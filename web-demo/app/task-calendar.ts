export type CalendarTaskState = "due" | "soon" | "done" | "snoozed" | "skipped";

type ChemicalPlanSource = "lanthanum-plan" | "alkalinity-plan";
type ChemicalPlanTask = { tankId: number; source?: string; state: CalendarTaskState; handledAt?: string; hiddenFromCalendar?: boolean };
type StoppedChemicalTask<T> = Omit<T, "state" | "handledAt" | "hiddenFromCalendar"> & {
  state: CalendarTaskState;
  handledAt?: string;
  hiddenFromCalendar?: boolean;
};

function isMatchingChemicalTask(task: ChemicalPlanTask, tankId: number, source: ChemicalPlanSource) {
  return task.tankId === tankId && task.source === source;
}

type DatedChemicalPlanTask = ChemicalPlanTask & { id: number; planId?: string; scheduledDate?: string };

/** A replacement prompt is needed only when an older plan occupies the new plan's date range. */
export function hasChemicalPlanFromDate(tasks: DatedChemicalPlanTask[], tankId: number, source: ChemicalPlanSource, startDate: string) {
  return tasks.some((task) => isMatchingChemicalTask(task, tankId, source) && (!task.scheduledDate || task.scheduledDate >= startDate));
}

/** Preserve dated history before startDate and remove only the overlapping/future part of an older plan. */
export function removeChemicalPlansFromDate<T extends DatedChemicalPlanTask>(tasks: T[], tankId: number, source: ChemicalPlanSource, startDate: string): T[] {
  return tasks.filter((task) => !isMatchingChemicalTask(task, tankId, source) || Boolean(task.scheduledDate && task.scheduledDate < startDate));
}

/**
 * One-time cleanup for existing browser data. A newer generation wins only from
 * its own first scheduled date; earlier tasks and completion history stay intact.
 */
export function pruneSupersededChemicalPlanOverlaps<T extends DatedChemicalPlanTask>(tasks: T[]): T[] {
  const plans = new Map<string, { tankId: number; source: ChemicalPlanSource; planId: string; maxTaskId: number; startDate?: string }>();
  for (const task of tasks) {
    if (!task.planId || (task.source !== "lanthanum-plan" && task.source !== "alkalinity-plan")) continue;
    const key = JSON.stringify([task.tankId, task.source, task.planId]);
    const current = plans.get(key);
    plans.set(key, {
      tankId: task.tankId,
      source: task.source,
      planId: task.planId,
      maxTaskId: Math.max(current?.maxTaskId ?? Number.NEGATIVE_INFINITY, task.id),
      startDate: !task.scheduledDate ? current?.startDate : !current?.startDate || task.scheduledDate < current.startDate ? task.scheduledDate : current.startDate,
    });
  }
  const generations = [...plans.values()];
  return tasks.filter((task) => {
    if (!task.planId || (task.source !== "lanthanum-plan" && task.source !== "alkalinity-plan")) return true;
    const current = plans.get(JSON.stringify([task.tankId, task.source, task.planId]));
    if (!current) return true;
    return !generations.some((newer) => newer.tankId === task.tankId
      && newer.source === task.source
      && newer.planId !== task.planId
      && newer.maxTaskId > current.maxTaskId
      && (!task.scheduledDate || !newer.startDate || task.scheduledDate >= newer.startDate));
  });
}

export type CalendarTaskSchedule = {
  scheduledDate?: string;
  intervalDays?: number;
  oneOff?: boolean;
  state: CalendarTaskState;
  completedDates?: string[];
  skippedDates?: string[];
  snoozedDates?: string[];
  snoozedUntil?: string;
  snoozedUntilByDate?: Record<string, string>;
  defaultCompletedBeforeDate?: string;
  reopenedDates?: string[];
  hiddenFromCalendar?: boolean;
  stoppedAfterDate?: string;
};

type EditableRecurringTask = CalendarTaskSchedule & {
  id: number;
  title: string;
  cycle: string;
  due: string;
  handledAt?: string;
};

type RecurringTaskEdits = Pick<EditableRecurringTask, "title" | "cycle" | "due" | "state" | "scheduledDate" | "intervalDays" | "defaultCompletedBeforeDate">;

/** Update one recurring rule without discarding its per-date completion history. */
export function editRecurringTask<T extends EditableRecurringTask>(tasks: T[], selectedTaskId: number, edits: RecurringTaskEdits): T[] {
  return tasks.map((task) => task.id === selectedTaskId && task.intervalDays && !task.oneOff ? {
    ...task,
    ...edits,
    handledAt: undefined,
    stoppedAfterDate: undefined,
  } : task);
}

function dateOrdinal(key: string) {
  const [year, month, day] = key.split("-").map(Number);
  return Math.floor(Date.UTC(year, month - 1, day) / 86_400_000);
}

export function taskOccursOnDate(task: CalendarTaskSchedule, key: string) {
  if (!task.scheduledDate || task.hiddenFromCalendar) return false;
  if (task.stoppedAfterDate && key > task.stoppedAfterDate) return false;
  if (!task.intervalDays || task.intervalDays < 1 || task.oneOff || ((task.state === "done" || task.state === "skipped") && !task.stoppedAfterDate)) {
    return task.scheduledDate === key;
  }
  const offset = dateOrdinal(key) - dateOrdinal(task.scheduledDate);
  return offset >= 0 && offset % task.intervalDays === 0;
}

type StoppableChemicalTask = ChemicalPlanTask & { id: number; planId?: string; dayIndex?: number };

/** Stop a finite plan while optionally retaining the selected day as history on its date. */
export function stopChemicalPlanFromDay<T extends StoppableChemicalTask>(tasks: T[], selectedTaskId: number, handledAt: string, keepSelectedDateInCalendar = true): StoppedChemicalTask<T>[] {
  const selected = tasks.find((task) => task.id === selectedTaskId);
  if (!selected?.planId || !selected.source || (selected.source !== "lanthanum-plan" && selected.source !== "alkalinity-plan")) return tasks;
  const selectedDay = selected.dayIndex ?? 0;
  return tasks.map((task) => {
    const affected = task.planId === selected.planId && task.source === selected.source && (task.dayIndex ?? 0) >= selectedDay && task.state !== "done" && task.state !== "skipped";
    if (!affected) return task;
    const isSelectedDay = task.id === selectedTaskId;
    return { ...task, state: "skipped", handledAt, hiddenFromCalendar: !isSelectedDay || !keepSelectedDateInCalendar };
  });
}

export function taskStateOnDate(task: CalendarTaskSchedule, key: string, today: string): CalendarTaskState {
  if (task.completedDates?.includes(key)) return "done";
  if (task.skippedDates?.includes(key)) return "skipped";
  if (task.snoozedDates?.includes(key)) return "snoozed";
  if (task.defaultCompletedBeforeDate && key < task.defaultCompletedBeforeDate && !task.reopenedDates?.includes(key)) return "done";
  if (!task.intervalDays || task.oneOff) return task.state;
  return key <= today ? "due" : "soon";
}

type RecurringTask = CalendarTaskSchedule & { id: number; handledAt?: string };

/** Restore timed snoozes when their exact deadline has passed. */
export function wakeExpiredSnoozedTasks<T extends RecurringTask>(tasks: T[], nowIso: string): T[] {
  return tasks.map((task) => {
    if (task.intervalDays && !task.oneOff && task.snoozedUntilByDate) {
      const expiredDates = Object.entries(task.snoozedUntilByDate)
        .filter(([, deadline]) => deadline <= nowIso)
        .map(([date]) => date);
      if (expiredDates.length === 0) return task;
      const expired = new Set(expiredDates);
      return {
        ...task,
        snoozedDates: (task.snoozedDates ?? []).filter((date) => !expired.has(date)),
        snoozedUntilByDate: Object.fromEntries(Object.entries(task.snoozedUntilByDate).filter(([date]) => !expired.has(date))),
      };
    }
    if (task.state === "snoozed" && task.snoozedUntil && task.snoozedUntil <= nowIso) {
      return { ...task, state: "due", snoozedUntil: undefined };
    }
    return task;
  });
}

/** Reopen one completed occurrence without changing later dates in the schedule. */
export function markTaskIncomplete<T extends RecurringTask>(tasks: T[], selectedTaskId: number, occurrenceDate: string, today: string): T[] {
  return tasks.map((task) => {
    if (task.id !== selectedTaskId) return task;
    if (task.intervalDays && !task.oneOff) {
      return {
        ...task,
        completedDates: (task.completedDates ?? []).filter((date) => date !== occurrenceDate),
        reopenedDates: [...new Set([...(task.reopenedDates ?? []), occurrenceDate])],
      };
    }
    return {
      ...task,
      state: task.scheduledDate && task.scheduledDate > today ? "soon" : "due",
      handledAt: undefined,
    };
  });
}

export function stopRecurringTaskFromDate<T extends RecurringTask>(tasks: T[], selectedTaskId: number, occurrenceDate: string): T[] {
  return tasks.map((task) => task.id === selectedTaskId && task.intervalDays && !task.oneOff ? {
    ...task,
    state: "skipped",
    stoppedAfterDate: occurrenceDate,
    handledAt: `${occurrenceDate} 已停止后续计划`,
    skippedDates: [...new Set([...(task.skippedDates ?? []), occurrenceDate])],
    completedDates: (task.completedDates ?? []).filter((date) => date !== occurrenceDate),
    snoozedDates: (task.snoozedDates ?? []).filter((date) => date !== occurrenceDate),
    snoozedUntilByDate: Object.fromEntries(Object.entries(task.snoozedUntilByDate ?? {}).filter(([date]) => date !== occurrenceDate)),
  } : task);
}

/** Select occurrences, not merely pending rules: past/future one-offs stay off home. */
export function pendingTasksOnDate<T extends CalendarTaskSchedule>(tasks: T[], key: string): T[] {
  return tasks.filter((task) => taskOccursOnDate(task, key))
    .map((task) => ({ ...task, state: taskStateOnDate(task, key, key) }))
    .filter((task) => task.state !== "done" && task.state !== "skipped");
}

/** The completed tab is an occurrence view for one calendar date, not an all-time archive. */
export function completedTasksOnDate<T extends CalendarTaskSchedule>(tasks: T[], key: string): T[] {
  return tasks.filter((task) => taskOccursOnDate(task, key))
    .map((task) => ({ ...task, state: taskStateOnDate(task, key, key) }))
    .filter((task) => task.state === "done");
}

type GroupableTask = CalendarTaskSchedule & { id: number; tankId: number; source?: string; planId?: string };

/** Presentation only; daily records and per-occurrence completion remain intact. */
export function groupChemicalPlanTasks<T extends GroupableTask>(tasks: T[], today: string) {
  const groups = new Map<string, { key: string; isChemicalPlan: boolean; task: T; members: T[] }>();
  for (const task of tasks) {
    const isChemicalPlan = Boolean(task.planId && (task.source === "lanthanum-plan" || task.source === "alkalinity-plan"));
    const key = isChemicalPlan ? JSON.stringify([task.tankId, task.source, task.planId]) : `task-${task.id}`;
    const group = groups.get(key);
    if (group) group.members.push(task);
    else groups.set(key, { key, isChemicalPlan, task, members: [task] });
  }
  return [...groups.values()].map((group) => {
    group.members.sort((a, b) => (a.scheduledDate ?? "").localeCompare(b.scheduledDate ?? ""));
    group.task = group.members.find((task) => task.scheduledDate === today) ?? group.members[0];
    return group;
  });
}

/** The all-plans catalog contains recurring rules and summaries of unfinished chemical plans only. */
export function taskCatalogGroups<T extends GroupableTask>(tasks: T[], today: string) {
  const recurringRules = tasks.filter((task) => Boolean(
    task.intervalDays
    && !task.oneOff
    && !task.planId
    && !task.stoppedAfterDate
    && task.state !== "done"
    && task.state !== "skipped",
  ));
  const unfinishedChemicalDays = tasks.filter((task) => Boolean(
    task.planId
    && (task.source === "lanthanum-plan" || task.source === "alkalinity-plan")
    && task.state !== "done"
    && task.state !== "skipped",
  ));
  return groupChemicalPlanTasks([...recurringRules, ...unfinishedChemicalDays], today);
}
