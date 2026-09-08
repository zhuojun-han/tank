"use client";

import { useEffect, useEffectEvent, useMemo, useState } from "react";
import { defaultTanks, defaultParameters, defaultTargets, defaultRecords, defaultTasks, type Tank, type Parameter, type Target, type RecordItem, type TaskItem, type TimerDefaults } from "./demo-state";
import { loadDemoState, saveDemoState, type DemoState } from "./demo-storage";
import { calculatorTargetDefault, createParameterTarget } from "./target-range";
import { TimerRing, useDetectionTimer } from "./detection-timer";
import { KhTitrationPanel } from "./kh-titration-panel";
import { calculateKhTitration, KH_TITRATION_TABLE_ID, type KhTitrationResult } from "./kh-titration";
import { HomeHistoryBars } from "./home-history-bars";
import { Po4ColorMatchPanel } from "./po4-color-match/page";
import { ColorMatchPanel, type PhotoReview } from "./color-match/page";
import { readRecordValues, recordPoint, recordValueText } from "./record-values";
import { PagedRecordList } from "./paged-record-list";
import { historyDate, recordDateLabel } from "./history-date";
import { RecordTrend } from "./record-trend";
import { addMaintenanceCycle, delayMaintenanceCycle, localCycleDate, maintenanceReminderDate, maintenanceTasksOnDate, type MaintenanceCycle, type MaintenanceChemical } from "./maintenance-cycle";
import { completeRollingTask, correctRollingCompletion, delayRollingTask, initializeRollingTasks, projectRollingTasks, reopenRollingTask, stopRollingTask, taskDisplayDate } from "./rolling-task";
import { TaskActionDialog } from "./task-action-dialog";
import { useLocalDate } from "./use-local-date";
import { MaintenanceDosingPanel } from "./maintenance-dosing-panel";
import {
  calculateLanthanumPlan,
  DEFAULT_PLAN_STOCK_FINAL_VOLUME_ML,
  LanthanumCalculationError,
  type LanthanumPlan,
} from "./lanthanum-calculator";
import {
  calculateAlkalinityPlan,
  AlkalinityCalculationError,
  DEFAULT_ALKALINITY_STOCK_FINAL_VOLUME_ML,
  DEFAULT_DAILY_DKH_CONSUMPTION,
  DEFAULT_MAX_DAILY_DKH_RISE,
  DEFAULT_SODIUM_BICARBONATE_PURITY_PERCENT,
  DEFAULT_STOCK_ML_PER_0_1_DKH_100L,
  STOCK_ML_PER_0_1_DKH_100L_OPTIONS,
  type AlkalinityPlan,
} from "./alkalinity-calculator";
import {
  calculateSaltMix,
  DEFAULT_LABEL_REFERENCE_SG,
  DEFAULT_SALT_GRAMS_PER_LITRE_AT_REFERENCE,
  DEFAULT_TARGET_SG,
  SalinityCalculationError,
  type SalinityCalculationResult,
} from "./salinity-calculator";
import { completedTasksOnDate, editRecurringTask, groupChemicalPlanTasks, hasChemicalPlanFromDate, markTaskIncomplete, pendingTasksOnDate, removeChemicalPlansFromDate, stopChemicalPlanFromDay, taskCatalogGroups, taskOccursOnDate, taskStateOnDate, wakeExpiredSnoozedTasks } from "./task-calendar";
import {
  defaultFishStock,
  type FishStockItem,
} from "./aquarium-data";
import { AquariumSimulator, FishManagerSheet } from "./aquarium-simulator";
import { TankManagerSheet, type TankDetails, type TankManagerView } from "./tank-manager-sheet";
import { tankAgeDays, validateTankStartDate } from "./tank-age";

type Tab = "home" | "test" | "trend" | "tasks";
type TaskFilter = "pending" | "completed" | "all";
type PendingTaskAction = { mode: "delay" | "complete" | "correct"; id: number; tankId: number; title: string; occurrenceDate: string; revision?: number; cycleId?: number; deferredUntil?: string };
type Advice = { parameterId: string; status: "high" | "low" | "good" | "partial" | "missing"; title: string; summary: string; actions: string[] };
type LanthanumUiPlan = LanthanumPlan & {
  previewOnly?: boolean;
  calculatedTankId: number;
  scheduledPlanId: string;
  scheduledStartDate: string;
};
type AlkalinityUiPlan = AlkalinityPlan & {
  previewOnly?: boolean;
  calculatedTankId: number;
  scheduledPlanId: string;
  scheduledStartDate: string;
};
type PendingChemicalReplacement =
  | { kind: "lanthanum"; plan: LanthanumUiPlan }
  | { kind: "alkalinity"; plan: AlkalinityUiPlan };
type ChemicalPlanDetails = {
  planId: string;
  source: "lanthanum-plan" | "alkalinity-plan";
};

function isFiniteChemicalPlanSource(source?: TaskItem["source"]) {
  return source === "lanthanum-plan" || source === "alkalinity-plan";
}

function formatMass(grams: number) {
  const milligrams = grams * 1_000;
  return milligrams < 1_000
    ? `${milligrams.toFixed(milligrams < 10 ? 3 : 2)} mg`
    : `${grams.toFixed(4)} g`;
}

function formatVolume(millilitres: number) {
  return `${millilitres.toFixed(millilitres < 10 ? 2 : 1)} mL`;
}

function formatSaltMass(grams: number) {
  return grams >= 1_000
    ? `${(grams / 1_000).toFixed(3)} kg`
    : `${grams.toFixed(1)} g`;
}

function dateKey(date: Date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function addDays(date: Date, amount: number) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() + amount);
}

function calendarDateLabel(date: Date) {
  return new Intl.DateTimeFormat("zh-CN", {
    month: "long",
    day: "numeric",
    weekday: "short",
  }).format(date);
}

function taskReminderTime(task: TaskItem) {
  return task.due.match(/\b([01]\d|2[0-3]):[0-5]\d\b/)?.[0] ?? "09:00";
}

const navItems: { id: Tab; label: string; icon: string }[] = [
  { id: "home", label: "首页", icon: "⌂" }, { id: "test", label: "检测", icon: "◉" },
  { id: "trend", label: "趋势", icon: "↗" }, { id: "tasks", label: "任务", icon: "✓" },
];

export default function Home() {
  const [ready, setReady] = useState(false);
  const [todayLabel, setTodayLabel] = useState("水质概览");
  const [tab, setTab] = useState<Tab>("home");
  const [tanks, setTanks] = useState<Tank[]>(defaultTanks);
  const [tankId, setTankId] = useState(1);
  const [parameters, setParameters] = useState<Parameter[]>(defaultParameters);
  const [targets, setTargets] = useState<Target[]>(defaultTargets);
  const [records, setRecords] = useState<RecordItem[]>(defaultRecords);
  const [tasks, setTasks] = useState<TaskItem[]>(defaultTasks);
  const [maintenanceCycles, setMaintenanceCycles] = useState<MaintenanceCycle[]>([]);
  const [maintenanceChemical, setMaintenanceChemical] = useState<MaintenanceChemical>("po4");
  const [fishStock, setFishStock] = useState<FishStockItem[]>(defaultFishStock);
  const [fishModal, setFishModal] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [tankMenu, setTankMenu] = useState(false);
  const [toast, setToast] = useState("");
  const [pendingSaveToast, announceSaved] = useState("");
  const [storageIssue, setStorageIssue] = useState("");
  const [storageBlocked, setStorageBlocked] = useState(false);
  const [storageExtras, setStorageExtras] = useState<Partial<DemoState>>({});
  const [timerTotal, setTimerTotal] = useState(300);
  const [timerRunning, setTimerRunning] = useState(false);

  const [timerDefaults, setTimerDefaults] = useState<TimerDefaults>({});
  const [testStage, setTestStage] = useState<"setup" | "result">("setup");
  const [selectedParameterId, setSelectedParameterId] = useState("no3");
  const [trendParameterId, setTrendParameterId] = useState("no3");
  const [resultLow, setResultLow] = useState("10");
  const [resultHigh, setResultHigh] = useState("25");
  const [resultInterpolation, setResultInterpolation] = useState("");
  const [recordError, setRecordError] = useState("");
  const [photoMatchOpen, setPhotoMatchOpen] = useState(false);
  const [photoEstimate, setPhotoEstimate] = useState<PhotoReview>();
  const [editRecord, setEditRecord] = useState<RecordItem | null>(null);
  const [taskModal, setTaskModal] = useState(false);
  const [editingTask, setEditingTask] = useState<TaskItem | null>(null);
  const [taskAction, setTaskAction] = useState<PendingTaskAction | null>(null);
  const [taskFilter, setTaskFilter] = useState<TaskFilter>("pending");
  const [chemicalPlanDetails, setChemicalPlanDetails] = useState<ChemicalPlanDetails | null>(null);
  const todayKey = useLocalDate((next, previous) => {
    setSelectedCalendarDate(selected => selected === previous ? next : selected);
    if (selectedCalendarDate === previous) setCalendarMonth(month =>
      dateKey(month).slice(0, 7) === previous.slice(0, 7)
        ? new Date(Number(next.slice(0, 4)), Number(next.slice(5, 7)) - 1, 1) : month);
    setTodayLabel(`${new Intl.DateTimeFormat("zh-CN", { month: "long", day: "numeric", weekday: "short" }).format(new Date(`${next}T12:00:00`))} · 水质概览`);
  });
  const [calendarMonth, setCalendarMonth] = useState(() => {
    const today = new Date();
    return new Date(today.getFullYear(), today.getMonth(), 1);
  });
  const [selectedCalendarDate, setSelectedCalendarDate] = useState(() =>
    dateKey(new Date()),
  );
  const [tankModal, setTankModal] = useState<TankManagerView | null>(null);
  const [targetModal, setTargetModal] = useState(false);
  const [parameterModal, setParameterModal] = useState(false);
  const [customParameterModal, setCustomParameterModal] = useState(false);
  const [maintenanceModal, setMaintenanceModal] = useState(false);
  const [lanthanumModal, setLanthanumModal] = useState(false);
  const [lanthanumPlan, setLanthanumPlan] = useState<LanthanumUiPlan | null>(null);
  const [lanthanumError, setLanthanumError] = useState("");
  const [alkalinityModal, setAlkalinityModal] = useState(false);
  const [alkalinityPlan, setAlkalinityPlan] = useState<AlkalinityUiPlan | null>(null);
  const [alkalinityError, setAlkalinityError] = useState("");
  const [pendingChemicalReplacement, setPendingChemicalReplacement] = useState<PendingChemicalReplacement | null>(null);
  const [salinityModal, setSalinityModal] = useState(false);
  const [salinityResult, setSalinityResult] = useState<SalinityCalculationResult | null>(null);
  const [salinityError, setSalinityError] = useState("");
  const [notificationEnabled, setNotificationEnabled] = useState(false);
  const [reminderOpen, setReminderOpen] = useState(false);
  const [reminderDismissedDate, setReminderDismissedDate] = useState("");

  const { clock: detectionClock, setTimer } = useDetectionTimer(timerRunning && selectedParameterId !== "kh", () => {
    setTimerRunning(false);
    const canPhoto = ["no3", "po4"].includes(selectedParameterId);
    setTestStage(canPhoto ? "setup" : "result");
    setPhotoMatchOpen(canPhoto);
    setToast(canPhoto ? "显色完成，可以拍照比色了" : "计时完成，可以录入结果了");
  });
  const publishSaveResult = useEffectEvent((outcome: { ok: boolean; message?: string }) => {
    if (!storageBlocked) setStorageIssue(outcome.ok ? "" : outcome.message ?? "保存失败，请重试。");
    if (pendingSaveToast) {
      setToast(outcome.ok ? pendingSaveToast : storageBlocked ? "原存档暂停写入，本次更改未保存。" : "本次更改未保存，请重试保存。");
      announceSaved("");
    }
  });

  useEffect(() => {
    const id = window.setTimeout(() => {
      setTodayLabel(`${new Intl.DateTimeFormat("zh-CN", { month: "long", day: "numeric", weekday: "short" }).format(new Date())} · 水质概览`);
      const restored = loadDemoState(() => window.localStorage, {
        tanks: defaultTanks, tankId: 1, parameters: defaultParameters, targets: defaultTargets,
        records: defaultRecords, tasks: defaultTasks, maintenanceCycles: [], fishStock: defaultFishStock,
        timerDefaults: {}, notificationEnabled: false, reminderDismissedDate: "",
      });
      const data = restored.state;
      setStorageBlocked(restored.blocked); setStorageIssue(restored.message ?? "");
      setStorageExtras(data);
      setTanks(data.tanks); setTankId(data.tankId); setParameters(data.parameters); setTargets(data.targets);
      setRecords(data.records); setTasks(data.tasks); setMaintenanceCycles(data.maintenanceCycles);
      setFishStock(data.fishStock); setTimerDefaults(data.timerDefaults);
      setNotificationEnabled(data.notificationEnabled); setReminderDismissedDate(data.reminderDismissedDate);
      const duration = data.timerDefaults[`${data.tankId}:no3`] ?? 300;
      setTimer(duration); setTimerTotal(duration);
      setReady(true);
    }, 0);
    return () => window.clearTimeout(id);
  }, [setTimer]);

  useEffect(() => {
    if (!ready) return;
    if (storageBlocked) {
      const id = window.setTimeout(() => publishSaveResult({ ok: false }), 0);
      return () => window.clearTimeout(id);
    }
    const outcome = saveDemoState(() => window.localStorage, {
      ...storageExtras, tanks, tankId, parameters, targets, records, tasks, maintenanceCycles,
      fishStock, timerDefaults, notificationEnabled, reminderDismissedDate,
    });
    // Saving failed: keep an enduring notice, not a success-looking disappearing toast.
    const id = window.setTimeout(() => publishSaveResult(outcome), 0);
    return () => window.clearTimeout(id);
  }, [ready, storageBlocked, storageExtras, tanks, tankId, parameters, targets, records, tasks, maintenanceCycles, fishStock, timerDefaults, notificationEnabled, reminderDismissedDate]);

  useEffect(() => {
    if (!ready) return;
    const id = window.setTimeout(() => {
      const raw = sessionStorage.getItem("reef-photo-review");
      if (!raw) return;
      sessionStorage.removeItem("reef-photo-review");
      try {
        const draft = JSON.parse(raw);
        const destination = draft.tankId ?? tankId;
        if (!tanks.some(t => t.id === destination)) throw new Error('原海缸不存在，请重新检测。');
        const review = draft.review as PhotoReview;
        const values = readRecordValues(String(review.low), String(review.high), review.interpolation === null ? "" : String(review.interpolation));
        setTankId(destination); setSelectedParameterId(review.parameterId === 'po4' ? 'po4' : 'no3'); setTab('test'); setTestStage('result');
        setResultLow(String(values.low)); setResultHigh(String(values.high)); setResultInterpolation(values.interpolation === null ? "" : String(values.interpolation)); setPhotoEstimate(review); setRecordError('');
      } catch { setToast('拍照草稿无效或原海缸不存在，未记录结果。'); }
    }, 0);
    return () => window.clearTimeout(id);
  }, [ready, tankId, tanks]);



  useEffect(() => {
    if (!toast) return;
    const id = window.setTimeout(() => setToast(""), 2600);
    return () => window.clearTimeout(id);
  }, [toast]);

  const tank = tanks.find((item) => item.id === tankId) ?? tanks[0];
  const enabledTargets = targets.filter((item) => item.tankId === tankId);
  const enabledParameters = enabledTargets.map((target) => parameters.find((item) => item.id === target.parameterId)).filter(Boolean) as Parameter[];
  const selectedParameter = parameters.find((item) => item.id === selectedParameterId) ?? enabledParameters[0] ?? parameters[0];
  const trendParameter = parameters.find((item) => item.id === trendParameterId) ?? enabledParameters[0] ?? parameters[0];
  useEffect(() => {
    if (!ready || new URLSearchParams(window.location.search).get('demoHistory') !== '1') return;
    const timer = window.setTimeout(() => {
      setRecords(current => {
        if (current.some(r=>r.tankId===tankId && r.note==='历史演示数据 · 非真实检测')) return current;
        const now=Date.now();
        const demo: RecordItem[] = ['no3','po4'].flatMap((parameterId,p)=>Array.from({length:15},(_,i)=>{
          const point = parameterId==='no3' ? [8,9.5,12,11,15,18,16,14,12.5,10,9,8.5,7,6.5,6][i] : [.31,.28,.26,.23,.21,.18,.2,.16,.14,.13,.11,.1,.09,.075,.065][i];
          return {id:-(now+p*100+i),tankId,parameterId,low:point,high:point,interpolation:point,date:new Date(now-(30-i)*86400000).toISOString(),note:'历史演示数据 · 非真实检测'};
        }));
        return [...current,...demo].sort((a,b)=>Date.parse(b.date)-Date.parse(a.date));
      });
    },0);
    return ()=>window.clearTimeout(timer);
  },[ready,tankId]);

  const tankRecords = records.filter((item) => item.tankId === tankId);
  const tankFishStock = fishStock.filter((item) => item.tankId === tankId);
  const trendRecords = tankRecords.filter((item) => item.parameterId === trendParameter.id).slice().reverse();
  const trendTarget = targets.find((item) => item.tankId === tankId && item.parameterId === trendParameter.id);
  const projectedTasks = useMemo(() => projectRollingTasks(tasks, todayKey), [tasks, todayKey]);
  const tankTasksForDate = (date: string): TaskItem[] => [
    ...projectedTasks.filter((item) => item.tankId === tankId),
    ...maintenanceTasksOnDate(maintenanceCycles, tankId, date, todayKey),
  ];
  const futureRefills = maintenanceCycles.filter(cycle => cycle.tankId === tankId && !cycle.closedOnDate && cycle.refillDeferredUntil)
    .flatMap(cycle => {
      const date = maintenanceReminderDate(cycle, todayKey);
      return date > todayKey ? maintenanceTasksOnDate([cycle], tankId, date, todayKey) : [];
    });
  const allTankTasks: TaskItem[] = [...tankTasksForDate(todayKey), ...futureRefills];
  const homeDosingTasks = allTankTasks.filter(task => task.source === "maintenance-cycle" && task.state === "done");
  const chemicalPlanDetailTasks = chemicalPlanDetails ? allTankTasks
    .filter((item) => item.planId === chemicalPlanDetails.planId && item.source === chemicalPlanDetails.source)
    .sort((a, b) => (taskDisplayDate(a, todayKey) ?? "").localeCompare(taskDisplayDate(b, todayKey) ?? "")) : [];
  const tankTasks = allTankTasks.filter((item) => item.state !== "done" && item.state !== "skipped");
  const pendingListTasks = tankTasks;
  const completedDateTasks = completedTasksOnDate(tankTasksForDate(selectedCalendarDate), selectedCalendarDate, todayKey);
  const pendingPlanGroups = groupChemicalPlanTasks(pendingListTasks, todayKey);
  const cycleCatalogTasks = [...new Map(allTankTasks.filter(task => task.source === "maintenance-cycle").map(task => [task.id, task])).values()];
  const allPlanGroups = [...taskCatalogGroups(allTankTasks, todayKey), ...cycleCatalogTasks
    .map(task => ({ key: `cycle-${task.id}`, isChemicalPlan: false, task, members: [task] }))];
  const homeTaskGroups = groupChemicalPlanTasks(pendingTasksOnDate(allTankTasks, todayKey), todayKey);
  const completedDateGroups = completedDateTasks.map((task) => ({ key: `completed-${task.id}`, isChemicalPlan: false, task, members: [task] }));
  const visibleTaskGroups = taskFilter === "pending" ? pendingPlanGroups : taskFilter === "completed" ? completedDateGroups : allPlanGroups;
  const calendarMonthLabel = new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "long",
  }).format(calendarMonth);
  const calendarOffset = (calendarMonth.getDay() + 6) % 7;
  const calendarStart = new Date(
    calendarMonth.getFullYear(),
    calendarMonth.getMonth(),
    1 - calendarOffset,
  );
  const calendarDays = Array.from({ length: 42 }, (_, index) => {
    const date = addDays(calendarStart, index);
    return {
      date,
      key: dateKey(date),
      inMonth: date.getMonth() === calendarMonth.getMonth(),
    };
  });
  const calendarOccurrencesForDate = (key: string) => tankTasksForDate(key)
    .filter((item) => taskOccursOnDate(item, key))
    .map((task) => ({
      task,
      occurrenceDate: key,
      state: taskStateOnDate(task, key, todayKey),
    }))
    .filter((item) => item.state !== "skipped");
  const selectedDateTasks = calendarOccurrencesForDate(selectedCalendarDate);
  const todayReminderTasks = allTankTasks.filter(task => taskOccursOnDate(task, todayKey))
    .map(task => ({ task, occurrenceDate: todayKey, state: taskStateOnDate(task, todayKey, todayKey) }))
    .filter(item => item.state !== "done" && item.state !== "skipped");
  const selectedDateLabel = calendarDateLabel(
    new Date(`${selectedCalendarDate}T12:00:00`),
  );
  useEffect(() => {
    if (!ready || !notificationEnabled || reminderDismissedDate === todayKey || todayReminderTasks.length === 0) return;
    const id = window.setTimeout(() => setReminderOpen(true), 0);
    return () => window.clearTimeout(id);
  }, [ready, notificationEnabled, reminderDismissedDate, todayKey, todayReminderTasks.length]);
  useEffect(() => {
    if (!ready) return;
    const deadlines = tasks.flatMap((task) => [
      ...(task.state === "snoozed" && task.snoozedUntil ? [task.snoozedUntil] : []),
      ...Object.entries(task.snoozedUntilByDate ?? {}).filter(([date]) => task.snoozedDates?.includes(date)).map(([, deadline]) => deadline),
    ]);
    if (deadlines.length === 0) return;
    const nextDeadline = deadlines.reduce((earliest, deadline) => {
      const time = Date.parse(deadline);
      return Number.isFinite(time) ? Math.min(earliest, time) : earliest;
    }, Infinity);
    if (!Number.isFinite(nextDeadline)) return;
    // Browsers overflow delays above 2^31-1 ms into an immediate timer. Wait in
    // bounded steps and do not rewrite storage until the deadline is reached.
    const delay = () => Math.min(2_147_483_647, Math.max(0, nextDeadline - Date.now()));
    let id: number;
    const wake = () => {
      if (Date.now() < nextDeadline) { id = window.setTimeout(wake, delay()); return; }
      setTasks((items) => wakeExpiredSnoozedTasks(items, new Date().toISOString()));
      setReminderDismissedDate("");
    };
    id = window.setTimeout(wake, delay());
    return () => window.clearTimeout(id);
  }, [ready, tasks]);
  const timerLocked = timerRunning || detectionClock.getSnapshot() < timerTotal;
  const chartMax = trendRecords.reduce((max, item) => Math.max(max, item.high), Math.max(1, trendTarget?.max ?? 0)) * 1.2;
  const latestPo4Record = tankRecords.find((item) => item.parameterId === "po4");
  const exactLatestPo4 = latestPo4Record && latestPo4Record.low === latestPo4Record.high ? latestPo4Record.low : "";
  const po4Target = targets.find((item) => item.tankId === tankId && item.parameterId === "po4");
  const lanthanumFirstDay = lanthanumPlan?.dailyPlan[0];
  const lanthanumLastDay = lanthanumPlan?.dailyPlan.at(-1);
  const latestKhRecord = tankRecords.find((item) => item.parameterId === "kh");
  const exactLatestKh = latestKhRecord && latestKhRecord.low === latestKhRecord.high ? latestKhRecord.low : "";
  const khTarget = targets.find((item) => item.tankId === tankId && item.parameterId === "kh");
  const alkalinityFirstDay = alkalinityPlan?.dailyPlan[0];
  const alkalinityLastDay = alkalinityPlan?.dailyPlan.at(-1);

  function parameterOf(id: string) { return parameters.find((item) => item.id === id) ?? parameters[0]; }
  function targetOf(parameterId: string) { return targets.find((item) => item.tankId === tankId && item.parameterId === parameterId); }
  function latestOf(parameterId: string) { return tankRecords.find((item) => item.parameterId === parameterId); }
  function resultText(record: RecordItem) { const unit = parameterOf(record.parameterId).unit; return record.low === record.high ? `${recordValueText(record.low, record)} ${unit}` : `${recordValueText(record.low, record)}–${recordValueText(record.high, record)} ${unit}`; }
  function targetText(parameterId: string) { const value = targetOf(parameterId); const unit = parameterOf(parameterId).unit; return value?.min !== null && value?.min !== undefined && value?.max !== null && value?.max !== undefined ? `${value.min}–${value.max} ${unit}` : "未设置"; }
  function resultStatus(parameterId: string) {
    const record = latestOf(parameterId); const target = targetOf(parameterId);
    if (!record) return "还没有检测记录";
    if (target?.min === null || target?.min === undefined || target?.max === null || target?.max === undefined) return "设置目标后可判断状态";
    if (record.high < target.min) return "低于你的目标范围";
    if (record.low > target.max) return "高于你的目标范围";
    if (record.low >= target.min && record.high <= target.max) return "在你的目标范围内";
    return "部分超出目标范围";
  }
  function adviceFor(parameterId: string): Advice {
    const parameter = parameterOf(parameterId); const record = latestOf(parameterId); const target = targetOf(parameterId);
    if (!record) return { parameterId, status: "missing", title: `${parameter.name} 还没有记录`, summary: "完成一次检测后，才能根据你的目标范围生成建议。", actions: ["先完成一次规范检测", "保存人工确认结果"] };
    if (target?.min === null || target?.min === undefined || target?.max === null || target?.max === undefined) return { parameterId, status: "missing", title: `${parameter.name} 尚未设置目标`, summary: "先设置适合当前海缸的目标范围，再判断偏高或偏低。", actions: ["设置目标上下限", "确认目标与饲养类型匹配"] };
    const low = record.high < target.min; const high = record.low > target.max; const inRange = record.low >= target.min && record.high <= target.max;
    if (inRange) return { parameterId, status: "good", title: `${parameter.name} 在目标范围内`, summary: `最近结果 ${resultText(record)}，继续保持当前喂食和维护节奏。`, actions: ["按原计划复测", "避免突然改变喂食或过滤强度"] };
    if (!low && !high) return { parameterId, status: "partial", title: `${parameter.name} 与目标范围部分重叠`, summary: `最近结果 ${resultText(record)}，当前范围不足以确定偏高或偏低。`, actions: ["在相同条件下复测确认", "确认试剂、显色时间和人工读数"] };
    if (parameterId === "no3" && high) return { parameterId, status: "high", title: "NO3 高于目标", summary: `最近结果 ${resultText(record)}，先确认读数，再逐步减少硝酸盐输入和累积。`, actions: ["复测并检查是否有残饵或生物死亡", "适量减少高营养饲料或单次投喂量", "清洗或更换滤棉，检查蛋分运行", "安排适量分次换水，避免一次剧烈下降"] };
    if (parameterId === "no3" && low) return { parameterId, status: "low", title: "NO3 低于目标", summary: `最近结果 ${resultText(record)}，不要继续加强换水或营养盐去除。`, actions: ["复测确认低值", "检查并适当降低过强的脱氮或碳源措施", "在生物承受范围内小幅增加喂食", "连续观察，不盲目添加硝酸盐药剂"] };
    if (parameterId === "po4" && high) return { parameterId, status: "high", title: "PO4 高于目标", summary: `最近结果 ${resultText(record)}，重点排查饲料输入、残饵和吸磷材料状态。`, actions: ["复测并检查残饵、底砂和积污", "适量减少高磷或荤性饲料及单次投喂量", "清洗滤棉并安排适量分次换水", "按产品说明检查或更换吸磷珠/吸磷材料"] };
    if (parameterId === "po4" && low) return { parameterId, status: "low", title: "PO4 低于目标", summary: `最近结果 ${resultText(record)}，继续强力吸磷可能造成营养限制。`, actions: ["使用低量程方法复测确认", "暂停新增并酌情减少吸磷材料", "在生物承受范围内小幅增加喂食", "连续观察珊瑚状态，不盲目添加磷酸盐"] };
    return { parameterId, status: high ? "high" : "low", title: `${parameter.name} ${high ? "高于" : "低于"}目标`, summary: "当前参数尚无已确认的专用维护规则。", actions: ["复测确认结果", "参考可靠资料或咨询有经验的专业人士"] };
  }
  function timerDefault(parameterId = selectedParameterId, targetTankId = tankId) { return timerDefaults[`${targetTankId}:${parameterId}`] ?? 300; }
  function setTimerDuration(seconds: number) { const safe = Math.min(3600, Math.max(10, seconds)); setTimer(safe); setTimerTotal(safe); setTimerDefaults((values) => ({ ...values, [`${tankId}:${selectedParameterId}`]: safe })); }
  function resetDetection(parameterId = selectedParameterId, targetTankId = tankId) { const duration = timerDefault(parameterId, targetTankId); setTestStage("setup"); setResultInterpolation(""); setPhotoEstimate(undefined); setRecordError(""); setTimer(duration); setTimerTotal(duration); setTimerRunning(false); }
  function selectTestParameter(id: string) { setSelectedParameterId(id); resetDetection(id); setResultLow(""); setResultHigh(""); }
  function switchTab(next: Tab) { setTab(next); setTankMenu(false); }
  function selectTank(id: number, parameterId = targets.find(target => target.tankId === id)?.parameterId ?? "no3") {
    setTankId(id);
    setTankMenu(false);
    setSelectedParameterId(parameterId);
    setTrendParameterId(parameterId);
    setResultLow("");
    setResultHigh("");
    setPhotoMatchOpen(false);
    resetDetection(parameterId, id);
  }
  function saveTank(details: TankDetails, editingId?: number) {
    if (storageBlocked) throw new Error("原存档暂停写入，请先处理存档问题。");
    const startedOn = validateTankStartDate(details.startedOn ?? "", localCycleDate());
    if (editingId !== undefined) {
      if (!tanks.some(item => item.id === editingId)) throw new Error("海缸已变化，请重新打开。");
      setTanks(items => items.map(item => item.id === editingId ? { ...item, ...details, startedOn } : item));
      announceSaved("海缸信息已保存");
      return;
    }
    let id = Date.now();
    while (tanks.some(item => item.id === id)) id++;
    setTanks(items => [...items, { id, ...details, startedOn }]);
    setTargets(items => [...items, { tankId: id, parameterId: "no3", min: null, max: null }, { tankId: id, parameterId: "po4", min: null, max: null }]);
    selectTank(id, "no3");
    announceSaved("新海缸已创建");
  }
  function changeCalendarMonth(amount: number) {
    const next = new Date(
      calendarMonth.getFullYear(),
      calendarMonth.getMonth() + amount,
      1,
    );
    setCalendarMonth(next);
    setSelectedCalendarDate(dateKey(next));
  }
  function showTodayInCalendar() {
    const today = new Date();
    setCalendarMonth(new Date(today.getFullYear(), today.getMonth(), 1));
    setSelectedCalendarDate(dateKey(today));
  }
  function openNewTaskModal() {
    setEditingTask(null);
    setTaskModal(true);
  }
  function openRecurringTaskEditor(task: TaskItem) {
    if (!task.intervalDays || task.oneOff) return;
    const current = projectedTasks.find(item => item.id === task.id && item.tankId === tankId);
    if (!current) return;
    setEditingTask(current);
    setTaskModal(true);
  }
  function closeTaskModal() {
    setTaskModal(false);
    setEditingTask(null);
  }
  function saveMaintenanceTask(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    const title = String(data.get("title") ?? "").trim();
    const scheduledDate = String(data.get("startDate"));
    const scheduled = new Date(`${scheduledDate}T12:00:00`);
    const intervalDays = Number(data.get("interval"));
    if (!title || !Number.isSafeInteger(intervalDays) || intervalDays < 1 || !Number.isFinite(scheduled.getTime()) || dateKey(scheduled) !== scheduledDate) {
      setToast("请填写有效日期及大于 0 的整数间隔。"); return;
    }
    const reminderTime = String(data.get("reminderTime") || "09:00");
    const scheduleFields = {
      title,
      cycle: `每 ${intervalDays} 天`,
      due: `${calendarDateLabel(scheduled)} ${reminderTime}`,
      state: scheduledDate <= todayKey ? "due" as const : "soon" as const,
      scheduledDate,
      intervalDays,
    };
    if (editingTask) {
      const current = tasks.find(task => task.id === editingTask.id && task.tankId === tankId);
      if (!current || current.rolling?.revision !== editingTask.rolling?.revision) { setToast("任务已变化，请重新打开编辑。"); return; }
      try { persistTaskChanges(editRecurringTask(tasks, editingTask.id, scheduleFields)); }
      catch (error) { setToast((error as Error).message); return; }
      closeTaskModal();
      announceSaved("重复任务已更新；既有逐日完成和跳过记录已保留");
      return;
    }
    try { persistTaskChanges(initializeRollingTasks([{
      id: tasks.reduce((max, task) => Math.max(max, task.id + 1), Date.now()),
      tankId,
      ...scheduleFields,
      completedDates: [],
      skippedDates: [],
      reopenedDates: [],
    }, ...tasks], todayKey)); }
    catch (error) { setToast((error as Error).message); return; }
    closeTaskModal();
    announceSaved(`维护任务已添加；下次按实际完成日期加 ${intervalDays} 天安排`);
  }
  function toggleNotificationReminder() {
    const next = !notificationEnabled;
    setNotificationEnabled(next);
    if (next) {
      setReminderDismissedDate("");
      if (todayReminderTasks.length > 0) setSettingsOpen(false);
      announceSaved("已开启网页内到期弹窗提醒");
    } else {
      setReminderOpen(false);
      announceSaved("已关闭网页内到期弹窗提醒");
    }
  }
  function dismissTodayReminder(openTasks = false) {
    setReminderDismissedDate(todayKey);
    setReminderOpen(false);
    if (openTasks) {
      showTodayInCalendar();
      setSettingsOpen(false);
      setTab("tasks");
    }
  }
  function openLanthanumCalculator() { setSettingsOpen(false); setLanthanumPlan(null); setLanthanumError(""); setLanthanumModal(true); }
  function openAlkalinityCalculator() { setSettingsOpen(false); setAlkalinityPlan(null); setAlkalinityError(""); setAlkalinityModal(true); }
  function openSalinityCalculator() { setSettingsOpen(false); setSalinityResult(null); setSalinityError(""); setSalinityModal(true); }
  function submitSalinityCalculation(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    setSalinityError("");
    try {
      setSalinityResult(calculateSaltMix({
        initialSg: Number(data.get("initialSg")),
        targetSg: Number(data.get("targetSg")),
        waterVolumeL: Number(data.get("waterVolumeL")),
        labelReferenceSg: Number(data.get("labelReferenceSg")),
        saltGramsPerLitreAtReference: Number(data.get("saltGramsPerLitreAtReference")),
      }));
    } catch (error) {
      setSalinityError(error instanceof SalinityCalculationError ? error.message : "计算失败，请检查输入。");
    }
  }
  function submitLanthanumCalculation(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    const targetPo4MgL = Number(data.get("targetPo4MgL"));
    setLanthanumError("");
    if (po4Target?.min !== null && po4Target?.min !== undefined && targetPo4MgL < po4Target.min) { setLanthanumError(`目标不能低于 ${tank?.name} 已设置的 PO4 下限 ${po4Target.min} mg/L。`); return; }
    try {
      const result = calculateLanthanumPlan({
        currentPo4MgL: Number(data.get("currentPo4MgL")),
        targetPo4MgL,
        netWaterVolumeL: Number(data.get("netWaterVolumeL")),
        maxDailyPo4DropMgL: Number(data.get("maxDailyPo4DropMgL")),
        stockFinalVolumeMl: Number(data.get("stockFinalVolumeMl")),
      });
      const scheduledStartDate = dateKey(new Date());
      const scheduledPlan = { ...result, calculatedTankId: tankId, scheduledPlanId: `lacl3-${tankId}-${Date.now()}`, scheduledStartDate };
      if (hasChemicalPlanFromDate(tasks, tankId, "lanthanum-plan", scheduledStartDate, todayKey)) {
        setPendingChemicalReplacement({ kind: "lanthanum", plan: scheduledPlan });
        return;
      }
      setLanthanumPlan(scheduledPlan);
      scheduleLanthanumTasks(scheduledPlan);
    } catch (error) {
      setLanthanumError(error instanceof LanthanumCalculationError ? error.message : "计算失败，请检查输入。");
    }
  }
  function scheduleLanthanumTasks(plan: LanthanumUiPlan) {
    const startDate = new Date(`${plan.scheduledStartDate}T12:00:00`);
    const nextTaskId = tasks.reduce((max, item) => Math.max(max, item.id), 0) + 1;
    const generatedTasks: TaskItem[] = plan.dailyPlan.map((day, index) => {
      const scheduled = addDays(startDate, index);
      const detail = `当天先复测 PO4、KH 并观察鱼和珊瑚；达到 ${plan.targetPo4MgL} mg/L、达到 0.03 mg/L 或出现急促呼吸、收缩等异常时，停止本次及后续计划。第 ${day.day} 天理论上最多取固定母液 ${formatVolume(day.stockToUseMl)}，用 RO/DI 水定容至最终 500 mL；只在复测仍需处理时执行，重算值更低时以更低值为准。仅慢速加入机械过滤或蛋分入口上游并捕获沉淀，不得直接加入展示缸。`;
      return {
        id: nextTaskId + index,
        tankId: plan.calculatedTankId,
        title: `氯化镧计划 · 第 ${day.day} 天`,
        cycle: `一次性 · 计划第 ${day.day}/${plan.days} 天`,
        due: `${calendarDateLabel(scheduled)} 09:00 · 复测后决定`,
        state: index === 0 ? "due" : "soon",
        detail,
        source: "lanthanum-plan",
        planId: plan.scheduledPlanId,
        dayIndex: day.day,
        totalDays: plan.days,
        oneOff: true,
        scheduledDate: dateKey(scheduled),
      };
    });
    setTasks((items) => initializeRollingTasks([...generatedTasks, ...removeChemicalPlansFromDate(items, plan.calculatedTankId, "lanthanum-plan", plan.scheduledStartDate, todayKey)], todayKey));
    setCalendarMonth(new Date(startDate.getFullYear(), startDate.getMonth(), 1));
    setSelectedCalendarDate(dateKey(startDate));
    announceSaved(`已自动将 ${generatedTasks.length} 天条件事项加入日历`);
  }
  function submitAlkalinityCalculation(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    const targetDkh = Number(data.get("targetDkh"));
    setAlkalinityError("");
    if (khTarget?.min !== null && khTarget?.min !== undefined && targetDkh < khTarget.min) { setAlkalinityError(`目标不能低于 ${tank?.name} 已设置的 KH 下限 ${khTarget.min} dKH。`); return; }
    if (khTarget?.max !== null && khTarget?.max !== undefined && targetDkh > khTarget.max) { setAlkalinityError(`目标不能高于 ${tank?.name} 已设置的 KH 上限 ${khTarget.max} dKH。`); return; }
    try {
      const result = calculateAlkalinityPlan({
        currentDkh: Number(data.get("currentDkh")),
        targetDkh,
        netWaterVolumeL: Number(data.get("netWaterVolumeL")),
        purityPercent: Number(data.get("purityPercent")),
        maxDailyDkhRise: Number(data.get("maxDailyDkhRise")),
        dailyDkhConsumption: Number(data.get("dailyDkhConsumption")),
        stockFinalVolumeMl: Number(data.get("stockFinalVolumeMl")),
        stockMlPer0_1Dkh100L: Number(data.get("stockMlPer0_1Dkh100L")),
        stockTemperatureC: Number(data.get("stockTemperatureC")),
      });
      const scheduledStartDate = dateKey(new Date());
      const scheduledPlan = { ...result, calculatedTankId: tankId, scheduledPlanId: `nahco3-${tankId}-${Date.now()}`, scheduledStartDate };
      if (hasChemicalPlanFromDate(tasks, tankId, "alkalinity-plan", scheduledStartDate, todayKey)) {
        setPendingChemicalReplacement({ kind: "alkalinity", plan: scheduledPlan });
        return;
      }
      setAlkalinityPlan(scheduledPlan);
      scheduleAlkalinityTasks(scheduledPlan);
    } catch (error) {
      setAlkalinityError(error instanceof AlkalinityCalculationError ? error.message : "计算失败，请检查输入。");
    }
  }
  function scheduleAlkalinityTasks(plan: AlkalinityUiPlan) {
    const startDate = new Date(`${plan.scheduledStartDate}T12:00:00`);
    const nextTaskId = tasks.reduce((max, item) => Math.max(max, item.id), 0) + 1;
    const generatedTasks: TaskItem[] = plan.dailyPlan.map((day, index) => {
      const scheduled = addDays(startDate, index);
      const detail = `当天先复测 KH、pH 并观察生物；达到 ${plan.targetDkh} dKH、重算后无需补充或出现异常时，停止当天及后续计划。第 ${day.day} 天理论取母液 ${formatVolume(day.stockToUseMl)}，对应投加当量 ${day.theoreticalDoseDkh.toFixed(3)} dKH（计划净提升 ${day.plannedNetDkhRise.toFixed(3)} + 假设当日消耗 ${day.assumedDkhConsumption.toFixed(3)}）；分次在强水流处缓慢加入。母液不得与钙、镁等浓缩液直接混合，应分开容器并错开添加；循环均匀后复测，重算值更低时以更低值为准。`;
      return {
        id: nextTaskId + index,
        tankId: plan.calculatedTankId,
        title: `碳酸氢钠补 KH · 第 ${day.day} 天`,
        cycle: `一次性 · 计划第 ${day.day}/${plan.days} 天`,
        due: `${calendarDateLabel(scheduled)} 09:00 · 复测后决定`,
        state: index === 0 ? "due" : "soon",
        detail,
        source: "alkalinity-plan",
        planId: plan.scheduledPlanId,
        dayIndex: day.day,
        totalDays: plan.days,
        oneOff: true,
        scheduledDate: dateKey(scheduled),
      };
    });
    setTasks((items) => initializeRollingTasks([...generatedTasks, ...removeChemicalPlansFromDate(items, plan.calculatedTankId, "alkalinity-plan", plan.scheduledStartDate, todayKey)], todayKey));
    setCalendarMonth(new Date(startDate.getFullYear(), startDate.getMonth(), 1));
    setSelectedCalendarDate(dateKey(startDate));
    announceSaved(`已自动将 ${generatedTasks.length} 天补 KH 条件事项加入日历`);
  }
  function previewChemicalReplacement() {
    if (!pendingChemicalReplacement) return;
    const pending = pendingChemicalReplacement;
    setPendingChemicalReplacement(null);
    if (pending.kind === "lanthanum") {
      setLanthanumPlan({ ...pending.plan, previewOnly: true });
    } else {
      setAlkalinityPlan({ ...pending.plan, previewOnly: true });
    }
  }
  function confirmChemicalReplacement() {
    if (!pendingChemicalReplacement) return;
    const pending = pendingChemicalReplacement;
    setPendingChemicalReplacement(null);
    if (pending.kind === "lanthanum") {
      setLanthanumPlan(pending.plan);
      scheduleLanthanumTasks(pending.plan);
    } else {
      setAlkalinityPlan(pending.plan);
      scheduleAlkalinityTasks(pending.plan);
    }
  }
  function openMaintenanceCycle(cycleId: number) {
    const cycle = maintenanceCycles.find(item => item.id === cycleId);
    if (!cycle || cycle.closedOnDate) return;
    setMaintenanceChemical(cycle.chemical);
    setMaintenanceModal(true);
  }
  function saveMaintenanceCycle(cycle: MaintenanceCycle) {
    cycle = { ...cycle, id: maintenanceCycles.reduce((max, item) => Math.max(max, item.id + 1), Date.now()) };
    const next = addMaintenanceCycle(maintenanceCycles, cycle);
    // Write before acknowledging success so a full browser store cannot lose a refill.
    if (storageBlocked) throw new Error("原存档尚未恢复，已暂停保存。请先处理页面上的存储提示。");
    const saved = saveDemoState(() => window.localStorage, { ...storageExtras, tanks, tankId, parameters, targets, records, tasks, maintenanceCycles: next, fishStock, timerDefaults, notificationEnabled, reminderDismissedDate: "" });
    if (!saved.ok) { setStorageIssue(saved.message); throw new Error(saved.message); }
    setMaintenanceCycles(next);
    setReminderDismissedDate("");
    setMaintenanceModal(false);
    setToast(`${cycle.chemical === "po4" ? "PO₄" : "KH"} 每日平衡已添加，${cycle.refillDate} 提醒补液`);
  }
  function maintenanceTaskCard(task: TaskItem) {
    const cycle = maintenanceCycles.find(item => item.id === task.maintenanceCycleId);
    return <article key={task.id} className={`task-card ${task.state}`} data-testid="maintenance-cycle-task">
      <div className="task-top"><div><span className="task-state">{task.state === "done" ? "已完成" : task.state === "soon" ? "计划补液" : "待处理"}</span><h2>{task.title}</h2><p>{task.cycle}</p></div></div>
      <p className="task-detail">{task.detail}</p>
      {cycle && !cycle.closedOnDate && <div className="task-actions"><button className="soft-button" onClick={() => openMaintenanceCycle(cycle.id)}>{todayKey >= cycle.refillDate ? "添加滴定液" : "提前续配"}</button>{task.state !== "done" && <button className="soft-button" onClick={() => setTaskAction({ mode: "delay", id: task.id, tankId, title: task.title, occurrenceDate: maintenanceReminderDate(cycle, todayKey), cycleId: cycle.id, deferredUntil: cycle.refillDeferredUntil })}>延迟</button>}</div>}
    </article>;
  }
  function completeTask(id: number, occurrenceDate?: string) {
    openTaskAction("complete", id, occurrenceDate);
  }
  function reopenTask(id: number, occurrenceDate: string) {
    const selected = tasks.find(item => item.id === id && item.tankId === tankId);
    if (!selected) return;
    try {
      const today = localCycleDate();
      persistTaskChanges(selected.rolling?.completed.some(item => item.completedDate === occurrenceDate)
        ? reopenRollingTask(tasks, id, occurrenceDate, today, selected.rolling.revision)
        : markTaskIncomplete(tasks, id, occurrenceDate, today));
      setToast("已重新标记为未完成");
    } catch (error) { setToast((error as Error).message); }
  }
  function delayTask(id: number, occurrenceDate?: string) {
    openTaskAction("delay", id, occurrenceDate);
  }
  function openTaskAction(mode: PendingTaskAction["mode"], id: number, occurrenceDate?: string) {
    const selected = projectedTasks.find(item => item.id === id && item.tankId === tankId);
    if (!selected) return;
    const date = occurrenceDate ?? taskDisplayDate(selected, todayKey) ?? todayKey;
    if (mode !== "correct" && date !== taskDisplayDate(selected, todayKey)) { setToast("请先处理最近一次任务。"); return; }
    setTaskAction({ mode, id, tankId, title: selected.title, occurrenceDate: date, revision: selected.rolling?.revision });
  }
  function persistTaskChanges(next: TaskItem[], cycles = maintenanceCycles) {
    if (storageBlocked) throw new Error("原存档尚未恢复，请先处理存储提示。");
    const saved = saveDemoState(() => window.localStorage, { ...storageExtras, tanks, tankId, parameters, targets, records, tasks: next, maintenanceCycles: cycles, fishStock, timerDefaults, notificationEnabled, reminderDismissedDate: "" });
    if (!saved.ok) { setStorageIssue(saved.message); throw new Error(saved.message); }
    setTasks(next); setMaintenanceCycles(cycles); setReminderDismissedDate("");
  }
  function confirmTaskAction(value: number | string) {
    if (!taskAction || taskAction.tankId !== tankId) throw new Error("当前海缸已变化，请重新打开任务。");
    const today = localCycleDate();
    if (taskAction.cycleId !== undefined) {
      const current = maintenanceCycles.find(c => c.id === taskAction.cycleId && c.tankId === tankId && !c.closedOnDate);
      if (!current || current.refillDeferredUntil !== taskAction.deferredUntil || maintenanceReminderDate(current, today) !== taskAction.occurrenceDate) throw new Error("补液安排已变化，请重新打开任务。");
      persistTaskChanges(tasks, delayMaintenanceCycle(maintenanceCycles, current.id, Number(value), today));
    } else {
      const current = projectRollingTasks(tasks, today).find(item => item.id === taskAction.id && item.tankId === tankId);
      if (!current || (taskAction.mode !== "correct" && taskDisplayDate(current, today) !== taskAction.occurrenceDate)) throw new Error("任务日期已变化，请重新打开任务。");
      const next = taskAction.mode === "delay" ? delayRollingTask(tasks, taskAction.id, Number(value), today, taskAction.revision)
        : taskAction.mode === "correct" ? correctRollingCompletion(tasks, taskAction.id, taskAction.occurrenceDate, String(value), today, taskAction.revision)
          : completeRollingTask(tasks, taskAction.id, String(value), today, taskAction.revision);
      persistTaskChanges(next);
      if (taskAction.mode !== "delay") {
        setSelectedCalendarDate(String(value));
        setCalendarMonth(new Date(`${String(value).slice(0, 7)}-01T12:00:00`));
      }
    }
    setTaskAction(null);
    setToast(taskAction.mode === "delay" ? `已延迟 ${value} 天` : "完成日期已记录，后续安排已更新");
  }
  function stopChemicalPlan(id: number, keepSelectedDateInCalendar = true) {
    const selected = tasks.find((item) => item.id === id);
    if (!isFiniteChemicalPlanSource(selected?.source)) return;
    const planName = selected.source === "alkalinity-plan" ? "碳酸氢钠补 KH" : "氯化镧";
    try { persistTaskChanges(stopChemicalPlanFromDay(tasks, id, "计划已停止", keepSelectedDateInCalendar, localCycleDate()));
      setToast(`已停止后续${planName}计划；后续日期已从日历移除`); }
    catch (error) { setToast((error as Error).message); }
  }
  function stopFutureTasks(id: number, occurrenceDate: string) {
    const selected = tasks.find((item) => item.id === id);
    if (isFiniteChemicalPlanSource(selected?.source)) { stopChemicalPlan(id); return; }
    if (selected?.intervalDays && !selected.oneOff) {
      try { persistTaskChanges(stopRollingTask(tasks, id, localCycleDate(), selected.rolling?.revision));
        setToast("已停止后续计划；未来日期已从日历移除"); }
      catch (error) { setToast((error as Error).message); }
      return;
    }
    skipTask(id, occurrenceDate);
  }
  function skipTask(id: number, occurrenceDate?: string) {
    const selected = tasks.find((item) => item.id === id && item.tankId === tankId);
    if (isFiniteChemicalPlanSource(selected?.source)) { stopChemicalPlan(id); return; }
    if (selected?.rolling) {
      try { persistTaskChanges(stopRollingTask(tasks, id, localCycleDate(), selected.rolling.revision)); setToast("本次已跳过"); }
      catch (error) { setToast((error as Error).message); }
      return;
    }
    if (selected?.intervalDays && occurrenceDate) {
      setTasks((items) => items.map((item) => item.id === id ? {
        ...item,
        skippedDates: [...new Set([...(item.skippedDates ?? []), occurrenceDate])],
        completedDates: (item.completedDates ?? []).filter((date) => date !== occurrenceDate),
        snoozedDates: (item.snoozedDates ?? []).filter((date) => date !== occurrenceDate),
        snoozedUntilByDate: Object.fromEntries(Object.entries(item.snoozedUntilByDate ?? {}).filter(([date]) => date !== occurrenceDate)),
      } : item));
      announceSaved("仅跳过本次，后续重复日期不受影响");
      return;
    }
    setTasks((items) => items.map((item) => item.id === id ? { ...item, state: "skipped", handledAt: "刚刚跳过", snoozedUntil: undefined } : item));
    announceSaved("本次已跳过");
  }
  function saveDetection() {
    let values;
    try { values = readRecordValues(resultLow, resultHigh, ["no3", "po4"].includes(selectedParameter.id) ? resultInterpolation : ""); }
    catch (error) { setRecordError((error as Error).message); return; }
    setRecords((items) => [{ id: Date.now(), tankId, parameterId: selectedParameter.id, ...values, date: new Date().toISOString(), note: photoEstimate ? "拍照记录" : "手动录入", photoEstimate }, ...items]);
    resetDetection(); announceSaved(`${selectedParameter.name} 结果已保存`); setTab("home");
  }
  function saveKhTitration(result: KhTitrationResult) {
    if (storageBlocked) throw new Error("原存档暂停写入，请先处理存档问题。");
    if (!tank || selectedParameter.id !== "kh" || !enabledParameters.some(item => item.id === "kh")) throw new Error("当前海缸或 KH 指标已变化，请重新检测。");
    const checked = calculateKhTitration(result.initialMl, result.remainingMl);
    const value = Number(checked.displayDkh);
    setRecords(items => [{
      id: Date.now(), tankId, parameterId: "kh", low: value, high: value,
      date: new Date().toISOString(), note: "KH 滴定记录",
      khTitration: { ...checked, tableId: KH_TITRATION_TABLE_ID },
    }, ...items]);
    resetDetection("kh"); announceSaved("KH 结果已保存"); setTab("home");
  }
  function saveEditedRecord(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault(); if (!editRecord) return; const data = new FormData(event.currentTarget);
    let values;
    try { values = readRecordValues(String(data.get("low") ?? ""), String(data.get("high") ?? ""), ["no3", "po4"].includes(String(data.get("parameterId"))) ? String(data.get("interpolation") ?? "") : ""); }
    catch (error) { setRecordError((error as Error).message); return; }
    setRecords((items) => items.map((item) => item.id === editRecord.id ? { ...item, tankId: Number(data.get("tankId")), parameterId: String(data.get("parameterId")), ...values, date: String(data.get("date")), note: String(data.get("note")), edited: true } : item));
    setEditRecord(null); announceSaved("记录已修改，趋势和状态已更新");
  }
  function toggleParameter(parameterId: string) {
    const current = targets.find((item) => item.tankId === tankId && item.parameterId === parameterId);
    if (current) {
      if (enabledTargets.length <= 1) { setToast("至少保留一个关注指标"); return; }
      setTargets((items) => items.filter((item) => !(item.tankId === tankId && item.parameterId === parameterId)));
      if (selectedParameterId === parameterId) selectTestParameter(enabledParameters.find((item) => item.id !== parameterId)?.id ?? "no3");
      if (trendParameterId === parameterId) setTrendParameterId(enabledParameters.find((item) => item.id !== parameterId)?.id ?? "no3");
    } else setTargets((items) => [...items, createParameterTarget(tankId, parameterId)]);
  }

  const defaultCalculatorTargets = useMemo(() => ({
    po4: calculatorTargetDefault("po4", po4Target),
    kh: calculatorTargetDefault("kh", khTarget),
  }), [po4Target, khTarget]);
  const PhotoPanel = selectedParameterId === "po4" ? Po4ColorMatchPanel : ColorMatchPanel;
  if (photoMatchOpen) return <PhotoPanel onClose={() => { setPhotoMatchOpen(false); resetDetection(); }} onReview={review => { setPhotoMatchOpen(false); setPhotoEstimate(review); setResultLow(String(review.low)); setResultHigh(String(review.high)); setResultInterpolation(review.interpolation === null ? "" : String(review.interpolation)); setRecordError(""); setTestStage("result"); }} />;
  return <main className="site-shell" aria-busy={!ready}>
        {storageIssue && <section role="alert" data-testid="storage-notice" className="notification-note"><strong>{storageBlocked ? "原存档已保留，暂停保存" : "更改尚未保存"}</strong><p>{storageIssue}</p>{storageBlocked && <p>当前显示临时演示数据。请保留此浏览器数据以便恢复，勿使用“恢复演示数据”。</p>}<button className="soft-button" onClick={() => {
          if (storageBlocked) { window.location.reload(); return; }
          const saved = saveDemoState(() => window.localStorage, { ...storageExtras, tanks, tankId, parameters, targets, records, tasks, maintenanceCycles, fishStock, timerDefaults, notificationEnabled, reminderDismissedDate });
          setStorageIssue(saved.ok ? "" : saved.message);
        }}>{storageBlocked ? "重新尝试读取" : "重试保存"}</button></section>}
    <div className="ambient ambient-one" /><div className="ambient ambient-two" />
    <section className="phone" aria-label="澜礁海缸助手网页版演示">
      <header className="topbar">
        <button className="tank-switcher" onClick={() => setTankMenu(!tankMenu)}><span className="tank-avatar">澜</span><span><small>当前海缸</small><strong>{tank?.name}</strong></span><span className="chevron">⌄</span></button>
        <button className="icon-button" onClick={() => setSettingsOpen(true)} aria-label="打开设置">⚙</button>
        {tankMenu && <div className="tank-popover">{tanks.map((item) => <button key={item.id} className={item.id === tankId ? "active" : ""} onClick={() => selectTank(item.id)}><span>{item.name}</span><small>{item.volume}</small></button>)}<button className="add-row" onClick={() => { setTankMenu(false); setTankModal({ mode: "add" }); }}>＋ 添加海缸</button></div>}
      </header>

      <div className="content-scroll">
        {tab === "home" && <section className="screen home-screen">
          <AquariumSimulator tankName={tank?.name ?? "当前海缸"} stock={tankFishStock} runningDays={tankAgeDays(tank?.startedOn, todayKey)} onOpen={() => setFishModal(true)} onManageTank={() => setTankModal({ mode: "edit", tankId })} />
          <div className="hero-copy"><div><p className="eyebrow">{todayLabel}</p><h1>{tank?.name}<br />水质改善建议</h1></div></div>
          <div className="metric-grid dynamic-metrics">{enabledParameters.slice(0, 4).map((parameter, index) => { const latest = latestOf(parameter.id); return <button key={parameter.id} className={`metric-card ${index % 2 ? "aqua" : "coral"}`} onClick={() => { setTrendParameterId(parameter.id); switchTab("trend"); }}><span className="metric-label">{parameter.name}<i>最近</i></span><strong>{latest ? (latest.low === latest.high ? recordValueText(latest.low, latest) : `${recordValueText(latest.low, latest)}–${recordValueText(latest.high, latest)}`) : "--"}</strong><small>{parameter.unit}</small><p>{resultStatus(parameter.id)}</p></button>; })}</div>
          <section className="advice-section"><div className="home-section-title"><div><p className="eyebrow">根据最近检测</p><h2>建议先做这些</h2></div></div><div className="advice-list">{enabledParameters.map((parameter) => { const advice = adviceFor(parameter.id); return <article key={parameter.id} className={`advice-card ${advice.status}`}><div className="advice-head"><span>{advice.status === "good" ? "✓" : advice.status === "high" ? "↑" : advice.status === "low" ? "↓" : "i"}</span><div><small>{parameter.name} · 目标 {targetText(parameter.id)}</small><h3>{advice.title}</h3></div></div><p>{advice.summary}</p><ul>{advice.actions.map((action) => <li key={action}>{action}</li>)}</ul></article>; })}</div><details className="advice-basis"><summary>查看建议依据</summary><p>建议依据用户自定目标范围和最近一次人工确认结果生成。NO3/PO4 的营养输入、换水、过滤与吸附材料规则参考 Red Sea、Tropic Marin 和 Hanna 的公开资料；不同生物配置差异较大，请小幅调整并复测。</p><div><a href="https://redseafish.com/wp-content/uploads/2013/12/Algae-management-Program_Multilanguage-Manual_GB_DE_FR_SE_NL_SP_PT_JP_CH_17A.pdf" target="_blank" rel="noreferrer">Red Sea 营养盐管理</a><a href="https://www.tropic-marin.com/naehrstoffkontrolle?lang=en" target="_blank" rel="noreferrer">Tropic Marin 营养控制</a><a href="https://pages.hannainst.com/hubfs/006-finished-content/Aquarium/Saltwater-Aquarium-Water-Parameters-Guidelines-1.pdf" target="_blank" rel="noreferrer">Hanna 海水参数指南</a></div></details></section>
          <button className="manage-parameters" onClick={() => setParameterModal(true)}>＋ 管理 {tank?.name} 的关注指标</button>
          {homeDosingTasks.length > 0 && <section className="home-dosing-status">
            <div className="home-section-title"><div><p className="eyebrow">今日状态</p><h2>每日平衡</h2></div></div>
            <div className="home-task-list">{homeDosingTasks.map(maintenanceTaskCard)}</div>
          </section>}
          <section className="home-todos">
            <div className="home-section-title"><div><p className="eyebrow">仅今天 · {homeTaskGroups.length} 项</p><h2>今日待办</h2></div><button onClick={() => switchTab("tasks")}>查看任务</button></div>
            {homeTaskGroups.length ? <div className="home-task-list">{homeTaskGroups.map(({ key, task, isChemicalPlan }) => task.source === "maintenance-cycle" ? maintenanceTaskCard(task) : <article key={key} className={`panel next-task ${task.state}`}>
              <div className="section-head"><div><h2>{isChemicalPlan ? task.source === "alkalinity-plan" ? "碳酸氢钠补 KH 计划" : "PO4 氯化镧计划" : task.title}</h2><p>{isChemicalPlan ? `今日第 ${task.dayIndex}/${task.totalDays} 天 · 复测后决定` : `${task.cycle} · 今日事项`}</p></div><span className="overdue-pill">{task.state === "snoozed" ? "稍后提醒" : "今日待办"}</span></div>
              {task.detail && <p className="task-detail">{task.detail}</p>}
              <div className="task-actions"><button className="soft-button" onClick={() => delayTask(task.id, todayKey)}>延迟</button>{(isChemicalPlan || task.intervalDays) && <button className="soft-button" onClick={() => stopFutureTasks(task.id, todayKey)}>停止后续计划</button>}<button className="primary-button compact" onClick={() => completeTask(task.id, todayKey)}>当日任务已完成</button></div>
            </article>)}</div> : <div className="panel home-clear"><span>✓</span><div><h2>今天没有待办事项</h2><p>其他日期的未完成事项可在任务页查看。</p></div></div>}
          </section>
          <section className="home-trends"><div className="home-section-title"><div><p className="eyebrow">每屏 5 次 · 左右滑动查看历史</p><h2>所有参数变化趋势</h2>{tankRecords.some(r=>r.note==="历史演示数据 · 非真实检测") && <button onClick={() => {window.history.replaceState(null,"",window.location.pathname);setRecords(items=>items.filter(r=>!(r.tankId===tankId && r.note==="历史演示数据 · 非真实检测")));}}>清除当前缸演示数据</button>}</div><button onClick={() => switchTab("trend")}>趋势详情</button></div>{enabledParameters.map(parameter => <section key={`${tankId}-${parameter.id}`} className="panel trend-preview home-trend-card"><div className="section-head"><div><h2>{parameter.name} 变化</h2><p>{parameter.label} · {parameter.unit}</p></div><button className="target-chip" onClick={() => {setTrendParameterId(parameter.id);switchTab("trend");}}>查看详情</button></div><HomeHistoryBars records={tankRecords.filter(r=>r.parameterId===parameter.id)} unit={parameter.unit} name={parameter.name} /></section>)}</section>
          <p className="disclaimer">调整后复测，观察生物状态。</p>
        </section>}

        {tab === "test" && <section className="screen test-screen">
          <div className="page-title"><p className="eyebrow">水质检测</p><h1>{testStage === "setup" ? "准备检测" : "确认结果"}</h1><p>当前记录到 {tank?.name}</p></div>
          <div className="parameter-tabs">{enabledParameters.map((parameter) => <button key={parameter.id} className={selectedParameter.id === parameter.id ? "active" : ""} onClick={() => selectTestParameter(parameter.id)}><strong>{parameter.name}</strong><small>{parameter.label}</small></button>)}<button className="add-parameter-tab" onClick={() => setParameterModal(true)}>＋</button></div>
          {testStage === "setup" && selectedParameter.id === "kh" && <KhTitrationPanel key={tankId} onRecord={saveKhTitration} onCancel={() => setToast("本次结果未记录")} disabled={storageBlocked} />}
          {testStage === "setup" && <>{selectedParameter.id !== "kh" && <section className="timer-card"><TimerRing clock={detectionClock} total={timerTotal} running={timerRunning} locked={timerLocked} parameterName={selectedParameter.name} /><h2>按试剂说明设置等待时间</h2><p>计时结束后进入检测。</p>{!timerLocked && <div className="timer-customizer"><div className="timer-presets">{[180,300,600].map((seconds) => <button key={seconds} className={timerTotal === seconds ? "active" : ""} onClick={() => setTimerDuration(seconds)}>{seconds / 60} 分钟</button>)}</div><div className="custom-time-row"><span>自定义默认时间</span><label><input type="number" min="0" max="60" value={Math.floor(timerTotal/60)} onChange={(e) => setTimerDuration(Number(e.target.value)*60 + timerTotal%60)} />分</label><label><input type="number" min="0" max="59" value={timerTotal%60} onChange={(e) => setTimerDuration(Math.floor(timerTotal/60)*60 + Number(e.target.value))} />秒</label></div><small>10秒–60分钟，自动保存为默认时间。</small></div>}<button className="primary-button wide" onClick={() => setTimerRunning(!timerRunning)}>{timerRunning ? "暂停计时" : timerLocked ? "继续计时" : "开始计时"}</button>{timerLocked && !timerRunning && <button className="text-button" onClick={() => resetDetection()}>重新开始默认计时</button>}<button className="text-button" onClick={() => { setTimerRunning(false); if (["no3", "po4"].includes(selectedParameter.id)) { setPhotoMatchOpen(true); } else { setTestStage("result"); } }}>跳过计时，{["no3", "po4"].includes(selectedParameter.id) ? "直接拍照" : "直接录入"}</button></section>}<button className="manual-entry" onClick={() => { setTimerRunning(false); setTestStage("result"); }}><span>⌨</span><div><strong>手动录入 {selectedParameter.name}</strong><small>所有关注指标都支持手动记录</small></div><b>›</b></button></>}
          {selectedParameter.id === "no3" && testStage === "setup" && <button className="manual-entry" onClick={() => { setTimerRunning(false); setPhotoMatchOpen(true); }}><span>◈</span><div><strong>NO3 照片辅助比色</strong><small>框选、比较范围与插值，修改后选择是否记录</small></div><b>›</b></button>}
          {selectedParameter.id === "po4" && testStage === "setup" && <button className="manual-entry" onClick={() => {setTimerRunning(false);setPhotoMatchOpen(true);}}><span>◈</span><div><strong>PO4 照片辅助比色</strong><small>框选、分项判断，修改后选择是否记录</small></div><b>›</b></button>}

          {testStage === "result" && <section className="result-card"><p className="eyebrow">{selectedParameter.name} · {tank?.name}</p><h2>修改并确认检测结果</h2>{photoEstimate && <p>原始辅助范围 {photoEstimate.low}–{photoEstimate.high} mg/L · 插值 {photoEstimate.interpolation === null ? "未提供" : `${photoEstimate.interpolation} mg/L`}。</p>}<div className="field-row"><label>结果下限<input inputMode="decimal" value={resultLow} onChange={e => setResultLow(e.target.value)} /></label><label>结果上限<input inputMode="decimal" value={resultHigh} onChange={e => setResultHigh(e.target.value)} /></label></div>{["no3", "po4"].includes(selectedParameter.id) && <label className="field">插值 / 单值（可选）<input aria-label="插值 / 单值" inputMode="decimal" value={resultInterpolation} onChange={e => setResultInterpolation(e.target.value)} /><small>可留空；填写时需在范围内。</small></label>}{recordError && <p role="alert">{recordError}</p>}<button className="primary-button wide" onClick={saveDetection}>确认并保存结果</button><button className="text-button" onClick={() => { resetDetection(); setToast("本次结果未记录"); }}>本次不记录</button></section>}
        </section>}

        {tab === "trend" && <section className="screen trend-screen">
          <div className="page-title"><p className="eyebrow">历史趋势</p><h1>水质变化</h1><p>选择任意关注指标查看历史</p></div>
          <div className="parameter-tabs compact-tabs">{enabledParameters.map((parameter) => <button key={parameter.id} className={trendParameter.id === parameter.id ? "active" : ""} onClick={() => setTrendParameterId(parameter.id)}><strong>{parameter.name}</strong><small>{parameter.unit}</small></button>)}</div>
          <section className="panel chart-panel"><div className="chart-summary"><div><small>当前结果</small><strong>{latestOf(trendParameter.id) ? resultText(latestOf(trendParameter.id)!) : "暂无记录"}</strong></div><button className="target-chip" onClick={() => setTargetModal(true)}>目标 {targetText(trendParameter.id)}</button></div>{["no3", "po4"].includes(trendParameter.id) ? <RecordTrend key={`${tankId}-${trendParameter.id}`} records={trendRecords} unit={trendParameter.unit} showRange /> : <><div className="large-chart"><div className="grid-line l1"><span>{chartMax.toFixed(chartMax < 10 ? 2 : 0)}</span></div><div className="grid-line l2"><span>{(chartMax/2).toFixed(chartMax < 10 ? 2 : 0)}</span></div><div className="grid-line l3"><span>0</span></div>{trendTarget?.min !== null && trendTarget?.min !== undefined && trendTarget.max !== null && trendTarget.max !== undefined && <div className="target-zone" style={{ bottom: `${10 + trendTarget.min/chartMax*75}%`, height: `${Math.max(6,(trendTarget.max-trendTarget.min)/chartMax*75)}%` }} />}{trendRecords.slice(-6).map((record,index) => <button key={record.id} className="plot-point" onClick={() => { setEditRecord(record); setRecordError(""); }} style={{ left: `${12+index*16}%`, bottom: `${10+((record.low+record.high)/2)/chartMax*75}%` }}><i /><span>{record.low === record.high ? recordValueText(record.low, record) : `${recordValueText(record.low, record)}–${recordValueText(record.high, record)}`}</span></button>)}</div></>}<div className="chart-axis"><span>较早</span><span>最近</span></div></section>
          <div className="section-head list-heading"><div><p className="eyebrow">{trendParameter.name}</p><h2>检测记录</h2></div><button onClick={() => { selectTestParameter(trendParameter.id); switchTab("test"); }}>＋ 添加</button></div>
          <PagedRecordList key={`${tankId}-${trendParameter.id}`} items={tankRecords.filter(record=>record.parameterId===trendParameter.id).sort((a,b)=>historyDate(b.date,new Date().getFullYear()).time-historyDate(a.date,new Date().getFullYear()).time||b.id-a.id)} renderItem={record=><button key={record.id} className="record-row" onClick={()=>{setEditRecord(record);setRecordError("");}}><span className="parameter-badge custom-badge">{trendParameter.name.slice(0,3)}</span><div><strong>{resultText(record)}</strong>{["no3","po4"].includes(record.parameterId)&&<p>插值 / 单值：{recordPoint(record)??"未填写"} {recordPoint(record)!==null?trendParameter.unit:""}</p>}<small>{recordDateLabel(record.date)}</small></div><span>{record.edited&&<i>已修改</i>} ›</span></button>} />
        </section>}

        {tab === "tasks" && <section className="screen tasks-screen">
          <div className="page-title row-title"><div><p className="eyebrow">维护计划</p><h1>任务日历</h1><p>{pendingPlanGroups.length} 项待处理 · 所选日完成 {completedDateTasks.length} 项</p></div><button className="round-add" aria-label="添加维护任务" onClick={openNewTaskModal}>＋</button></div>
          <section className="task-calendar">
            <div className="calendar-head"><button aria-label="上个月" onClick={() => changeCalendarMonth(-1)}>‹</button><div><strong>{calendarMonthLabel}</strong><button onClick={showTodayInCalendar}>今天</button></div><button aria-label="下个月" onClick={() => changeCalendarMonth(1)}>›</button></div>
            <div className="calendar-weekdays">{["一", "二", "三", "四", "五", "六", "日"].map((day) => <span key={day}>{day}</span>)}</div>
            <div className="calendar-grid">{calendarDays.map((day) => {
              const dayTasks = calendarOccurrencesForDate(day.key);
              return <button key={day.key} className={`${day.inMonth ? "" : "outside"} ${day.key === todayKey ? "today" : ""} ${day.key === selectedCalendarDate ? "selected" : ""}`} onClick={() => setSelectedCalendarDate(day.key)}>
                <span className="calendar-day-number">{day.date.getDate()}</span>
                <div className="calendar-day-tasks">{dayTasks.slice(0, 3).map(({ task, state }) => <small key={`${task.id}-${day.key}`} className={`${isFiniteChemicalPlanSource(task.source) ? "lanthanum" : ""} ${state === "done" || state === "skipped" ? "handled" : ""}`}><b>{state === "done" ? "✓" : state === "skipped" ? "–" : "•"}</b>{task.title}</small>)}{dayTasks.length > 3 && <small>+{dayTasks.length - 3} 项</small>}</div>
              </button>;
            })}</div>
            <div className="calendar-selected daily-agenda">
              <div className="agenda-heading"><div><small>当天待办</small><strong>{selectedDateLabel}</strong></div><span>{selectedDateTasks.length} 项</span></div>
              {selectedDateTasks.some(({ task }) => task.source !== "maintenance-cycle") && <p className="daily-agenda-hint">未完成自动顺延；下次按实际完成日期安排。</p>}
              {selectedDateTasks.length ? <div className="daily-task-list">{selectedDateTasks.map(({ task, state, occurrenceDate }) => {
                if (task.source === "maintenance-cycle") return maintenanceTaskCard(task);
                const handled = state === "done" || state === "skipped";
                const snoozedUntil = task.intervalDays ? task.snoozedUntilByDate?.[occurrenceDate] : task.snoozedUntil;
                const snoozedLabel = snoozedUntil ? new Intl.DateTimeFormat("zh-CN", { hour: "2-digit", minute: "2-digit", hour12: false }).format(new Date(snoozedUntil)) : "稍后";
                const stateLabel = state === "done" ? "已完成" : state === "skipped" ? "已跳过" : state === "snoozed" ? `稍后至 ${snoozedLabel}` : state === "due" ? "待完成" : "计划中";
                return <article key={`${task.id}-${occurrenceDate}`} className={`daily-task ${state}`}>
                  <div className="daily-task-main"><span className="task-state">{stateLabel}</span><h3>{task.title}</h3><p>{task.cycle} · {occurrenceDate} {taskReminderTime(task)}</p></div>
                  {task.detail && <details className="daily-task-detail"><summary>查看执行说明</summary><p>{task.detail}</p></details>}
                  {handled ? <div className="daily-task-handled"><div className={`daily-task-result ${state}`}>{state === "done" ? "✓ 当日任务已完成" : "– 当日计划已停止"}</div>{state === "done" && <button className="daily-task-reopen" onClick={() => reopenTask(task.id, occurrenceDate)}>重新标记为未完成</button>}</div> : <div className="daily-task-actions"><button className="complete-once" onClick={() => completeTask(task.id, occurrenceDate)}>✓ 当日任务已完成</button><button className="soft-button" onClick={() => delayTask(task.id, occurrenceDate)}>延迟</button><button className="skip-once" onClick={() => task.intervalDays && !task.oneOff || isFiniteChemicalPlanSource(task.source) ? stopFutureTasks(task.id, occurrenceDate) : skipTask(task.id, occurrenceDate)}>{task.intervalDays && !task.oneOff || isFiniteChemicalPlanSource(task.source) ? "停止后续计划" : "跳过本次"}</button></div>}
                </article>;
              })}</div> : <p>当天暂无事项</p>}
            </div>
          </section>
          <div className="list-section-title"><strong>计划与所选日记录</strong><small>已完成记录随上方所选日期切换</small></div>
          <div className="segmented" role="tablist" aria-label="任务筛选"><button role="tab" aria-selected={taskFilter === "pending"} className={taskFilter === "pending" ? "active" : ""} onClick={() => setTaskFilter("pending")}>待处理 <span>{pendingPlanGroups.length}</span></button><button role="tab" aria-selected={taskFilter === "completed"} className={taskFilter === "completed" ? "active" : ""} onClick={() => setTaskFilter("completed")}>已完成 <span>{completedDateTasks.length}</span></button><button role="tab" aria-selected={taskFilter === "all"} className={taskFilter === "all" ? "active" : ""} onClick={() => setTaskFilter("all")}>全部 <span>{allPlanGroups.length}</span></button></div>
          <div className="task-list">{visibleTaskGroups.map(({ key, task, members, isChemicalPlan }) => {
            if (task.source === "maintenance-cycle") return maintenanceTaskCard(task);
            if (isChemicalPlan) { return <article key={key} className="task-card chemical-plan-summary">
              <div className="task-top"><div><span className="task-state">合并计划 · 剩余 {members.length} 天待处理</span><h2>{task.source === "alkalinity-plan" ? "碳酸氢钠补 KH 计划" : "PO4 氯化镧计划"}</h2><p>{taskDisplayDate(members[0], todayKey)} 至 {taskDisplayDate(members.at(-1)!, todayKey)}</p><small className="next-cycle">每天的剂量和完成状态保留在日历中，不会一次完成整个计划。</small></div></div>
              <div className="task-actions"><button className="soft-button" onClick={() => setChemicalPlanDetails({ planId: task.planId!, source: task.source as ChemicalPlanDetails["source"] })}>查看每日安排</button><button className="soft-button" onClick={() => stopChemicalPlan(members[0].id, false)}>停止后续计划</button></div>
            </article>; }
            const handled = taskFilter === "completed" || task.state === "done" || task.state === "skipped";
            const recurring = Boolean(task.intervalDays && !task.oneOff);
            const nextOccurrence = taskDisplayDate(task, todayKey) ?? todayKey;
            const recurringPending = recurring && !handled;
            const stateLabel = taskFilter === "completed" ? "所选日已完成" : recurring ? `每 ${task.intervalDays} 天重复` : task.state === "due" ? "已到期" : task.state === "snoozed" ? "稍后提醒" : task.state === "done" ? "已完成" : task.state === "skipped" ? "已跳过" : "即将到期";
            return <article key={task.id} className={`task-card ${task.state}`}><div className="task-top"><button className={`check-button ${handled ? "checked" : ""}`} aria-label={recurring ? `${task.title}是重复计划` : handled ? stateLabel : `完成${task.title}`} disabled={handled || recurring} onClick={() => completeTask(task.id)}>{recurring ? "↻" : "✓"}</button><div><span className="task-state">{stateLabel}</span><h2>{task.title}</h2><p>{taskFilter === "completed" ? `${task.cycle} · ${selectedCalendarDate}` : handled ? `${task.cycle} · ${task.handledAt ?? "已处理"}` : `${task.cycle} · ${nextOccurrence} ${taskReminderTime(task)}`}</p>{handled && taskFilter !== "completed" && <small className="next-cycle">{task.due}</small>}{recurring && taskFilter !== "completed" && <small className="next-cycle">下次按实际完成日期安排。</small>}</div>{recurring && <button type="button" className="more-button" aria-label={`编辑${task.title}`} title="编辑任务" onClick={() => openRecurringTaskEditor(task)}>•••</button>}</div>{task.detail && <p className="task-detail">{task.detail}</p>}{taskFilter === "completed" && <div className="task-actions"><button className="soft-button" onClick={() => reopenTask(task.id, selectedCalendarDate)}>重新标记为未完成</button>{task.rolling?.completed.at(-1)?.completedDate === selectedCalendarDate && <button className="soft-button" onClick={() => openTaskAction("correct", task.id, selectedCalendarDate)}>修改完成日期</button>}</div>}{!handled && !recurring && <div className="task-actions"><button className="soft-button" onClick={() => delayTask(task.id)}>延迟</button><button className="soft-button" onClick={() => skipTask(task.id)}>跳过本次</button></div>}{!handled && recurring && <div className="task-actions">{recurringPending && <button className="soft-button" onClick={() => delayTask(task.id, nextOccurrence)}>延迟</button>}<button className="soft-button" onClick={() => stopFutureTasks(task.id, todayKey)}>停止后续计划</button>{recurringPending && <button className="primary-button compact" onClick={() => completeTask(task.id, nextOccurrence)}>当日任务已完成</button>}</div>}</article>;
          })}{!visibleTaskGroups.length && <div className="empty-state"><span>✓</span><h2>{taskFilter === "completed" ? "所选日期没有已完成任务" : taskFilter === "all" ? "还没有周期任务或进行中的加药计划" : "今天都完成了"}</h2><p>{taskFilter === "completed" ? "选择日期查看当天已完成记录。" : taskFilter === "all" ? "添加周期任务，或先制定 KH/PO4 加药计划。" : "新的维护任务会显示在这里。"}</p></div>}</div>
          <button className="primary-button wide" onClick={openNewTaskModal}>＋ 添加维护任务</button>
          <section className="notification-note"><span>🔔</span><div><strong>网页内到期弹窗提醒</strong><p>{notificationEnabled ? "已开启；网站打开时会弹出当天待办。" : "已关闭；可在这里或设置中开启。"}</p></div><button className={`toggle-switch ${notificationEnabled ? "on" : ""}`} role="switch" aria-checked={notificationEnabled} aria-label="网页内到期弹窗提醒" onClick={toggleNotificationReminder}><i /></button></section>
        </section>}
      </div>
      <nav className="bottom-nav">{navItems.map((item) => <button key={item.id} className={tab === item.id ? "active" : ""} onClick={() => switchTab(item.id)}><span>{item.icon}</span><small>{item.label}</small></button>)}</nav>
    </section>

    <aside className="desktop-note"><span>交互式手机 Demo</span><h2>澜礁<br />海缸助手</h2><p>自定义关注指标，为每个海缸建立属于自己的水质档案。</p><div className="desktop-features"><span>参数可扩展</span><span>每缸独立目标</span><span>历史趋势</span></div></aside>

    {fishModal && <div className="modal-backdrop" onMouseDown={() => setFishModal(false)}><FishManagerSheet tankId={tankId} tankName={tank?.name ?? "当前海缸"} stock={tankFishStock} onClose={() => setFishModal(false)} onSave={(items) => { setFishStock((current) => [...current.filter((item) => item.tankId !== tankId), ...items]); setFishModal(false); announceSaved(`${tank?.name} 的鱼类档案已保存`); }} /></div>}

    {chemicalPlanDetails && <div className="modal-backdrop" role="dialog" aria-modal="true" aria-labelledby="plan-details-title" onMouseDown={() => setChemicalPlanDetails(null)}>
      <section className="sheet plan-details-sheet" onMouseDown={(event) => event.stopPropagation()}>
        <div className="sheet-handle" />
        <div className="section-head"><div><p className="eyebrow">完整计划 · {chemicalPlanDetailTasks.length} 天</p><h2 id="plan-details-title">{chemicalPlanDetails.source === "alkalinity-plan" ? "碳酸氢钠补 KH" : "PO4 氯化镧"}每日安排</h2></div><button className="icon-button" onClick={() => setChemicalPlanDetails(null)}>×</button></div>
        <p className="form-hint">完成或延迟，请到任务日历操作。</p>
        <div className="plan-detail-list">{chemicalPlanDetailTasks.map((task) => {
          const occurrenceDate = taskDisplayDate(task, todayKey) ?? todayKey;
          const state = taskStateOnDate(task, occurrenceDate, todayKey);
          const stateLabel = state === "done" ? "已完成" : state === "skipped" ? "已停止" : state === "snoozed" ? "稍后处理" : state === "due" ? "待完成" : "计划中";
          return <article key={task.id} className={`plan-detail-item ${state}`}><div><span>{occurrenceDate}</span><b>{stateLabel}</b></div><h3>{task.title}</h3><p>{task.cycle} · {occurrenceDate} {taskReminderTime(task)}</p>{task.detail && <details><summary>查看任务说明</summary><p>{task.detail}</p></details>}</article>;
        })}</div>
      </section>
    </div>}

    {settingsOpen && <div className="modal-backdrop" onMouseDown={() => setSettingsOpen(false)}><section className="sheet" onMouseDown={(e) => e.stopPropagation()}><div className="sheet-handle" /><div className="section-head"><div><p className="eyebrow">偏好与数据</p><h2>设置</h2></div><button className="icon-button" onClick={() => setSettingsOpen(false)}>×</button></div><button className="settings-row" onClick={() => { setSettingsOpen(false); setTankModal({ mode: "list" }); }}><span>◌</span><div><strong>海缸管理</strong><small>{tanks.length} 个海缸</small></div><b>›</b></button><button className="settings-row" onClick={() => { setSettingsOpen(false); setParameterModal(true); }}><span>＋</span><div><strong>关注指标管理</strong><small>{tank?.name} · {enabledParameters.map((item) => item.name).join("、")}</small></div><b>›</b></button><button className="settings-row" onClick={() => { setSettingsOpen(false); setTargetModal(true); }}><span>⌁</span><div><strong>水质目标范围</strong><small>分别设置 {enabledParameters.length} 项指标</small></div><b>›</b></button><button className="settings-row" onClick={() => { setSettingsOpen(false); setMaintenanceChemical("po4"); setMaintenanceModal(true); }}><span>滴</span><div><strong>PO₄ / KH 稳定滴定配方</strong><small>每日变化、配液体积与预计可用天数</small></div><b>›</b></button><button className="settings-row" onClick={openLanthanumCalculator}><span>La</span><div><strong>PO4 氯化镧理论计划</strong><small>500 mL 母液、每日稀释与日历待办</small></div><b>›</b></button><button className="settings-row" onClick={openAlkalinityCalculator}><span>KH</span><div><strong>碳酸氢钠补 KH 理论计划</strong><small>理论克数、分日复测与日历待办</small></div><b>›</b></button><button className="settings-row" onClick={openSalinityCalculator}><span>SG</span><div><strong>海盐配制计算器</strong><small>按初始比重、目标比重与水量估算海盐</small></div><b>›</b></button><div className="settings-row reminder-setting"><span>🔔</span><div><strong>到期弹窗提醒</strong><small>{notificationEnabled ? "已开启 · 网站打开时提醒" : "已关闭"}</small></div><button className={`toggle-switch ${notificationEnabled ? "on" : ""}`} role="switch" aria-checked={notificationEnabled} aria-label="到期弹窗提醒" onClick={toggleNotificationReminder}><i /></button></div><p className="settings-boundary">提醒仅在网页打开时生效。</p><button className="danger-link" onClick={() => { localStorage.removeItem("reef-demo-state-v4"); localStorage.removeItem("reef-demo-state-v5"); localStorage.removeItem("reef-demo-state-v6"); localStorage.removeItem("reef-demo-state-v7"); localStorage.removeItem("reef-demo-state-v8"); localStorage.removeItem("reef-demo-state-v9"); localStorage.removeItem("reef-demo-state-v10"); location.reload(); }}>恢复演示数据</button></section></div>}

    {salinityModal && <div className="modal-backdrop"><section className="sheet salinity-sheet"><div className="sheet-handle" /><div className="section-head"><div><p className="eyebrow">配水辅助工具</p><h2>海盐配制计算器</h2></div><button className="icon-button" onClick={() => setSalinityModal(false)}>×</button></div>{!salinityResult ? <form onSubmit={submitSalinityCalculation}><div className="salinity-explainer"><strong>按比重（SG）计算</strong><p>无盐水填0；每升用盐量按包装填写。</p></div><div className="field-row"><label>初始比重（SG）<input name="initialSg" type="number" step="0.001" min="0" max="1.04" required defaultValue={0} /><small className="field-note">0 = RO/DI 无盐水</small></label><label>目标比重（SG）<input name="targetSg" type="number" step="0.001" min="1.001" max="1.04" required defaultValue={DEFAULT_TARGET_SG} /></label></div><label className="field">需要配制的水量<input name="waterVolumeL" type="number" step="any" min="0.1" required defaultValue={20} /><small className="field-note">加入海盐前的起始水量，单位 L</small></label><details className="salinity-calibration"><summary>海盐包装校准（已带示例值）</summary><div className="field-row"><label>包装每升用盐量<input name="saltGramsPerLitreAtReference" type="number" step="0.1" min="0.1" max="100" required defaultValue={DEFAULT_SALT_GRAMS_PER_LITRE_AT_REFERENCE} /><small className="field-note">g/L · 请按包装修改</small></label><label>对应包装比重<input name="labelReferenceSg" type="number" step="0.0001" min="1.0001" max="1.04" required defaultValue={DEFAULT_LABEL_REFERENCE_SG} /><small className="field-note">Red Sea 示例为 SG 1.0255</small></label></div></details>{salinityError && <p className="calculation-error" role="alert">{salinityError}</p>}<button className="primary-button wide" type="submit">计算需要多少海盐</button><p className="chemical-note">溶解后用校准的盐度计复测。</p></form> : <div className="salinity-result"><div className="calculation-summary"><article className="salinity-total"><small>{salinityResult.waterVolumeL} L 起始水量 · {salinityResult.initialSg === 0 ? "无盐水" : `SG ${salinityResult.initialSg.toFixed(3)}`} → SG {salinityResult.targetSg.toFixed(3)}</small><strong>约 {formatSaltMass(salinityResult.requiredSaltG)} 海盐</strong><p>按包装基准 {salinityResult.saltGramsPerLitreAtReference} g/L（对应 SG {salinityResult.labelReferenceSg.toFixed(4)}）估算</p><code>计算值 {salinityResult.requiredSaltG.toFixed(2)} g</code></article><article><small>先加入估算量的 90%</small><strong>{formatSaltMass(salinityResult.initialAdditionG)}</strong><p>充分溶解、循环并在产品标注温度下复测，再逐步加入预留部分。</p><code>预留约 {formatSaltMass(salinityResult.reservedAdjustmentG)} 用于微调</code></article></div><div className="impact-panel"><strong>建议操作顺序</strong><ul><li>先量取 {salinityResult.waterVolumeL} L RO/DI 水，再把盐逐步加入水中并持续循环；不要把水直接倒在干盐上。</li><li>先加入约 90%，完全溶解并按品牌说明达到参考温度后测量，再少量补盐到 SG {salinityResult.targetSg.toFixed(3)}。</li><li>在独立容器中配制；不要在有鱼或珊瑚的展示缸里直接混合海盐。</li></ul></div><details className="protocol-source"><summary>计算依据与边界</summary><p>估算式：水量 × 包装标注的每升用盐量 ×（目标 SG − 初始 SG）÷（包装基准 SG − 1.000）。SG 与干盐质量不是跨品牌通用的一一对应关系，所以包装基准可以修改，结果不替代实测。</p><div><a href="https://g1.redseafish.com/wp-content/uploads/2013/12/10031-Red-Sea-Salt-manual.pdf" target="_blank" rel="noreferrer">Red Sea 配盐说明</a><a href="https://www.instantocean.com/en/instant-answers/faqs/sea-salt" target="_blank" rel="noreferrer">Instant Ocean 配制建议</a></div></details><button className="soft-button wide salinity-recalculate" onClick={() => { setSalinityResult(null); setSalinityError(""); }}>重新计算</button><p className="disclaimer">这是配盐起始估算，不是最终称量保证；以你所用海盐包装和校准量具的实测结果为准。</p></div>}</section></div>}

    {lanthanumModal && <div className="modal-backdrop">
      <section className="sheet lanthanum-sheet">
        <div className="sheet-handle" />
        <div className="section-head"><div><p className="eyebrow">{tank?.name} · 配方计算</p><h2>氯化镧降低 PO4</h2></div><button className="icon-button" onClick={() => setLanthanumModal(false)}>×</button></div>
        {!lanthanumPlan ? <form className="lanthanum-form" onSubmit={submitLanthanumCalculation}>
          <div className="theory-warning"><strong>母液强度</strong><p>每1 mL母液对应100 L水体降低0.1 mg/L PO4；改变体积不改变浓度。</p></div>
          {latestPo4Record && latestPo4Record.low !== latestPo4Record.high && <p className="calculation-error">最近 PO4 是 {latestPo4Record.low}–{latestPo4Record.high} mg/L 的范围，请输入复测单值。</p>}
          <div className="field-row"><label>当前 PO4（按 PO4 计）<input name="currentPo4MgL" type="number" step="any" min="0.030001" required defaultValue={exactLatestPo4} placeholder="当前单值 mg/L" /></label><label>精确目标 PO4<input name="targetPo4MgL" type="number" step="any" min="0.03" required defaultValue={defaultCalculatorTargets.po4} placeholder="最低 0.03 mg/L" /><small className="field-note">默认取目标范围中值，可修改</small></label></div>
          <div className="field-row"><label>实际净水量<input name="netWaterVolumeL" type="number" step="any" min="0.1" required defaultValue={200} placeholder="扣除活石底砂后的 L" /></label><label>母液最终体积<input name="stockFinalVolumeMl" type="number" step="1" min="1" required defaultValue={DEFAULT_PLAN_STOCK_FINAL_VOLUME_ML} /><small className="field-note">mL · 溶解后定容到此体积</small></label></div>
          <label className="field">计划单日最大降幅（0.1–0.5）<input name="maxDailyPo4DropMgL" type="number" step="0.1" min="0.1" max="0.5" required defaultValue={0.1} /></label>
          {lanthanumError && <p className="calculation-error" role="alert">{lanthanumError}</p>}
          <button className="primary-button wide" type="submit">计算母液配方、用量与计划天数</button>
          <p className="chemical-note">固定采用 LaCl₃·7H₂O、纯度 99.9%。默认 500 mL 时称取约 19.5713 g；选择其他体积后质量等比例变化。0.1–0.5 mg/L 不是已验证的通用安全降幅。</p>
        </form> : <div className="lanthanum-result">
          {lanthanumPlan.previewOnly && <p className="calendar-saved-note" role="status">仅计算预览 · 未加入日历，原计划和处理记录保持不变</p>}
          <div className="theory-warning"><strong>这是理论化学计量，不是安全承诺</strong><p>海水副反应、活石释放、过滤效率和生物反应都会让实际结果偏离；系统没有增加任何“效率补偿”。</p></div>
          <div className="calculation-summary">
            <article><small>母液 · 最终 {formatVolume(lanthanumPlan.planStockFinalVolumeMl)}</small><strong>{formatMass(lanthanumPlan.solidMassToWeighG)}</strong><p>{lanthanumPlan.saltFormula}，固定纯度 {lanthanumPlan.purityPercent}%</p><code>{lanthanumPlan.solidMassToWeighG.toFixed(6)} g · {lanthanumPlan.planStockConcentrationMgPerMl.toFixed(6)} mg/mL</code></article>
            <article><small>按单日最大降幅估算</small><strong>至少 {lanthanumPlan.days} 天</strong><p>从 {lanthanumPlan.currentPo4MgL} 降到 {lanthanumPlan.targetPo4MgL} mg/L</p><code>全程理论需母液 {formatVolume(lanthanumPlan.totalStockRequiredMl)} · 约 {lanthanumPlan.stockBatchesRequired} 批</code></article>
            <article><small>下一次 500 mL 工作液</small><strong>{formatVolume(lanthanumFirstDay?.stockToUseMl ?? 0)} 母液</strong><p>加 RO/DI 水定容至最终 500 mL（约需 {formatVolume(lanthanumFirstDay?.rodiToFinalVolumeMl ?? 0)} 水）</p><code>理论对应 PO4 降幅不超过 {lanthanumFirstDay?.theoreticalPo4DropMgL.toFixed(6)} mg/L</code></article>
            {lanthanumPlan.days > 1 && <article><small>理论计划最后一日</small><strong>{formatVolume(lanthanumLastDay?.stockToUseMl ?? 0)} 母液</strong><p>最后一日仅使用剩余理论份额；每天实测后天数会变化。</p><code>理论降幅 {lanthanumLastDay?.theoreticalPo4DropMgL.toFixed(6)} mg/L</code></article>}
          </div>
          <div className="impact-panel"><strong>投加注意</strong><ul><li>分日缓慢投加，避免PO4骤降。</li><li>在过滤或蛋分入口上游投加并捕获沉淀，不直接加入展示缸。</li><li>每日复测；达到目标、PO4≤0.03 mg/L或生物异常时停止。</li></ul></div>
          <details className="protocol-source"><summary>计算依据</summary><p>理论反应：La³⁺ + PO₄³⁻ → LaPO₄(s)，摩尔比 1:1。本结果不补偿海水副反应，也不代表沉淀会被完全捕获。</p><div><a href="https://pubchem.ncbi.nlm.nih.gov/compound/165791" target="_blank" rel="noreferrer">PubChem 七水合 LaCl₃</a><a href="https://pubchem.ncbi.nlm.nih.gov/compound/Phosphate-Ion" target="_blank" rel="noreferrer">PubChem PO₄</a><a href="https://pmc.ncbi.nlm.nih.gov/articles/PMC5441187/" target="_blank" rel="noreferrer">低磷生物影响研究</a><a href="https://www.brightwellaquatics.com/products/phosphat-et.php" target="_blank" rel="noreferrer">厂家过滤与风险说明</a></div></details>
          {lanthanumPlan.previewOnly ? <>
            <details className="protocol-source"><summary>本次计算的全部每日安排（未加入日历）</summary>{lanthanumPlan.dailyPlan.map(day => <article key={day.day}><strong>第 {day.day} 天</strong><p>PO4 {day.startingPo4MgL.toFixed(3)} → {day.endingPo4MgL.toFixed(3)} mg/L；取母液 {formatVolume(day.stockToUseMl)}，加 RO/DI 水定容至 {formatVolume(day.dilutedFinalVolumeMl)}。</p></article>)}</details>
            <button className="soft-button wide" onClick={() => setLanthanumModal(false)}>关闭计算结果</button>
          </> : <><p className="calendar-saved-note">✓ 已加入任务日历</p><button className="primary-button wide" onClick={() => { setLanthanumModal(false); setTab("tasks"); }}>查看已加入的任务日历</button></>}<p className="disclaimer">每天复测PO4/KH；达到目标或出现异常时停止。</p>
        </div>}
      </section>
    </div>}

    {parameterModal && <div className="modal-backdrop"><section className="sheet"><div className="sheet-handle" /><div className="section-head"><div><p className="eyebrow">{tank?.name}</p><h2>关注指标</h2></div><button className="icon-button" onClick={() => setParameterModal(false)}>×</button></div><p className="form-hint">选择要关注的指标。</p><div className="parameter-manager">{parameters.map((parameter) => { const enabled = enabledTargets.some((target) => target.parameterId === parameter.id); return <button key={parameter.id} className={enabled ? "enabled" : ""} onClick={() => toggleParameter(parameter.id)}><span className="parameter-mark">{parameter.name.slice(0,3)}</span><div><strong>{parameter.name} · {parameter.label}</strong><small>{parameter.unit} {parameter.builtIn ? "· 内置" : "· 自定义"}</small></div><b>{enabled ? "已关注 ✓" : "＋ 添加"}</b></button>; })}</div><button className="primary-button wide" onClick={() => { setParameterModal(false); setCustomParameterModal(true); }}>＋ 新增自定义参数</button></section></div>}

    {customParameterModal && <div className="modal-backdrop"><form className="sheet" onSubmit={(event) => { event.preventDefault(); const data = new FormData(event.currentTarget); const name = String(data.get("name")).trim(); const label = String(data.get("label")).trim() || name; const unit = String(data.get("unit")).trim(); if (parameters.some((item) => item.name.toLowerCase() === name.toLowerCase())) { setToast("已有同名指标"); return; } const id = `custom-${Date.now()}`; setParameters((items) => [...items, { id, name, label, unit, builtIn: false, photoSupported: false }]); setTargets((items) => [...items, { tankId, parameterId: id, min: null, max: null }]); setSelectedParameterId(id); setTrendParameterId(id); setCustomParameterModal(false); setTargetModal(true); announceSaved(`${name} 已加入 ${tank?.name}`); }}><div className="sheet-handle" /><div className="section-head"><div><p className="eyebrow">自定义</p><h2>新增水质参数</h2></div><button type="button" className="icon-button" onClick={() => setCustomParameterModal(false)}>×</button></div><label className="field">参数简称<input name="name" required maxLength={12} placeholder="例如：Sr" /></label><label className="field">参数名称<input name="label" maxLength={24} placeholder="例如：锶（可选）" /></label><label className="field">单位<input name="unit" required maxLength={12} placeholder="例如：mg/L、ppt、pH" /></label><button className="primary-button wide" type="submit">创建并设置目标</button><p className="disclaimer">自定义参数使用手动录入。</p></form></div>}

    {targetModal && <div className="modal-backdrop"><form className="sheet target-sheet" onSubmit={(event) => { event.preventDefault(); const data = new FormData(event.currentTarget); const next = enabledParameters.map((parameter) => { const minRaw = String(data.get(`min-${parameter.id}`) ?? ""); const maxRaw = String(data.get(`max-${parameter.id}`) ?? ""); return { tankId, parameterId: parameter.id, min: minRaw === "" ? null : Number(minRaw), max: maxRaw === "" ? null : Number(maxRaw) }; }); if (next.some((item) => item.min !== null && item.max !== null && item.min > item.max)) { setToast("目标下限不能大于上限"); return; } setTargets((items) => [...items.filter((item) => item.tankId !== tankId), ...next]); setTargetModal(false); announceSaved(`${tank?.name} 的目标范围已更新`); }}><div className="sheet-handle" /><div className="section-head"><div><p className="eyebrow">{tank?.name}</p><h2>水质目标范围</h2></div><button type="button" className="icon-button" onClick={() => setTargetModal(false)}>×</button></div><p className="form-hint">留空则不判断高低。</p>{enabledParameters.map((parameter) => { const target = targetOf(parameter.id); return <div className="target-group" key={parameter.id}><div><strong>{parameter.name} · {parameter.label}</strong><small>{parameter.unit}</small></div><div className="field-row"><label>目标下限<input name={`min-${parameter.id}`} type="number" step="any" min="0" defaultValue={target?.min ?? ""} placeholder="可留空" /></label><label>目标上限<input name={`max-${parameter.id}`} type="number" step="any" min="0" defaultValue={target?.max ?? ""} placeholder="可留空" /></label></div></div>; })}<button className="primary-button wide" type="submit">保存当前海缸目标</button></form></div>}

    {editRecord && <div className="modal-backdrop"><form className="sheet" onSubmit={saveEditedRecord}><div className="sheet-handle" /><div className="section-head"><div><p className="eyebrow">历史记录</p><h2>编辑检测结果</h2></div><button type="button" className="icon-button" onClick={() => setEditRecord(null)}>×</button></div><label className="field">所属海缸<select name="tankId" defaultValue={editRecord.tankId}>{tanks.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label><div className="field-row"><label>检测指标<select name="parameterId" defaultValue={editRecord.parameterId}>{parameters.map((item) => <option key={item.id} value={item.id}>{item.name} · {item.unit}</option>)}</select></label><label>检测时间<input name="date" defaultValue={editRecord.date} /></label></div><div className="field-row"><label>结果下限<input name="low" type="number" step="any" min="0" defaultValue={editRecord.low} /></label><label>结果上限<input name="high" type="number" step="any" min="0" defaultValue={editRecord.high} /></label></div><label className="field">NO3 / PO4 插值（可选）<input name="interpolation" type="number" step="any" min="0" defaultValue={editRecord.interpolation ?? ""} /></label>{recordError && <p role="alert">{recordError}</p>}<label className="field">备注<textarea name="note" defaultValue={editRecord.note} rows={3} /></label><div className="original-estimate"><strong>原始记录</strong><span>{resultText(editRecord)}</span><small>保存修改后会立即更新对应指标趋势。</small>{editRecord.photoEstimate && <small>原始拍照建议：{editRecord.photoEstimate.low}–{editRecord.photoEstimate.high}，插值 {editRecord.photoEstimate.interpolation === null ? "未提供" : `${editRecord.photoEstimate.interpolation} mg/L`}</small>}</div><button className="primary-button wide" type="submit">保存修改</button></form></div>}

    {reminderOpen && notificationEnabled && <div className="modal-backdrop reminder-backdrop" role="dialog" aria-modal="true" aria-labelledby="reminder-title"><section className="sheet reminder-sheet"><div className="reminder-icon">🔔</div><p className="eyebrow">{calendarDateLabel(new Date())}</p><h2 id="reminder-title">今天有 {todayReminderTasks.length} 项待办</h2><div className="reminder-task-list">{todayReminderTasks.slice(0, 5).map(({ task, occurrenceDate }) => <div key={`${task.id}-${occurrenceDate}`}><span className={isFiniteChemicalPlanSource(task.source) ? "lanthanum-dot" : ""} /><div><strong>{task.title}</strong><small>{task.cycle} · {task.due}</small></div></div>)}</div>{todayReminderTasks.length > 5 && <p className="form-hint">另有 {todayReminderTasks.length - 5} 项，请进入当天任务查看。</p>}<button className="primary-button wide" onClick={() => dismissTodayReminder(true)}>查看并处理当天任务</button><button className="soft-button wide" onClick={() => dismissTodayReminder(false)}>今天不再提示</button><p className="disclaimer">提醒仅在网页打开时生效。</p></section></div>}

    {taskAction && (taskAction.mode === "delay"
      ? <TaskActionDialog key={"delay-" + taskAction.id} mode="delay" title={taskAction.title} today={todayKey} onClose={() => setTaskAction(null)} onConfirm={confirmTaskAction} />
      : <TaskActionDialog key={"complete-" + taskAction.id} mode="complete" title={taskAction.title} today={todayKey} initialCompletedDate={taskAction.mode === "correct" ? taskAction.occurrenceDate : todayKey} onClose={() => setTaskAction(null)} onConfirm={confirmTaskAction} />)}

    {taskModal && <div className="modal-backdrop"><form className="sheet" onSubmit={saveMaintenanceTask}><div className="sheet-handle" /><div className="section-head"><div><p className="eyebrow">当前海缸</p><h2>{editingTask ? "编辑重复任务" : "添加维护任务"}</h2></div><button type="button" className="icon-button" onClick={closeTaskModal}>×</button></div><label className="field">任务名称<input name="title" required placeholder="例如：清洗滤棉" defaultValue={editingTask?.title ?? ""} /></label><div className="field-row"><label>开始日期<input name="startDate" required type="date" defaultValue={editingTask ? taskDisplayDate(editingTask, todayKey) : dateKey(addDays(new Date(), 1))} /></label><label>提醒时间<input name="reminderTime" type="time" defaultValue={editingTask ? taskReminderTime(editingTask) : "09:00"} /></label></div><label className="field">重复间隔（天）<input name="interval" required type="number" min="1" defaultValue={editingTask?.intervalDays ?? 7} /></label><p className="form-hint">{editingTask ? "修改后更新后续安排，保留已处理记录。" : "未完成自动顺延，可补选实际完成日期。"}</p><button className="primary-button wide" type="submit">{editingTask ? "保存修改" : "保存任务"}</button></form></div>}

    {tankModal && <TankManagerSheet tanks={tanks} currentTankId={tankId} today={todayKey} initialView={tankModal} onSave={saveTank} onClose={() => setTankModal(null)} />}

    {maintenanceModal && <MaintenanceDosingPanel tankId={tankId} today={todayKey} cycles={maintenanceCycles} initialChemical={maintenanceChemical} onSave={saveMaintenanceCycle} tankName={tank?.name ?? "当前海缸"} previousKh={alkalinityPlan?.calculatedTankId === tankId ? alkalinityPlan : null} onClose={() => setMaintenanceModal(false)} />}
    {alkalinityModal && <div className="modal-backdrop">
      <section className="sheet alkalinity-sheet">
        <div className="sheet-handle" />
        <div className="section-head">
          <div><p className="eyebrow">{tank?.name} · 配方计算</p><h2>碳酸氢钠补 KH</h2></div>
          <button className="icon-button" onClick={() => setAlkalinityModal(false)}>×</button>
        </div>
        {!alkalinityPlan ? <form className="alkalinity-form" onSubmit={submitAlkalinityCalculation}>
          <div className="theory-warning"><strong>按碳酸氢钠纯度计算</strong><p>请填写实际净水量、包装纯度和实测KH。</p></div>
          {latestKhRecord && latestKhRecord.low !== latestKhRecord.high && <p className="calculation-error">最近 KH 是 {latestKhRecord.low}–{latestKhRecord.high} dKH 的范围，请输入复测单值。</p>}
          <div className="field-row">
            <label>当前 KH<input name="currentDkh" type="number" step="0.01" min="0" required defaultValue={exactLatestKh} placeholder="当前单值 dKH" /></label>
            <label>目标 KH<input name="targetDkh" type="number" step="any" min="0.01" required defaultValue={defaultCalculatorTargets.kh} placeholder="目标 dKH" /><small className="field-note">默认取目标范围中值，可修改</small></label>
          </div>
          <div className="field-row">
            <label>实际净水量<input name="netWaterVolumeL" type="number" step="0.1" min="0.1" required defaultValue={200} placeholder="扣除活石底砂后的 L" /></label>
            <label>碳酸氢钠纯度<input name="purityPercent" type="number" step="0.1" min="0.1" max="100" required defaultValue={DEFAULT_SODIUM_BICARBONATE_PURITY_PERCENT} /><small className="field-note">% · 按包装标识填写</small></label>
          </div>
          <div className="field-row">
            <label>每日 KH 消耗量<input name="dailyDkhConsumption" type="number" step="0.01" min="0" required defaultValue={DEFAULT_DAILY_DKH_CONSUMPTION} /><small className="field-note">默认 0.5 dKH/日，可改为实测消耗</small></label>
            <label>计划单日净升幅<input name="maxDailyDkhRise" type="number" step="0.1" min="0.1" max="1" required defaultValue={DEFAULT_MAX_DAILY_DKH_RISE} /><small className="field-note">0.1–1.0 dKH/日，不含当日消耗补偿</small></label>
          </div>
          <div className="field-row">
            <label>母液最终体积<input name="stockFinalVolumeMl" type="number" step="1" min="1" required defaultValue={DEFAULT_ALKALINITY_STOCK_FINAL_VOLUME_ML} /><small className="field-note">mL · 溶解后定容到此体积</small></label>
            <label>母液最低温度<input name="stockTemperatureC" type="number" step="1" min="0" max="40" required defaultValue={20} /><small className="field-note">°C · 配制/保存中可能达到的最低温度</small></label>
          </div>
          <label className="field">母液强度（每 100 L 提升 0.1 dKH 所需）<select name="stockMlPer0_1Dkh100L" required defaultValue={DEFAULT_STOCK_ML_PER_0_1_DKH_100L}>{STOCK_ML_PER_0_1_DKH_100L_OPTIONS.map((millilitres) => <option key={millilitres} value={millilitres}>{millilitres} mL</option>)}</select><small className="field-note">默认6 mL；按保存温度检查是否可配制。</small></label>
          {alkalinityError && <p className="calculation-error" role="alert">{alkalinityError}</p>}
          <button className="primary-button wide" type="submit">计算母液配方、每日毫升数与天数</button>
          <p className="chemical-note">每日投加当量 = 计划净升幅 + 每日消耗量。溶解度按 0–40°C 数据线性插值并保留 20% 程序余量；仍可能受原料、量具、蒸发与保存条件影响。</p>
        </form> : <div className="alkalinity-result">
          {alkalinityPlan.previewOnly && <p className="calendar-saved-note" role="status">仅计算预览 · 未加入日历，原计划和处理记录保持不变</p>}
          <div className="theory-warning"><strong>投加前先复测</strong><p>达到目标或生物异常时停止，按最新实测重新计算。</p></div>
          <div className="calculation-summary">
            <article className="alkalinity-total"><small>母液配方 · 最终 {formatVolume(alkalinityPlan.stockFinalVolumeMl)}</small><strong>称取 {formatMass(alkalinityPlan.stockSolidMassToWeighG)}</strong><p>{alkalinityPlan.purityPercent}% NaHCO₃，溶解后定容；不是直接加这么多进缸。</p><code>{alkalinityPlan.stockReagentConcentrationGPerL.toFixed(4)} g/L</code></article>
            <article><small>整毫升强度</small><strong>{alkalinityPlan.stockMlPer0_1Dkh100L} mL / 100 L</strong><p>理论提升 0.1 dKH；1 mL / 100 L 提升 {alkalinityPlan.stockStrengthDkhPerMlPer100L.toFixed(6)} dKH。</p><code>{alkalinityPlan.stockTemperatureC}°C · 约占饱和浓度 {alkalinityPlan.solubilityUtilizationPercent.toFixed(1)}%</code></article>
            <article><small>考虑每日消耗后的全程计划</small><strong>{alkalinityPlan.days} 天 · 母液 {formatVolume(alkalinityPlan.totalStockRequiredMl)}</strong><p>净提升 {alkalinityPlan.totalDkhRise.toFixed(3)} dKH，同时补偿假设消耗 {alkalinityPlan.totalAssumedDkhConsumption.toFixed(3)} dKH。</p><code>总投加当量 {alkalinityPlan.totalTheoreticalDoseDkh.toFixed(3)} dKH</code></article>
            <article><small>下一次理论母液量</small><strong>{formatVolume(alkalinityFirstDay?.stockToUseMl ?? 0)}</strong><p>投加当量 {alkalinityFirstDay?.theoreticalDoseDkh.toFixed(3)} dKH = 净提升 {alkalinityFirstDay?.plannedNetDkhRise.toFixed(3)} + 消耗 {alkalinityFirstDay?.assumedDkhConsumption.toFixed(3)}。</p><code>投加后瞬时理论值约 {alkalinityFirstDay?.postDoseDkh.toFixed(3)} dKH</code></article>
            {alkalinityPlan.days > 1 && <article><small>理论计划最后一日</small><strong>{formatVolume(alkalinityLastDay?.stockToUseMl ?? 0)}</strong><p>仍含当日消耗补偿；每天复测后必须重新计算。</p><code>日末理论值 {alkalinityLastDay?.expectedEndingDkh.toFixed(3)} dKH</code></article>}
          </div>
          {alkalinityPlan.stockShortfallMl > 0 && <p className="calculation-error">所选一瓶母液不足：全程还差 {formatVolume(alkalinityPlan.stockShortfallMl)}，按相同配方约需 {alkalinityPlan.stockBatchesRequired} 批。可增大母液体积或分批配制。</p>}
          <div className="impact-panel"><strong>投加注意</strong><ul><li>先复测KH/pH；达到目标或出现异常时停止。</li><li>用RO/DI水溶解，在强水流处缓慢添加，不直接投粉。</li><li>不与钙、镁浓缩液混合，分开容器并错时添加。</li></ul></div>
          <details className="protocol-source"><summary>计算依据</summary><p>1 dKH = 1/2.8 meq/L；HCO₃⁻ 每摩尔提供 1 摩尔当量碱度。100 L × 1 dKH ≈ 3.00025 g 纯 NaHCO₃。溶解度表采用 0/10/20/30/40°C 的 6.4/7.6/8.7/10.0/11.3 g/100 g 溶液，温度间线性插值；程序用 1 kg/L 参考换算后只允许其 80%，这是保守筛查而非精确饱和模型。</p><div><a href="https://pubchem.ncbi.nlm.nih.gov/compound/Sodium-Bicarbonate" target="_blank" rel="noreferrer">PubChem NaHCO₃ 与溶解度</a><a href="https://archive.epa.gov/ada/web/pdf/10003z26.pdf" target="_blank" rel="noreferrer">EPA 碱度当量说明</a><a href="https://redseafish.com/wp-content/uploads/2020/11/24783-NEW-Manual-Foundation-Supplements_GB-DE-FR-NL-SP_v21b-WEB.pdf" target="_blank" rel="noreferrer">Red Sea 分日补充说明</a><a href="https://www.seachem.com/reef-carbonate.php/downloads/articles/planted.php" target="_blank" rel="noreferrer">Seachem 添加边界</a></div></details>
          {alkalinityPlan.previewOnly ? <>
            <details className="protocol-source"><summary>本次计算的全部每日安排（未加入日历）</summary>{alkalinityPlan.dailyPlan.map(day => <article key={day.day}><strong>第 {day.day} 天</strong><p>取母液 {formatVolume(day.stockToUseMl)}；投加当量 {day.theoreticalDoseDkh.toFixed(3)} dKH = 净提升 {day.plannedNetDkhRise.toFixed(3)} + 消耗 {day.assumedDkhConsumption.toFixed(3)}。日末理论 KH {day.expectedEndingDkh.toFixed(3)} dKH。</p></article>)}</details>
            <button className="soft-button wide" onClick={() => setAlkalinityModal(false)}>关闭计算结果</button>
          </> : <><p className="calendar-saved-note">✓ 已加入任务日历</p>
          <button className="primary-button wide" onClick={() => { setAlkalinityModal(false); setTab("tasks"); }}>查看已加入的任务日历</button></>}
          <p className="disclaimer">每天复测KH/pH，再决定当天用量。</p>
        </div>}
      </section>
    </div>}

    {pendingChemicalReplacement && <div className="modal-backdrop" role="dialog" aria-modal="true" aria-labelledby="replacement-title" onMouseDown={() => setPendingChemicalReplacement(null)}>
      <section className="sheet" onMouseDown={(event) => event.stopPropagation()}>
        <div className="sheet-handle" />
        <div className="section-head"><div><p className="eyebrow">计划日期冲突</p><h2 id="replacement-title">覆盖原计划？</h2></div><button className="icon-button" onClick={() => setPendingChemicalReplacement(null)}>×</button></div>
        <div className="theory-warning"><strong>{pendingChemicalReplacement.kind === "lanthanum" ? "PO4 氯化镧计划" : "碳酸氢钠补 KH 计划"}</strong><p>新计划从 {pendingChemicalReplacement.plan.scheduledStartDate} 开始。该日期之前的旧计划、完成状态和历史记录都会保留；只删除并替换该日期及以后的同类旧计划任务。</p></div>
        <p className="form-hint">选择“仅计算”可保留原计划。</p>
        <div style={{ display: "grid", gap: 10 }}><button className="soft-button wide" onClick={previewChemicalReplacement}>仅计算，不覆盖原计划</button><button className="primary-button wide" onClick={confirmChemicalReplacement}>覆盖并创建新计划</button><button className="text-button" onClick={() => setPendingChemicalReplacement(null)}>取消，保留原计划</button></div>
      </section>
    </div>}

    {toast && <div className="toast" role="status">✓ {toast}</div>}
  </main>;
}
