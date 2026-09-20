import type { EntityId } from './entity-id';
import { normalizeFishStock, isFishArtworkDataUrl, type FishStockItem } from './aquarium-data.ts';
import { pruneSupersededChemicalPlanOverlaps } from './task-calendar.ts';
import { localCycleDate, type MaintenanceCycle } from './maintenance-cycle.ts';
import type { MaintenanceInput } from './maintenance-dosing.ts';
import type { Tank, Parameter, Target, RecordItem, TaskItem, TimerDefaults } from './demo-state.ts';
import { initializeKhTargetRanges } from './target-range.ts';
import { initializeRollingTasks } from './rolling-task.ts';

export type DemoState = {
  schemaVersion?: number;
  khTargetDefaultsApplied?: true;
  tanks: Tank[]; tankId: EntityId; parameters: Parameter[]; targets: Target[];
  records: RecordItem[]; tasks: TaskItem[]; maintenanceCycles: MaintenanceCycle[];
  fishStock: FishStockItem[]; timerDefaults: TimerDefaults;
  notificationEnabled: boolean; reminderDismissedDate: string;
  reminderSnoozedUntil?: Record<string, number>;
};
export const STORAGE_KEY = 'reef-demo-state-v10';
const keys = [10, 9, 8, 7, 6, 5, 4].map(v => `reef-demo-state-v${v}`);
type StorageAccess = () => Pick<Storage, 'getItem' | 'setItem'>;
type Row = Record<string, unknown>;
function object(v: unknown): v is Row { return Boolean(v) && typeof v === 'object' && !Array.isArray(v); }
function entityId(v: unknown): boolean { return typeof v === 'string' ? v.length > 0 && v.length <= 160 : typeof v === 'number' && Number.isSafeInteger(v); }
function finite(v: unknown): v is number { return typeof v === 'number' && Number.isFinite(v); }
function string(v: unknown): v is string { return typeof v === 'string'; }
function khTitration(v: unknown): boolean {
  return object(v) && string(v.tableId) && string(v.displayDkh) && typeof v.interpolated === 'boolean'
    && ['initialMl', 'remainingMl', 'usedMl', 'tableReadingMl', 'dkh'].every(key => finite(v[key]));
}
function date(v: unknown): v is string {
  if (!string(v) || !/^\d{4}-\d{2}-\d{2}$/.test(v)) return false;
  const parsed = Date.parse(`${v}T00:00:00Z`);
  return Number.isFinite(parsed) && new Date(parsed).toISOString().slice(0, 10) === v;
}
function requireValid(value: unknown, field: string): asserts value {
  if (!value) throw new Error(`存档中的 ${field} 格式异常。`);
}
function rows(value: unknown, field: string, check: (row: Row) => boolean) {
  requireValid(Array.isArray(value) && value.every(row => object(row) && check(row)), field);
}
function optional(row: Row, field: string, check: (v: unknown) => boolean) {
  return row[field] === undefined || check(row[field]);
}
function rollingTask(value: unknown): boolean {
  if (!object(value) || value.version !== 1 || !date(value.nextDate)
    || !finite(value.revision) || !Number.isSafeInteger(value.revision) || value.revision < 0
    || !Array.isArray(value.completed)) return false;
  let previousDate = '';
  for (const entry of value.completed) {
    if (!object(entry) || !date(entry.dueDate) || !date(entry.completedDate)
      || entry.completedDate <= previousDate) return false;
    previousDate = entry.completedDate;
  }
  return optional(value, 'legacySchedule', legacy => object(legacy) && date(legacy.scheduledDate)
    && optional(legacy, 'intervalDays', v => finite(v) && v > 0)
    && date(legacy.defaultCompletedBeforeDate));
}
/** A projected date belongs to one render, not the stored scheduling baseline. */
function persistentTask(task: TaskItem): TaskItem {
  const saved = { ...task };
  delete saved.projection;
  return saved;
}
function activeCycleInput(input: unknown, chemical: unknown) {
  if (!object(input) || !finite(input.waterL) || input.waterL <= 0) return false;
  const keys = chemical === 'po4' ? ['po4Rise', 'po4Flow', 'po4Minutes'] : ['khDrop', 'khFlow', 'khMinutes', 'khStrength', 'khPurity', 'temperature'];
  return keys.every(key => finite(input[key])) && ['ml/s', 'ml/min'].includes(String(input[`${chemical}Unit`]));
}
/** Older UI saved raw hidden-channel blanks as null; these were never part of
 * the accepted recipe. Repair only those unused inputs, never reservoir effect. */
function compatibleCycle(cycle: MaintenanceCycle): MaintenanceCycle {
  const input = { ...cycle.input };
  const unused = cycle.chemical === 'po4'
    ? { khDrop: 0, khFlow: 1.4, khMinutes: 1, khStrength: 6, khPurity: 100, temperature: 20 }
    : { po4Rise: 0, po4Flow: 1.4, po4Minutes: 1 };
  for (const [key, fallback] of Object.entries(unused)) {
    const field = key as keyof MaintenanceInput;
    if (!finite(input[field])) Object.assign(input, { [key]: fallback });
  }
  const unit = cycle.chemical === 'po4' ? 'khUnit' : 'po4Unit';
  if (!['ml/s', 'ml/min'].includes(input[unit])) input[unit] = 'ml/s';
  return { ...cycle, input };
}
function taskDate(task: TaskItem, index: number, now: Date) {
  const day = new Date(now);
  day.setDate(day.getDate() + (task.due.includes('明天') ? 1 : task.due.includes('今天') ? 0 : ['done', 'skipped'].includes(task.state) ? -1 : Math.max(2, index + 2)));
  return `${day.getFullYear()}-${String(day.getMonth() + 1).padStart(2, '0')}-${String(day.getDate()).padStart(2, '0')}`;
}
export function normalizeTask(task: TaskItem, index: number, now = new Date()): TaskItem {
  const interval = task.cycle.match(/每\s*(\d+)\s*(天|周)/);
  const intervalDays = task.intervalDays ?? (!task.oneOff && !['done', 'skipped'].includes(task.state) && interval ? Number(interval[1]) * (interval[2] === '周' ? 7 : 1) : undefined);
  const wakeAt = now.toISOString();
  return { ...task, scheduledDate: task.scheduledDate ?? taskDate(task, index, now), intervalDays,
    completedDates: task.completedDates ?? [], skippedDates: task.skippedDates ?? [], reopenedDates: task.reopenedDates ?? [],
    snoozedDates: task.snoozedDates ?? [], snoozedUntil: task.state === 'snoozed' ? task.snoozedUntil ?? wakeAt : task.snoozedUntil,
    snoozedUntilByDate: task.snoozedUntilByDate ?? Object.fromEntries((task.snoozedDates ?? []).map(day => [day, wakeAt])) };
}
function compatibleTasks(tasks: TaskItem[], now: Date): TaskItem[] {
  const normalized = tasks.map((task, index) => normalizeTask(persistentTask(task), index, now));
  return initializeRollingTasks(pruneSupersededChemicalPlanOverlaps(normalized), localCycleDate(now));
}

/** Validate the entire snapshot before any caller is allowed to apply it. */
export function validateDemoState(state: unknown): asserts state is DemoState {
  requireValid(object(state), '根对象');
  requireValid(state.schemaVersion === undefined || state.schemaVersion === 1, '版本（可能来自更新的应用）');
  requireValid(optional(state, 'khTargetDefaultsApplied', v => v === true), 'KH 默认目标标记');
  // Stored dates may temporarily be ahead of the device clock after travel or
  // a clock correction. Only input confirmation enforces the current-day limit.
  rows(state.tanks, '海缸', r => entityId(r.id) && string(r.name) && string(r.volume)
    && optional(r, 'startedOn', v => v === '' || date(v)));
  requireValid((state.tanks as Tank[]).length > 0 && (state.tanks as Tank[]).some(t => t.id === state.tankId), '当前海缸');
  rows(state.parameters, '参数', r => string(r.id) && string(r.name) && string(r.label) && string(r.unit) && typeof r.builtIn === 'boolean' && typeof r.photoSupported === 'boolean');
  requireValid((state.parameters as Parameter[]).length > 0, '参数列表');
  rows(state.targets, '目标范围', r => entityId(r.tankId) && string(r.parameterId) && (r.min === null || finite(r.min)) && (r.max === null || finite(r.max)));
  rows(state.records, '检测记录', r => entityId(r.id) && entityId(r.tankId) && string(r.parameterId) && finite(r.low) && finite(r.high) && r.low <= r.high && string(r.date) && string(r.note) && optional(r, 'interpolation', v => v === null || finite(v)) && optional(r, 'photoEstimate', object) && optional(r, 'khTitration', khTitration));
  rows(state.tasks, '任务', r => entityId(r.id) && entityId(r.tankId) && string(r.title) && string(r.cycle) && string(r.due) && ['due', 'soon', 'done', 'snoozed', 'skipped'].includes(String(r.state))
    && optional(r, 'scheduledDate', date) && optional(r, 'intervalDays', v => finite(v) && v > 0)
    && optional(r, 'rolling', rollingTask)
    && ['completedDates', 'skippedDates', 'reopenedDates', 'snoozedDates'].every(k => optional(r, k, v => Array.isArray(v) && v.every(date)))
    && optional(r, 'snoozedUntilByDate', v => object(v) && Object.entries(v).every(([k, timestamp]) => date(k) && string(timestamp) && Number.isFinite(Date.parse(timestamp)))));
  rows(state.maintenanceCycles, '补液周期', r => entityId(r.id) && entityId(r.tankId) && ['po4', 'kh'].includes(String(r.chemical)) && date(r.startDate) && date(r.refillDate)
    && ['solutionMl', 'dailyLiquidMl', 'effectPerMl', 'retainedMl', 'addedStockMl', 'addedWaterMl'].every(k => finite(r[k]) && (r[k] as number) >= 0)
    && (r.solutionMl as number) > 0 && (r.dailyLiquidMl as number) > 0 && optional(r, 'closedOnDate', date)
    && optional(r, 'refillDeferredUntil', date)
    && optional(r, 'theory', v => object(v) && string(v.planId) && v.planId.trim().length > 0
      && v.source === (r.chemical === 'po4' ? 'lanthanum-plan' : 'alkalinity-plan')
      && finite(v.target) && v.target > 0 && date(v.planStartDate) && date(v.endDate)
      && v.planStartDate <= r.startDate! && r.startDate! <= v.endDate
      && Date.parse(v.endDate) - Date.parse(v.planStartDate) < 3650 * 86400000
      && finite(v.lastDayRatio) && v.lastDayRatio > 0 && v.lastDayRatio <= 1 + 1e-10)
    && activeCycleInput(r.input, r.chemical));
  rows(state.fishStock, '鱼类档案', r => (string(r.id) || entityId(r.id)) && entityId(r.tankId) && string(r.species) && finite(r.quantity) && r.quantity > 0 && date(r.introducedOn)
    && optional(r, 'artwork', v => object(v) && (v.source === 'builtin' && string(v.id) || v.source === 'custom' && isFishArtworkDataUrl(v.dataUrl))));
  requireValid(object(state.timerDefaults) && Object.values(state.timerDefaults).every(v => finite(v) && v >= 10 && v <= 3600), '计时设置');
  requireValid(typeof state.notificationEnabled === 'boolean' && string(state.reminderDismissedDate), '提醒设置');
  requireValid(optional(state, 'reminderSnoozedUntil', v => object(v) && Object.values(v).every(until => finite(until) && until > 0 && until <= 8640000000000000)), '稍后提醒时间');
}

export function loadDemoState(access: StorageAccess, defaults: DemoState, now = new Date()) {
  const fallback: DemoState = { ...defaults, khTargetDefaultsApplied: true,
    targets: initializeKhTargetRanges(defaults.targets), tasks: compatibleTasks(defaults.tasks, now) };
  try {
    const storage = access();
    let raw: string | null = null;
    for (const key of keys) {
      raw = storage.getItem(key);
      if (raw !== null) break;
    }
    if (raw === null) return { state: fallback, blocked: false };
    const parsed: unknown = JSON.parse(raw);
    requireValid(object(parsed), '根对象');
    // Every supported historical snapshot already contained these fields.
    // An empty/partial object is damaged data, not an invitation to seed demos.
    const required = parsed.schemaVersion === 1
      ? ['tanks', 'tankId', 'parameters', 'targets', 'records', 'tasks', 'maintenanceCycles', 'fishStock', 'timerDefaults', 'notificationEnabled', 'reminderDismissedDate']
      : ['tanks', 'tankId', 'parameters', 'targets', 'records', 'tasks'];
    requireValid(required.every(key => Object.hasOwn(parsed, key)), '必需字段');
    // Missing fields in v4-v10 are a known migration, not malformed values.
    const migrated = { ...fallback, ...parsed, fishStock: parsed.fishStock === undefined ? [] : parsed.fishStock, maintenanceCycles: parsed.maintenanceCycles === undefined ? [] : parsed.maintenanceCycles };
    validateDemoState(migrated);
    const state = { ...migrated, schemaVersion: 1, khTargetDefaultsApplied: true as const,
      // Fill previously empty KH ranges once. Later intentional blanks stay blank.
      targets: parsed.khTargetDefaultsApplied === true ? migrated.targets : initializeKhTargetRanges(migrated.targets),
      parameters: migrated.parameters.map(p => ['no3', 'po4'].includes(p.id) ? { ...p, photoSupported: true } : p),
      tasks: compatibleTasks(migrated.tasks, now),
      maintenanceCycles: migrated.maintenanceCycles.map(compatibleCycle),
      fishStock: normalizeFishStock(migrated.fishStock, []) };
    validateDemoState(state);
    return { state, blocked: false };
  } catch (e) {
    return { state: fallback, blocked: true, message: `${e instanceof Error ? e.message : '无法读取浏览器存储。'} 原存档未修改；恢复成功前不会自动保存。` };
  }
}

export function saveDemoState(access: StorageAccess, state: DemoState): { ok: true } | { ok: false; message: string } {
  try {
    validateDemoState(state);
    access().setItem(STORAGE_KEY, JSON.stringify({ ...state, schemaVersion: 1, khTargetDefaultsApplied: true,
      tasks: state.tasks.map(persistentTask), maintenanceCycles: state.maintenanceCycles.map(compatibleCycle) }));
    return { ok: true };
  } catch (e) {
    return { ok: false, message: `未能保存本次更改：${e instanceof Error ? e.message : '浏览器存储不可用'}。原有存档仍保留，请勿关闭页面，释放存储空间后重试。` };
  }
}
