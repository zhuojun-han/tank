import type { CalendarTaskSchedule, CalendarTaskState } from "./task-calendar.ts";

export type RollingTaskMetadata = {
  version: 1;
  nextDate: string;
  revision: number;
  completed: Array<{ dueDate: string; completedDate: string }>;
  /** Preserve the old implicit history when its recurrence rule is later edited. */
  legacySchedule?: { scheduledDate: string; intervalDays?: number; defaultCompletedBeforeDate: string };
};

export type RollingTaskProjection = { date: string; today: string };
type RollingTask = CalendarTaskSchedule & {
  id: number;
  tankId?: number;
  source?: string;
  planId?: string;
  dayIndex?: number;
  handledAt?: string;
};

export function isCalendarDate(value: unknown): value is string {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const time = Date.parse(`${value}T00:00:00Z`);
  return Number.isFinite(time) && new Date(time).toISOString().slice(0, 10) === value;
}

function ordinal(date: string) {
  if (!isCalendarDate(date)) throw new Error("请选择有效日期。");
  return Date.parse(`${date}T00:00:00Z`) / 86_400_000;
}

export function addTaskCalendarDays(date: string, days: number) {
  if (!Number.isSafeInteger(days)) throw new Error("天数必须是整数。");
  const time = (ordinal(date) + days) * 86_400_000;
  if (!Number.isFinite(time) || Math.abs(time) > 8.64e15) throw new Error("日期超出可用范围。");
  const result = new Date(time).toISOString().slice(0, 10);
  if (!isCalendarDate(result)) throw new Error("日期超出可用范围。");
  return result;
}

function interval(task: CalendarTaskSchedule) {
  const finitePlan = task.planId && (task.source === "lanthanum-plan" || task.source === "alkalinity-plan");
  return !finitePlan && !task.oneOff && Number.isSafeInteger(task.intervalDays) && task.intervalDays! > 0 ? task.intervalDays : undefined;
}

function active(task: CalendarTaskSchedule) {
  return !task.hiddenFromCalendar && !task.stoppedAfterDate && task.state !== "done" && task.state !== "skipped";
}

function chemicalKey(task: RollingTask) {
  return task.planId && (task.source === "lanthanum-plan" || task.source === "alkalinity-plan")
    ? JSON.stringify([task.tankId, task.source, task.planId]) : undefined;
}

function legacyNextDate(task: RollingTask) {
  const start = task.scheduledDate!;
  const step = interval(task);
  if (!step) return start;
  const matchesRule = (date: string) => date >= start && (ordinal(date) - ordinal(start)) % step === 0;
  const handled = [...(task.completedDates ?? []), ...(task.skippedDates ?? [])].filter(matchesRule).sort();
  let next = handled.length ? addTaskCalendarDays(handled.at(-1)!, step) : start;
  if (task.defaultCompletedBeforeDate && next < task.defaultCompletedBeforeDate) {
    next = addTaskCalendarDays(start, Math.ceil((ordinal(task.defaultCompletedBeforeDate) - ordinal(start)) / step) * step);
  }
  const reopened = (task.reopenedDates ?? []).filter(date => matchesRule(date) && !handled.includes(date)).sort()[0];
  return reopened && reopened < next ? reopened : next;
}

/** Initialize once; existing dates and history remain evidence, never fabricated completions. */
export function initializeRollingTasks<T extends RollingTask>(tasks: T[], today: string): T[] {
  ordinal(today);
  return tasks.map(task => {
    if (task.rolling || task.source === "maintenance-cycle" || !isCalendarDate(task.scheduledDate)) return task;
    // Old unusual fractional intervals retain their compatible fixed-date interpretation.
    if (!chemicalKey(task) && !task.oneOff && task.intervalDays !== undefined && !interval(task)) return task;
    const rolling: RollingTaskMetadata = { version: 1, nextDate: legacyNextDate(task), revision: 0, completed: [] };
    if (task.defaultCompletedBeforeDate) rolling.legacySchedule = {
      scheduledDate: task.scheduledDate,
      intervalDays: task.intervalDays,
      defaultCompletedBeforeDate: task.defaultCompletedBeforeDate,
    };
    return { ...task, rolling };
  });
}

function pendingBaseDate(task: CalendarTaskSchedule, today?: string) {
  if (!task.rolling) return task.scheduledDate;
  let date = task.rolling.nextDate;
  if (today && date < today) date = today;
  const deadline = task.snoozedUntil ?? task.snoozedUntilByDate?.[task.rolling.nextDate];
  if (deadline) {
    const time = new Date(deadline);
    if (Number.isFinite(time.getTime())) {
      const wakeDate = `${time.getFullYear()}-${String(time.getMonth() + 1).padStart(2, "0")}-${String(time.getDate()).padStart(2, "0")}`;
      if (wakeDate > date) date = wakeDate;
    }
  }
  return date;
}

/** Display metadata is a pure view and must not be persisted with the task. */
export function taskDisplayDate(task: CalendarTaskSchedule, today?: string) {
  if (task.projection && (!today || task.projection.today === today)) return task.projection.date;
  if (task.rolling && !active(task)) {
    if (task.state === "done") return task.rolling.completed.at(-1)?.completedDate ?? task.scheduledDate;
    if (task.state === "skipped") return task.stoppedAfterDate ?? task.skippedDates?.at(-1) ?? task.scheduledDate;
  }
  return pendingBaseDate(task, today);
}

function pendingChemicalMembers<T extends RollingTask>(tasks: T[], selected: T) {
  const key = chemicalKey(selected);
  return key ? tasks.filter(task => chemicalKey(task) === key && active(task) && task.rolling)
    .sort((a, b) => a.rolling!.nextDate.localeCompare(b.rolling!.nextDate) || (a.dayIndex ?? 0) - (b.dayIndex ?? 0) || a.id - b.id) : [selected];
}

/** Roll one unresolved head forward. Finite chemical days keep their spacing and doses. */
export function projectRollingTasks<T extends RollingTask>(tasks: T[], today: string): T[] {
  ordinal(today);
  const shifts = new Map<string, number>();
  for (const task of tasks) {
    const key = chemicalKey(task);
    if (!key || !task.rolling || !active(task) || shifts.has(key)) continue;
    const head = pendingChemicalMembers(tasks, task)[0];
    shifts.set(key, ordinal(pendingBaseDate(head, today)!) - ordinal(head.rolling!.nextDate));
  }
  return tasks.map(task => {
    if (!task.rolling || !active(task)) return task.projection ? { ...task, projection: undefined } : task;
    const key = chemicalKey(task);
    const date = key ? addTaskCalendarDays(task.rolling.nextDate, shifts.get(key) ?? 0) : pendingBaseDate(task, today)!;
    const state: CalendarTaskState = task.state === "snoozed" || task.snoozedDates?.includes(task.rolling.nextDate) ? "snoozed" : date <= today ? "due" : "soon";
    return { ...task, state, projection: { date, today } };
  });
}

/** Only dated legacy evidence survives; missed fixed-anchor dates are not new reminders. */
export function rollingHistoryState(task: CalendarTaskSchedule, date: string): CalendarTaskState | undefined {
  if (task.rolling?.completed.some(entry => entry.completedDate === date) || task.completedDates?.includes(date)) return "done";
  if (task.skippedDates?.includes(date)) return "skipped";
  const legacy = task.rolling?.legacySchedule;
  if (legacy && date < legacy.defaultCompletedBeforeDate && date >= legacy.scheduledDate && !task.reopenedDates?.includes(date)) {
    const step = legacy.intervalDays;
    if (!step ? date === legacy.scheduledDate : (ordinal(date) - ordinal(legacy.scheduledDate)) % step === 0) return "done";
  }
  if (task.stoppedAfterDate === date && task.state === "skipped") return "skipped";
  if (task.rolling?.revision === 0 && (task.state === "done" || task.state === "skipped") && task.scheduledDate === date) return task.state;
  return undefined;
}

export function rollingPendingOnDate(task: CalendarTaskSchedule, date: string, today?: string) {
  if (!task.rolling) return false;
  if (!active(task)) return false;
  const base = taskDisplayDate(task, today)!;
  if (date < base) return false;
  const step = interval(task);
  return step ? (ordinal(date) - ordinal(base)) % step === 0 : date === base;
}

export function rollingOccursOnDate(task: CalendarTaskSchedule, date: string, today?: string) {
  return !task.hiddenFromCalendar && Boolean(task.rolling) && (Boolean(rollingHistoryState(task, date)) || rollingPendingOnDate(task, date, today));
}

function selectedTask<T extends RollingTask>(tasks: T[], id: number, expectedRevision?: number, requireActive = true) {
  const task = tasks.find(item => item.id === id);
  if (!task?.rolling || (requireActive && !active(task))) throw new Error("该任务已更新，请重新打开。");
  if (expectedRevision !== undefined && task.rolling.revision !== expectedRevision) throw new Error("该任务已更新，请重新打开。");
  return task;
}

function requireHead<T extends RollingTask>(tasks: T[], task: T) {
  const members = pendingChemicalMembers(tasks, task);
  if (members[0]?.id !== task.id) throw new Error("请先处理本计划较早的任务。");
  return members;
}

function clearedSnooze<T extends RollingTask>(task: T): T {
  return { ...task, snoozedUntil: undefined, snoozedDates: [], snoozedUntilByDate: {}, projection: undefined };
}

function previousCompletionDate<T extends RollingTask>(tasks: T[], task: T, excludingLatest = false) {
  const key = chemicalKey(task);
  const peers = key ? tasks.filter(item => chemicalKey(item) === key) : [task];
  return peers.flatMap(item => {
    const entries = item.id === task.id && excludingLatest ? item.rolling!.completed.slice(0, -1) : item.rolling?.completed ?? [];
    return [...entries.map(entry => entry.completedDate), ...(item.completedDates ?? [])];
  }).sort().at(-1);
}

function validateCompletionDate<T extends RollingTask>(tasks: T[], task: T, actualDate: string, today: string, excludingLatest = false) {
  ordinal(actualDate); ordinal(today);
  if (actualDate > today) throw new Error("完成日期不能晚于今天。");
  const key = chemicalKey(task);
  const origin = key ? tasks.filter(item => chemicalKey(item) === key).map(item => item.scheduledDate!).sort()[0] : task.scheduledDate;
  if (origin && actualDate < origin) throw new Error("完成日期不能早于计划开始日期。");
  const previous = previousCompletionDate(tasks, task, excludingLatest);
  if (previous && actualDate <= previous) throw new Error("完成日期必须晚于上一次实际完成日期。");
}

export function delayRollingTask<T extends RollingTask>(tasks: T[], id: number, days: number, today: string, expectedRevision?: number): T[] {
  if (!Number.isSafeInteger(days) || days < 1) throw new Error("延迟天数必须是大于 0 的整数。");
  ordinal(today);
  const task = selectedTask(tasks, id, expectedRevision);
  const members = requireHead(tasks, task);
  const displayed = projectRollingTasks(tasks, today).find(item => item.id === id)!;
  const nextDate = addTaskCalendarDays(taskDisplayDate(displayed, today)!, days);
  const shift = ordinal(nextDate) - ordinal(task.rolling!.nextDate);
  const affected = new Set(members.map(item => item.id));
  return tasks.map(item => affected.has(item.id) ? {
    ...clearedSnooze(item), state: "soon", handledAt: undefined,
    rolling: { ...item.rolling!, nextDate: addTaskCalendarDays(item.rolling!.nextDate, shift), revision: item.rolling!.revision + 1 },
  } : item);
}

export function completeRollingTask<T extends RollingTask>(tasks: T[], id: number, actualDate: string, today: string, expectedRevision?: number): T[] {
  const task = selectedTask(tasks, id, expectedRevision);
  const members = requireHead(tasks, task);
  validateCompletionDate(tasks, task, actualDate, today);
  const dueDate = taskDisplayDate(projectRollingTasks(tasks, today).find(item => item.id === id)!, today)!;
  const completed = [...task.rolling!.completed, { dueDate, completedDate: actualDate }];
  const step = interval(task);
  const group = chemicalKey(task);
  const shift = ordinal(actualDate) - ordinal(task.rolling!.nextDate);
  const affected = new Set(members.map(item => item.id));
  return tasks.map(item => {
    if (item.id === id) return {
      ...clearedSnooze(item), state: step ? "due" : "done", handledAt: `${actualDate} 完成`,
      rolling: { ...item.rolling!, completed, nextDate: step ? addTaskCalendarDays(actualDate, step) : item.rolling!.nextDate, revision: item.rolling!.revision + 1 },
    };
    if (group && affected.has(item.id)) return {
      ...clearedSnooze(item), state: "soon",
      rolling: { ...item.rolling!, nextDate: addTaskCalendarDays(item.rolling!.nextDate, shift), revision: item.rolling!.revision + 1 },
    };
    return item;
  });
}

function latestEntry<T extends RollingTask>(tasks: T[], task: T, completedDate: string) {
  const entry = task.rolling!.completed.at(-1);
  if (!entry || entry.completedDate !== completedDate || previousCompletionDate(tasks, task) !== completedDate) throw new Error("只能修改最近一次实际完成记录。");
  return entry;
}

export function correctRollingCompletion<T extends RollingTask>(tasks: T[], id: number, completedDate: string, actualDate: string, today: string, expectedRevision?: number): T[] {
  const task = selectedTask(tasks, id, expectedRevision, false);
  const entry = latestEntry(tasks, task, completedDate);
  validateCompletionDate(tasks, task, actualDate, today, true);
  const step = interval(task);
  const key = chemicalKey(task);
  const shift = ordinal(actualDate) - ordinal(entry.completedDate);
  return tasks.map(item => {
    if (item.id === id) return {
      ...item, handledAt: `${actualDate} 完成`, projection: undefined,
      rolling: { ...item.rolling!, completed: [...item.rolling!.completed.slice(0, -1), { ...entry, completedDate: actualDate }],
        nextDate: step ? addTaskCalendarDays(actualDate, step) : item.rolling!.nextDate, revision: item.rolling!.revision + 1 },
    };
    return key && chemicalKey(item) === key && active(item) && item.rolling ? {
      ...item, projection: undefined, rolling: { ...item.rolling, nextDate: addTaskCalendarDays(item.rolling.nextDate, shift), revision: item.rolling.revision + 1 },
    } : item;
  });
}

export function reopenRollingTask<T extends RollingTask>(tasks: T[], id: number, completedDate: string, today: string, expectedRevision?: number): T[] {
  ordinal(today); ordinal(completedDate);
  const task = selectedTask(tasks, id, expectedRevision, false);
  const latest = task.rolling!.completed.at(-1);
  let nextDate = completedDate;
  if (latest) nextDate = latestEntry(tasks, task, completedDate).dueDate;
  else {
    if (rollingHistoryState(task, completedDate) !== "done" || (previousCompletionDate(tasks, task) ?? "") > completedDate) throw new Error("只能重开最近可修改的完成记录。");
    if ((task.completedDates ?? []).some(date => date > completedDate)) throw new Error("只能重开最近可修改的完成记录。");
    const key = chemicalKey(task);
    if (key && tasks.some(item => chemicalKey(item) === key && item.state === "done" && (item.dayIndex ?? 0) > (task.dayIndex ?? 0))) throw new Error("只能重开最近可修改的完成记录。");
  }
  const key = chemicalKey(task);
  return tasks.map(item => {
    if (item.id === id) return {
      ...clearedSnooze(item), state: nextDate > today ? "soon" : "due", handledAt: undefined, stoppedAfterDate: undefined,
      completedDates: latest ? item.completedDates : (item.completedDates ?? []).filter(date => date !== completedDate),
      reopenedDates: latest ? item.reopenedDates : [...new Set([...(item.reopenedDates ?? []), completedDate])],
      rolling: { ...item.rolling!, nextDate, completed: latest ? item.rolling!.completed.slice(0, -1) : item.rolling!.completed, revision: item.rolling!.revision + 1 },
    };
    if (key && chemicalKey(item) === key && active(item) && item.rolling && item.scheduledDate && task.scheduledDate) return {
      ...clearedSnooze(item), state: "soon", rolling: { ...item.rolling, nextDate: addTaskCalendarDays(nextDate, ordinal(item.scheduledDate) - ordinal(task.scheduledDate)), revision: item.rolling.revision + 1 },
    };
    return item;
  });
}

export function stopRollingTask<T extends RollingTask>(tasks: T[], id: number, today: string, expectedRevision?: number): T[] {
  ordinal(today);
  const task = selectedTask(tasks, id, expectedRevision);
  const members = requireHead(tasks, task);
  const date = taskDisplayDate(projectRollingTasks(tasks, today).find(item => item.id === id)!, today)!;
  const affected = new Set(members.map(item => item.id));
  return tasks.map(item => affected.has(item.id) ? {
    ...clearedSnooze(item), state: "skipped", stoppedAfterDate: item.id === id ? date : item.stoppedAfterDate,
    hiddenFromCalendar: item.id !== id || item.hiddenFromCalendar,
    skippedDates: item.id === id ? [...new Set([...(item.skippedDates ?? []), date])] : item.skippedDates,
    handledAt: `${date} 已停止后续计划`, rolling: { ...item.rolling!, revision: item.rolling!.revision + 1 },
  } : item);
}
