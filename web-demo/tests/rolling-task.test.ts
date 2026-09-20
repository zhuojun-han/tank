import assert from "node:assert/strict";
import test from "node:test";

import type { TaskItem } from "../app/demo-state.ts";
import {
  addTaskCalendarDays, completeRollingTask, correctRollingCompletion, delayRollingTask,
  initializeRollingTasks, isCalendarDate, projectRollingTasks, reopenRollingTask, stopRollingTask, taskDisplayDate,
} from "../app/rolling-task.ts";
import { completedTasksOnDate, editRecurringTask, groupChemicalPlanTasks, hasChemicalPlanFromDate, markTaskIncomplete, pendingTasksOnDate, pruneSupersededChemicalPlanOverlaps, removeChemicalPlansFromDate, stopChemicalPlanFromDay, taskCatalogGroups, taskOccursOnDate, taskStateOnDate } from "../app/task-calendar.ts";

function manual(overrides: Partial<TaskItem> = {}): TaskItem {
  return { id: 1, tankId: 1, title: "更换滤棉", cycle: "每 7 天", due: "今天", state: "due", scheduledDate: "2026-09-08", intervalDays: 7, ...overrides };
}

function ready(tasks: TaskItem[] = [manual()], today = "2026-09-08") {
  return initializeRollingTasks(tasks, today);
}

function date(tasks: TaskItem[], id: number, today: string) {
  return taskDisplayDate(projectRollingTasks(tasks, today).find(task => task.id === id)!);
}

function chemical(overrides: Partial<TaskItem> = {}): TaskItem {
  return manual({ title: "KH 第 1 天", cycle: "3 天计划", source: "alkalinity-plan", planId: "kh-1", oneOff: true, dayIndex: 1, intervalDays: 1, detail: "加入 12 ml", ...overrides });
}

test("one unresolved weekly occurrence rolls automatically, delays as a whole, and uses actual completion", () => {
  const original = [manual()];
  const tasks = ready(original);
  const snapshot = structuredClone(tasks);
  assert.equal(date(tasks, 1, "2026-09-08"), "2026-09-08");
  const projected = projectRollingTasks(tasks, "2026-09-09");
  assert.equal(taskDisplayDate(projected[0]), "2026-09-09");
  assert.equal(taskOccursOnDate(projected[0], "2026-09-08"), false);
  assert.equal(taskOccursOnDate(projected[0], "2026-09-16"), true);
  assert.equal(taskOccursOnDate(projected[0], "2026-09-15"), false);
  const delayed = delayRollingTask(tasks, 1, 2, "2026-09-09", 0);
  assert.equal(date(delayed, 1, "2026-09-09"), "2026-09-11");
  assert.equal(taskOccursOnDate(projectRollingTasks(delayed, "2026-09-09")[0], "2026-09-18"), true);
  assert.deepEqual(pendingTasksOnDate(projectRollingTasks(delayed, "2026-09-09"), "2026-09-09"), []);
  const completed = completeRollingTask(delayed, 1, "2026-09-08", "2026-09-09", 1);
  assert.equal(completed[0].rolling!.nextDate, "2026-09-15");
  assert.deepEqual(completed[0].rolling!.completed, [{ dueDate: "2026-09-11", completedDate: "2026-09-08" }]);
  assert.deepEqual(completedTasksOnDate(projectRollingTasks(completed, "2026-09-09"), "2026-09-08").map(task => task.id), [1]);
  assert.equal(taskOccursOnDate(projectRollingTasks(completed, "2026-09-09")[0], "2026-09-11"), false);
  assert.deepEqual(tasks, snapshot);
  assert.equal(original[0].rolling, undefined);
});

test("calendar projection and reload are pure and do not manufacture daily completion history", () => {
  const nativeId = "fbc9e91d-63e2-47f1-9c20-af429ea0a631";
  const tasks = ready([manual({ scheduledDate: "2020-01-01" }), manual({ id: nativeId, tankId: "9007199254740993", scheduledDate: "2020-01-01" })]);
  const before = JSON.stringify(tasks);
  for (const today of ["2026-09-08", "2026-09-09", "2027-01-01"]) {
    const loaded = initializeRollingTasks(JSON.parse(before) as TaskItem[], today);
    assert.deepEqual(loaded, tasks);
    const projected = projectRollingTasks(loaded, today);
    assert.deepEqual(pendingTasksOnDate(projected, today).map(task => task.id), [1, nativeId]);
    assert.equal(completedTasksOnDate(projected, addTaskCalendarDays(today, -1)).length, 0);
  }
  assert.equal(JSON.stringify(tasks), before);
  assert.equal(tasks[0].defaultCompletedBeforeDate, undefined);
  const delayed = delayRollingTask(tasks, nativeId, 2, "2026-09-08");
  const completed = completeRollingTask(JSON.parse(JSON.stringify(delayed)), nativeId, "2026-09-08", "2026-09-08");
  assert.equal(completed[1].id, nativeId);
  assert.equal(completed[1].tankId, "9007199254740993");
  assert.equal(completed[1].rolling!.nextDate, "2026-09-15");
  assert.deepEqual(completed[0], tasks[0]);
});

test("native monthly tasks retain month-end recurrence, legacy history, and actual-completion anchoring", () => {
  const monthly = manual({ id: "monthly-native", tankId: "native-tank", intervalDays: undefined, nativeIntervalUnit: "month", nativeIntervalAmount: 1,
    scheduledDate: "2026-01-31", rolling: { version: 1, nextDate: "2026-01-31", revision: 0, completed: [] } });
  const projected = projectRollingTasks([monthly], "2026-01-31")[0];
  for (const day of ["2026-01-31", "2026-02-28", "2026-03-31", "2026-04-30"]) assert.equal(taskOccursOnDate(projected, day), true, day);
  for (const day of ["2026-02-01", "2026-02-27", "2026-03-28", "2026-04-29"]) assert.equal(taskOccursOnDate(projected, day), false, day);
  assert.equal(taskCatalogGroups([projected], "2026-01-31").length, 1);
  const completed = completeRollingTask([monthly], monthly.id, "2026-01-31", "2026-01-31");
  assert.equal(completed[0].rolling!.nextDate, "2026-02-28");
  const again = completeRollingTask(JSON.parse(JSON.stringify(completed)), monthly.id, "2026-02-28", "2026-02-28");
  assert.equal(again[0].rolling!.nextDate, "2026-03-28");
  const legacy = { ...monthly, rolling: { ...monthly.rolling!, nextDate: "2026-04-30", legacySchedule: {
    scheduledDate: "2026-01-31", defaultCompletedBeforeDate: "2026-04-01", nativeIntervalUnit: "month" as const, nativeIntervalAmount: 1,
  } } };
  for (const day of ["2026-01-31", "2026-02-28", "2026-03-31"]) assert.equal(completedTasksOnDate([legacy], day, "2026-04-01").length, 1, day);
  assert.equal(completedTasksOnDate([legacy], "2026-03-28", "2026-04-01").length, 0);
  const leap = { ...monthly, rolling: { ...monthly.rolling!, nextDate: "2028-01-31" } };
  assert.equal(taskOccursOnDate(projectRollingTasks([leap], "2028-01-31")[0], "2028-02-29"), true);
  assert.equal(taskOccursOnDate(projectRollingTasks([leap], "2028-01-31")[0], "2028-02-28"), false);
});

test("legacy migration keeps real and implicit history, preserves missing-source manual tasks, and respects reopened dates", () => {
  const tasks = [
    manual({ scheduledDate: "2026-09-01", completedDates: ["2026-09-08"], skippedDates: ["2026-09-15"] }),
    manual({ id: 2, scheduledDate: "2026-09-01", intervalDays: 2, defaultCompletedBeforeDate: "2026-09-08", reopenedDates: ["2026-09-03"] }),
    manual({ id: 3, oneOff: true, intervalDays: undefined, scheduledDate: "2026-09-01", state: "done", handledAt: "以前完成" }),
    manual({ id: 4, scheduledDate: "2026-09-01", intervalDays: 2, stoppedAfterDate: "2026-09-05", state: "skipped", completedDates: ["2026-09-03"], skippedDates: ["2026-09-05"] }),
  ];
  const before = structuredClone(tasks);
  const migrated = initializeRollingTasks(tasks, "2026-09-08");
  assert.equal(migrated[0].rolling!.nextDate, "2026-09-22");
  assert.equal(migrated[1].rolling!.nextDate, "2026-09-03");
  const projected = projectRollingTasks(migrated, "2026-09-08");
  assert.equal(taskOccursOnDate(projected[0], "2026-09-01"), false);
  assert.equal(taskStateOnDate(projected[0], "2026-09-08", "2026-09-08"), "done");
  assert.equal(taskStateOnDate(projected[0], "2026-09-15", "2026-09-08"), "skipped");
  assert.equal(taskOccursOnDate(projected[1], "2026-09-03"), false);
  assert.equal(taskStateOnDate(projected[1], "2026-09-05", "2026-09-08"), "done");
  assert.equal(taskOccursOnDate(projected[2], "2026-09-01"), true);
  assert.equal(taskOccursOnDate(projected[2], "2026-09-08"), false);
  assert.equal(taskOccursOnDate(projected[3], "2026-09-07"), false);
  assert.deepEqual(tasks, before);
  assert.deepEqual(migrated[0].completedDates, before[0].completedDates);
  assert.deepEqual(migrated[0].skippedDates, before[0].skippedDates);
});

test("legacy migration keeps duplicate history and chooses only the earliest unresolved date on its recurrence", () => {
  const task = manual({
    scheduledDate: "2026-09-01", intervalDays: 2, defaultCompletedBeforeDate: "2026-09-15",
    completedDates: ["2026-09-05", "2026-09-02", "2026-09-05"],
    skippedDates: ["2026-09-07"],
    reopenedDates: ["2026-09-11", "2026-09-05", "2026-08-30", "2026-09-04", "2026-09-03", "2026-09-07", "2026-09-03"],
  });
  const before = structuredClone(task);
  const [migrated] = ready([task]);
  assert.equal(migrated.rolling!.nextDate, "2026-09-03");
  assert.deepEqual(migrated.rolling!.completed, []);
  for (const key of ["completedDates", "skippedDates", "reopenedDates"] as const) {
    assert.deepEqual(migrated[key], before[key]);
  }
  assert.deepEqual(task, before);
  const [handledOnly] = ready([{ ...task, reopenedDates: ["2026-09-07", "2026-09-05", "2026-09-02"] }]);
  assert.equal(handledOnly.rolling!.nextDate, "2026-09-15");
});

test("old decades-long default history migrates by interval arithmetic and retains its rule on edit", () => {
  const tasks = ready([manual({ scheduledDate: "1980-01-01", intervalDays: 2, defaultCompletedBeforeDate: "2026-09-08" })]);
  assert.equal(tasks[0].rolling!.nextDate, "2026-09-08");
  const edited = editRecurringTask(tasks, 1, { title: "新名称", cycle: "每 7 天", due: "下次", state: "soon", scheduledDate: "2026-09-10", intervalDays: 7 });
  assert.equal(edited[0].scheduledDate, "1980-01-01");
  assert.equal(taskOccursOnDate(projectRollingTasks(edited, "2026-09-08")[0], "2026-09-17"), true);
  for (const day of ["1980-01-01", "1980-01-02", "1980-01-03", "2026-09-06"]) {
    assert.equal(taskOccursOnDate(edited[0], day), taskOccursOnDate(tasks[0], day));
  }
});

test("finite chemical days roll as one queue with no duplicate due days or extra doses", () => {
  const tasks = ready([
    chemical(), chemical({ id: 2, dayIndex: 2, scheduledDate: "2026-09-09", detail: "加入 10 ml" }),
    chemical({ id: 3, dayIndex: 3, scheduledDate: "2026-09-10", detail: "加入 8 ml" }),
    chemical({ id: 4, tankId: 2 }), chemical({ id: 5, source: "lanthanum-plan" }), chemical({ id: 6, planId: "kh-2" }),
  ]);
  const projected = projectRollingTasks(tasks, "2026-09-11");
  assert.deepEqual(projected.slice(0, 3).map(task => taskDisplayDate(task)), ["2026-09-11", "2026-09-12", "2026-09-13"]);
  assert.equal(pendingTasksOnDate(projected.slice(0, 3), "2026-09-11").length, 1);
  const groups = groupChemicalPlanTasks(projected, "2026-09-11");
  assert.equal(groups[0].task.id, 1);
  const delayed = delayRollingTask(tasks, 1, 2, "2026-09-11");
  assert.deepEqual(delayed.slice(0, 3).map(task => task.rolling!.nextDate), ["2026-09-13", "2026-09-14", "2026-09-15"]);
  assert.deepEqual(delayed.slice(3), tasks.slice(3));
  const completed = completeRollingTask(delayed, 1, "2026-09-10", "2026-09-11");
  assert.equal(completed[0].state, "done");
  assert.deepEqual(completed.slice(1, 3).map(task => task.rolling!.nextDate), ["2026-09-11", "2026-09-12"]);
  assert.deepEqual(completed.map(task => [task.scheduledDate, task.detail]), tasks.map(task => [task.scheduledDate, task.detail]));
  assert.deepEqual(completed.slice(3), tasks.slice(3));
  assert.deepEqual(pendingTasksOnDate(projectRollingTasks(completed, "2026-09-11").slice(0, 3), "2026-09-11").map(task => task.id), [2]);
  assert.equal(taskOccursOnDate(projectRollingTasks(completed, "2026-09-11")[0], "2026-09-13"), false);
  assert.throws(() => completeRollingTask(tasks, 2, "2026-09-11", "2026-09-11"), /较早/);
  assert.throws(() => completeRollingTask(completed, 2, "2026-09-10", "2026-09-11"), /上一次/);
});

test("completion-date corrections and reopen affect only the latest real completion and its future", () => {
  const first = completeRollingTask(ready(), 1, "2026-09-08", "2026-09-08");
  const second = completeRollingTask(first, 1, "2026-09-16", "2026-09-16");
  const corrected = correctRollingCompletion(second, 1, "2026-09-16", "2026-09-15", "2026-09-16", 2);
  assert.equal(corrected[0].rolling!.nextDate, "2026-09-22");
  assert.deepEqual(corrected[0].rolling!.completed, [{ dueDate: "2026-09-08", completedDate: "2026-09-08" }, { dueDate: "2026-09-16", completedDate: "2026-09-15" }]);
  assert.throws(() => correctRollingCompletion(corrected, 1, "2026-09-08", "2026-09-09", "2026-09-16"), /最近一次/);
  assert.throws(() => correctRollingCompletion(corrected, 1, "2026-09-15", "2026-09-08", "2026-09-16"), /上一次/);
  assert.throws(() => reopenRollingTask(corrected, 1, "2026-09-08", "2026-09-16"), /最近一次/);
  const reopened = markTaskIncomplete(corrected, 1, "2026-09-15", "2026-09-16");
  assert.equal(reopened[0].rolling!.nextDate, "2026-09-16");
  assert.equal(reopened[0].rolling!.completed.length, 1);
  assert.equal(completedTasksOnDate(projectRollingTasks(reopened, "2026-09-16"), "2026-09-15").length, 0);
  assert.equal(pendingTasksOnDate(projectRollingTasks(reopened, "2026-09-16"), "2026-09-16").length, 1);
});

test("reopening legacy implicit history makes one pending head without duplicate historical pending dates", () => {
  const tasks = ready([manual({ scheduledDate: "2026-09-01", intervalDays: 2, defaultCompletedBeforeDate: "2026-09-08" })]);
  const reopened = reopenRollingTask(tasks, 1, "2026-09-07", "2026-09-08");
  const projected = projectRollingTasks(reopened, "2026-09-08");
  assert.equal(taskOccursOnDate(projected[0], "2026-09-07"), false);
  assert.equal(taskStateOnDate(projected[0], "2026-09-05", "2026-09-08"), "done");
  assert.deepEqual(pendingTasksOnDate(projected, "2026-09-08").map(task => task.id), [1]);
  assert.equal(reopened[0].defaultCompletedBeforeDate, tasks[0].defaultCompletedBeforeDate);
});

test("finite correction, reopening, and stop retain completed doses and isolate tanks", () => {
  const tasks = ready([chemical(), chemical({ id: 2, scheduledDate: "2026-09-09", dayIndex: 2 }), chemical({ id: 3, tankId: 2 })]);
  const completed = completeRollingTask(tasks, 1, "2026-09-10", "2026-09-11");
  const corrected = correctRollingCompletion(completed, 1, "2026-09-10", "2026-09-09", "2026-09-11");
  assert.equal(corrected[1].rolling!.nextDate, "2026-09-10");
  const reopened = reopenRollingTask(corrected, 1, "2026-09-09", "2026-09-11");
  assert.deepEqual(reopened.slice(0, 2).map(task => task.rolling!.nextDate), ["2026-09-11", "2026-09-12"]);
  assert.deepEqual(reopened[2], tasks[2]);
  const stopped = stopRollingTask(completed, 2, "2026-09-11");
  assert.deepEqual(stopped[0], completed[0]);
  assert.equal(stopped[1].state, "skipped");
  assert.equal(taskOccursOnDate(stopped[1], "2026-09-12"), false);
  assert.deepEqual(stopped[2], tasks[2]);
});

test("stopping ordinary recurrence preserves completed history without a later pending occurrence", () => {
  const completed = completeRollingTask(ready(), 1, "2026-09-08", "2026-09-08");
  const stopped = stopRollingTask(completed, 1, "2026-09-10");
  assert.equal(taskStateOnDate(stopped[0], "2026-09-08", "2026-09-10"), "done");
  assert.equal(taskStateOnDate(stopped[0], "2026-09-15", "2026-09-10"), "skipped");
  assert.equal(pendingTasksOnDate(projectRollingTasks(stopped, "2026-09-22"), "2026-09-22").length, 0);
});

test("invalid dates, delays and stale confirmations throw without changing the input", () => {
  const tasks = ready();
  const before = structuredClone(tasks);
  for (const day of ["2026-02-30", "2026-9-8", "not-a-date", "2026-09-07", "2026-09-10"]) {
    assert.throws(() => completeRollingTask(tasks, 1, day, "2026-09-09"));
  }
  for (const days of [0, -1, 0.5, Number.NaN, Number.POSITIVE_INFINITY, Number.MAX_SAFE_INTEGER]) assert.throws(() => delayRollingTask(tasks, 1, days, "2026-09-09"));
  const completed = completeRollingTask(tasks, 1, "2026-09-08", "2026-09-09", 0);
  assert.throws(() => completeRollingTask(completed, 1, "2026-09-09", "2026-09-09", 0), /已更新/);
  assert.throws(() => delayRollingTask(completed, 1, 1, "2026-09-09", 0), /已更新/);
  assert.deepEqual(tasks, before);
});

test("calendar arithmetic crosses months, years, leap days and DST without elapsed-hour drift", () => {
  for (const [start, days, expected] of [
    ["2026-09-30", 1, "2026-10-01"], ["2026-12-31", 1, "2027-01-01"],
    ["2028-02-28", 1, "2028-02-29"], ["2028-02-28", 2, "2028-03-01"],
    ["2026-03-07", 2, "2026-03-09"], ["2026-10-31", 2, "2026-11-02"],
  ] as const) assert.equal(addTaskCalendarDays(start, days), expected);
  assert.equal(isCalendarDate("2026-02-29"), false);
  assert.equal(isCalendarDate("2028-02-29"), true);
  const tasks = ready([manual({ scheduledDate: "2026-12-31" })], "2026-12-31");
  const delayed = delayRollingTask(tasks, 1, 1, "2026-12-31");
  assert.equal(date(delayed, 1, "2027-01-01"), "2027-01-01");
});

test("legacy one-off snooze and virtual maintenance items retain their existing contracts", () => {
  const future = new Date(2026, 8, 10, 9).toISOString();
  const tasks = ready([
    manual({ oneOff: true, state: "snoozed", snoozedUntil: future }),
    manual({ id: 2, source: "maintenance-cycle", oneOff: true }),
    manual({ id: 3, intervalDays: 1.5 }),
  ]);
  assert.equal(date(tasks, 1, "2026-09-08"), "2026-09-10");
  assert.equal(tasks[1].rolling, undefined);
  assert.equal(tasks[2].rolling, undefined);
  const delayed = delayRollingTask(tasks, 1, 1, "2026-09-08");
  assert.equal(delayed[0].rolling!.nextDate, "2026-09-11");
  assert.equal(delayed[0].snoozedUntil, undefined);
});

test("delayed finite replacement uses effective dates and never erases completion evidence on reload", () => {
  const tasks = ready([
    chemical({ id: 1, scheduledDate: "2026-09-01", state: "done", handledAt: "已完成" }),
    chemical({ id: 2, scheduledDate: "2026-09-02", dayIndex: 2 }),
    chemical({ id: 3, scheduledDate: "2026-09-03", dayIndex: 3 }),
    chemical({ id: 4, scheduledDate: "2026-09-02", tankId: 2 }),
  ]);
  assert.equal(hasChemicalPlanFromDate(tasks, 1, "alkalinity-plan", "2026-09-09", "2026-09-08"), true);
  const replaced = removeChemicalPlansFromDate(tasks, 1, "alkalinity-plan", "2026-09-09", "2026-09-08");
  assert.deepEqual(replaced.map(task => task.id), [1, 2, 4]);
  const withNew = [...tasks, ...ready([chemical({ id: 10, planId: "new", scheduledDate: "2026-09-02" })])];
  assert.deepEqual(pruneSupersededChemicalPlanOverlaps(withNew), withNew);
  assert.equal(removeChemicalPlansFromDate(tasks, 1, "alkalinity-plan", "2026-08-01", "2026-09-08").some(task => task.id === 1), true);
});

test("stopping a delayed chemical day uses its displayed stop date and never affects another tank", () => {
  const tasks = ready([chemical(), chemical({ id: 2, dayIndex: 2, scheduledDate: "2026-09-09" }), chemical({ id: 3, tankId: 2 })]);
  const stopped = stopChemicalPlanFromDay(tasks, 1, "停止", true, "2026-09-11");
  assert.equal(taskOccursOnDate(stopped[0], "2026-09-11"), true);
  assert.equal(taskOccursOnDate(stopped[0], "2026-09-08"), false);
  assert.equal(taskStateOnDate(stopped[0], "2026-09-11", "2026-09-11"), "skipped");
  assert.equal(taskOccursOnDate(stopped[1], "2026-09-12"), false);
  assert.deepEqual(stopped[2], tasks[2]);
});

test("projected status follows its current due date and completed finite details use actual date", () => {
  const tasks = delayRollingTask(ready(), 1, 2, "2026-09-08");
  assert.equal(projectRollingTasks(tasks, "2026-09-09")[0].state, "soon");
  assert.equal(projectRollingTasks(tasks, "2026-09-10")[0].state, "due");
  assert.equal(projectRollingTasks(tasks, "2026-09-11")[0].state, "due");
  assert.equal(tasks[0].state, "soon");
  const completed = completeRollingTask(ready([chemical()]), 1, "2026-09-09", "2026-09-10");
  assert.equal(taskDisplayDate(projectRollingTasks(completed, "2026-09-11")[0]), "2026-09-09");
});

test("backdating cannot cross the last explicit legacy completion and a reopened head is not hidden by old skipped evidence", () => {
  const tasks = ready([manual({ scheduledDate: "2026-09-01", completedDates: ["2026-09-08"] })]);
  assert.throws(() => completeRollingTask(tasks, 1, "2026-09-07", "2026-09-09"), /上一次/);
  assert.throws(() => completeRollingTask(tasks, 1, "2026-09-08", "2026-09-09"), /上一次/);
  const first = completeRollingTask(ready(), 1, "2026-09-08", "2026-09-08");
  const stopped = stopRollingTask(first, 1, "2026-09-09");
  const reopened = reopenRollingTask(stopped, 1, "2026-09-08", "2026-09-09");
  assert.deepEqual(reopened[0].skippedDates, ["2026-09-15"]);
  assert.equal(pendingTasksOnDate(projectRollingTasks(reopened, "2026-09-15"), "2026-09-15").length, 1);
});

test("projection selects each mixed queue head by date, day index and id without mutating history", () => {
  const tasks = ready([
    chemical({ id: 30, scheduledDate: "2026-09-01", dayIndex: 2, snoozedUntil: "2026-09-15T12:00:00Z" }),
    chemical({ id: 20, scheduledDate: "2026-09-01", dayIndex: 1, snoozedUntil: "2026-09-14T12:00:00Z" }),
    chemical({ id: 10, scheduledDate: "2026-09-01", dayIndex: 1, snoozedUntil: "2026-09-10T12:00:00Z" }),
    chemical({ id: 40, scheduledDate: "2026-09-02", dayIndex: 3 }),
    chemical({ id: 50, scheduledDate: "2026-08-01", hiddenFromCalendar: true }),
    chemical({ id: 60, scheduledDate: "2026-08-01", state: "done", completedDates: ["2026-08-01"] }),
    chemical({ id: 70, scheduledDate: "2026-09-02", tankId: 2 }),
    chemical({ id: 80, scheduledDate: "2026-09-12", source: "lanthanum-plan" }),
    chemical({ id: 90, scheduledDate: "2026-09-03", planId: "another-plan" }),
    manual({ id: 100, scheduledDate: "2026-09-04" }),
  ]);
  const before = structuredClone(tasks);
  const projected = projectRollingTasks(tasks, "2026-09-08");
  assert.deepEqual(projected.slice(0, 4).map(task => taskDisplayDate(task)), ["2026-09-10", "2026-09-10", "2026-09-10", "2026-09-11"]);
  assert.equal(projected[4], tasks[4]);
  assert.equal(projected[5], tasks[5]);
  assert.deepEqual(projected.slice(6).map(task => taskDisplayDate(task)), ["2026-09-08", "2026-09-12", "2026-09-08", "2026-09-08"]);
  assert.deepEqual(tasks, before);
});

test("many independent chemical plans require only linear grouping reads", () => {
  let planReads = 0;
  const tasks = Array.from({ length: 2_500 }, (_, index) => {
    const task = chemical({ id: index + 1, scheduledDate: "2026-09-01",
      rolling: { version: 1, nextDate: "2026-09-01", revision: 0, completed: [] } });
    Object.defineProperty(task, "planId", { enumerable: true, get() { planReads++; return `plan-${index}`; } });
    return task;
  });
  const projected = projectRollingTasks(tasks, "2026-09-08");
  assert.equal(projected.length, tasks.length);
  assert.ok(projected.every(task => taskDisplayDate(task) === "2026-09-08"));
  assert.ok(planReads < tasks.length * 12, `grouping read plan identifiers ${planReads} times`);
  assert.ok(tasks.every(task => task.rolling!.nextDate === "2026-09-01" && task.rolling!.completed.length === 0));
});
