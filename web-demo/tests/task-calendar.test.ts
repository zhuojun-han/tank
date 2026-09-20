import assert from "node:assert/strict";
import test from "node:test";

import { completedTasksOnDate, editRecurringTask, groupChemicalPlanTasks, hasChemicalPlanFromDate, markTaskIncomplete, pendingTasksOnDate, pruneSupersededChemicalPlanOverlaps, removeChemicalPlansFromDate, stopChemicalPlanFromDay, stopRecurringTaskFromDate, taskCatalogGroups, taskOccursOnDate, taskStateOnDate, wakeExpiredSnoozedTasks } from "../app/task-calendar.ts";

test("editing a recurring task updates the rule and preserves occurrence history", () => {
  const original = [{
    id: 1,
    title: "清洗滤棉",
    cycle: "每 7 天",
    due: "9月1日周二 09:00",
    scheduledDate: "2026-09-01",
    intervalDays: 7,
    state: "due" as const,
    completedDates: ["2026-09-01"],
    skippedDates: ["2026-09-08"],
    reopenedDates: ["2026-08-25"],
  }];

  const edited = editRecurringTask(original, 1, {
    title: "更换滤棉",
    cycle: "每 5 天",
    due: "9月2日周三 10:30",
    scheduledDate: "2026-09-02",
    intervalDays: 5,
    state: "soon",
    defaultCompletedBeforeDate: "2026-09-05",
  });

  assert.equal(edited[0].id, 1);
  assert.equal(edited[0].title, "更换滤棉");
  assert.equal(edited[0].intervalDays, 5);
  assert.deepEqual(edited[0].completedDates, ["2026-09-01"]);
  assert.deepEqual(edited[0].skippedDates, ["2026-09-08"]);
  assert.deepEqual(edited[0].reopenedDates, ["2026-08-25"]);
});

test("stopping a recurring user task preserves history and removes future dates", () => {
  const tasks = [{
    id: 1,
    scheduledDate: "2026-09-01",
    intervalDays: 2,
    state: "due" as const,
    completedDates: ["2026-09-03"],
    skippedDates: [],
    snoozedDates: ["2026-09-05"],
  }];
  const stopped = stopRecurringTaskFromDate(tasks, 1, "2026-09-05");
  assert.equal(taskOccursOnDate(stopped[0], "2026-09-03"), true);
  assert.equal(taskStateOnDate(stopped[0], "2026-09-03", "2026-09-05"), "done");
  assert.equal(taskOccursOnDate(stopped[0], "2026-09-05"), true);
  assert.equal(taskStateOnDate(stopped[0], "2026-09-05", "2026-09-05"), "skipped");
  assert.equal(taskOccursOnDate(stopped[0], "2026-09-07"), false);
  assert.deepEqual(stopped[0].snoozedDates, []);
  assert.deepEqual(tasks[0].state, "due");
});

test("a snoozed recurring occurrence is pending only on that date", () => {
  const task = { scheduledDate: "2026-09-01", intervalDays: 2, state: "due" as const, snoozedDates: ["2026-09-05"] };
  assert.equal(taskStateOnDate(task, "2026-09-03", "2026-09-05"), "due");
  assert.equal(taskStateOnDate(task, "2026-09-05", "2026-09-05"), "snoozed");
  assert.equal(taskStateOnDate(task, "2026-09-07", "2026-09-05"), "soon");
});

test("timed snoozes wake one-off and recurring occurrences at their deadline", () => {
  const tasks = [
    { id: 1, state: "snoozed" as const, snoozedUntil: "2026-09-05T10:00:00.000Z" },
    { id: 2, state: "due" as const, scheduledDate: "2026-09-01", intervalDays: 2, snoozedDates: ["2026-09-03", "2026-09-05"], snoozedUntilByDate: { "2026-09-03": "2026-09-05T10:00:00.000Z", "2026-09-05": "2026-09-05T12:00:00.000Z" } },
  ];
  const awakened = wakeExpiredSnoozedTasks(tasks, "2026-09-05T11:00:00.000Z");
  assert.equal(awakened[0].state, "due");
  assert.equal(awakened[0].snoozedUntil, undefined);
  assert.deepEqual(awakened[1].snoozedDates, ["2026-09-05"]);
  assert.deepEqual(awakened[1].snoozedUntilByDate, { "2026-09-05": "2026-09-05T12:00:00.000Z" });
  assert.equal(taskStateOnDate(awakened[1], "2026-09-03", "2026-09-05"), "due");
  assert.equal(taskStateOnDate(awakened[1], "2026-09-05", "2026-09-05"), "snoozed");
});

test("timed snoozes compare instants across offsets and leave future or invalid deadlines unchanged", () => {
  const tasks = [
    { id: 1, state: "snoozed" as const, snoozedUntil: "2026-09-05T18:00:00+08:00" },
    { id: 2, state: "snoozed" as const, snoozedUntil: "2026-09-05T03:00:00-07:00" },
    { id: 3, state: "snoozed" as const, snoozedUntil: "2026-09-05T09:30:00-01:00" },
    { id: 4, state: "snoozed" as const, snoozedUntil: "!invalid" },
    {
      id: 5, state: "due" as const, intervalDays: 1,
      snoozedDates: ["2026-09-01", "2026-09-02", "2026-09-03", "2026-09-04"],
      snoozedUntilByDate: {
        "2026-09-01": "2026-09-05T18:00:00+08:00",
        "2026-09-02": "2026-09-05T03:00:00-07:00",
        "2026-09-03": "2026-09-05T09:30:00-01:00",
        "2026-09-04": "!invalid",
      },
    },
  ];
  const before = structuredClone(tasks);
  for (const now of ["2026-09-05T10:00:00Z", "2026-09-05T18:00:00+08:00", "2026-09-05T03:00:00-07:00"]) {
    const awakened = wakeExpiredSnoozedTasks(tasks, now);
    assert.deepEqual(awakened.slice(0, 2).map(task => [task.state, task.snoozedUntil]), [["due", undefined], ["due", undefined]]);
    assert.deepEqual(awakened.slice(2, 4), before.slice(2, 4));
    assert.deepEqual(awakened[4].snoozedDates, ["2026-09-03", "2026-09-04"]);
    assert.deepEqual(awakened[4].snoozedUntilByDate, {
      "2026-09-03": "2026-09-05T09:30:00-01:00", "2026-09-04": "!invalid",
    });
  }
  assert.deepEqual(tasks, before);
  assert.strictEqual(wakeExpiredSnoozedTasks(tasks, "invalid-now"), tasks);
});

test("stopping a chemical plan keeps the selected day but removes later days from calendar", () => {
  const tasks = [
    { id: 1, tankId: 1, source: "alkalinity-plan", planId: "kh-1", dayIndex: 1, scheduledDate: "2026-09-05", state: "due" as const },
    { id: 2, tankId: 1, source: "alkalinity-plan", planId: "kh-1", dayIndex: 2, scheduledDate: "2026-09-06", state: "soon" as const },
    { id: 3, tankId: 1, source: "alkalinity-plan", planId: "kh-1", dayIndex: 3, scheduledDate: "2026-09-07", state: "soon" as const },
    { id: 4, tankId: 1, source: "alkalinity-plan", planId: "kh-1", dayIndex: 0, scheduledDate: "2026-09-04", state: "done" as const },
    { id: 5, tankId: 1, source: "lanthanum-plan", planId: "po4-1", dayIndex: 2, scheduledDate: "2026-09-06", state: "soon" as const },
  ];
  const stopped = stopChemicalPlanFromDay(tasks, 1, "stopped");
  assert.equal(taskOccursOnDate(stopped[0], "2026-09-05"), true);
  assert.equal(stopped[0].state, "skipped");
  assert.equal(stopped[0].hiddenFromCalendar, false);
  assert.equal(taskOccursOnDate(stopped[1], "2026-09-06"), false);
  assert.equal(taskOccursOnDate(stopped[2], "2026-09-07"), false);
  assert.equal(stopped[1].hiddenFromCalendar, true);
  assert.deepEqual(stopped.slice(3), tasks.slice(3));
  assert.deepEqual(tasks[1].state, "soon");
});

test("stopping a future-only summary removes every remaining day from calendar", () => {
  const tasks = [
    { id: 1, tankId: 1, source: "lanthanum-plan", planId: "po4-1", dayIndex: 2, scheduledDate: "2026-09-06", state: "soon" as const },
    { id: 2, tankId: 1, source: "lanthanum-plan", planId: "po4-1", dayIndex: 3, scheduledDate: "2026-09-07", state: "soon" as const },
  ];
  const stopped = stopChemicalPlanFromDay(tasks, 1, "stopped", false);
  assert.ok(stopped.every((task) => task.state === "skipped" && task.hiddenFromCalendar));
  assert.ok(stopped.every((task) => !taskOccursOnDate(task, task.scheduledDate)));
});

test("home selects only today's pending occurrences, including recurring completion", () => {
  const tasks = [
    { id: 1, scheduledDate: "2026-09-04", state: "due" as const },
    { id: 2, scheduledDate: "2026-09-05", state: "soon" as const },
    { id: 3, scheduledDate: "2026-09-06", state: "soon" as const },
    { id: 4, scheduledDate: "2026-09-05", state: "done" as const },
    { id: 5, scheduledDate: "2026-09-05", state: "skipped" as const },
    { id: 6, scheduledDate: "2026-08-29", intervalDays: 7, state: "due" as const, completedDates: ["2026-09-05"] },
    { id: 7, scheduledDate: "2026-08-29", intervalDays: 7, state: "due" as const },
    { id: 8, scheduledDate: "2026-08-29", intervalDays: 7, state: "due" as const, skippedDates: ["2026-09-05"] },
  ];
  assert.deepEqual(pendingTasksOnDate(tasks, "2026-09-05").map((task) => task.id), [2, 7]);
  assert.deepEqual(pendingTasksOnDate(tasks, "2026-09-06").map((task) => task.id), [3]);
  assert.ok(pendingTasksOnDate(tasks, "2026-09-12").some((task) => task.id === 6));
});

test("completed view contains only occurrences completed on the selected day", () => {
  const tasks = [
    { id: 1, scheduledDate: "2026-09-05", state: "done" as const },
    { id: 2, scheduledDate: "2026-09-04", state: "done" as const },
    { id: 3, scheduledDate: "2026-09-05", state: "skipped" as const },
    { id: 4, scheduledDate: "2026-08-29", intervalDays: 7, state: "due" as const, completedDates: ["2026-09-05"] },
    { id: 5, scheduledDate: "2026-08-29", intervalDays: 7, state: "due" as const, completedDates: ["2026-09-12"] },
    { id: 6, scheduledDate: "2026-09-05", state: "due" as const },
  ];

  assert.deepEqual(completedTasksOnDate(tasks, "2026-09-05").map((task) => task.id), [1, 4]);
  assert.deepEqual(tasks[3].state, "due");
});

test("all catalog contains active recurring rules and unfinished chemical plan summaries only", () => {
  const tasks = [
    { id: 1, tankId: 1, source: "manual", scheduledDate: "2026-09-05", intervalDays: 7, state: "due" as const },
    { id: 2, tankId: 1, source: "manual", scheduledDate: "2026-09-05", intervalDays: 3, stoppedAfterDate: "2026-09-05", state: "skipped" as const },
    { id: 3, tankId: 1, source: "manual", scheduledDate: "2026-09-05", oneOff: true, state: "due" as const },
    { id: 4, tankId: 1, source: "alkalinity-plan", planId: "kh-1", scheduledDate: "2026-09-05", state: "due" as const },
    { id: 5, tankId: 1, source: "alkalinity-plan", planId: "kh-1", scheduledDate: "2026-09-06", state: "soon" as const },
    { id: 6, tankId: 1, source: "alkalinity-plan", planId: "kh-1", scheduledDate: "2026-09-04", state: "done" as const },
    { id: 7, tankId: 1, source: "lanthanum-plan", planId: "po4-1", scheduledDate: "2026-09-04", state: "done" as const },
    { id: 8, tankId: 1, source: "manual", scheduledDate: "2026-09-05", state: "due" as const },
  ];

  const groups = taskCatalogGroups(tasks, "2026-09-05");
  assert.deepEqual(groups.map((group) => group.key), ["task-1", JSON.stringify([1, "alkalinity-plan", "kh-1"])]);
  assert.deepEqual(groups[1].members.map((task) => task.id), [4, 5]);
});

test("groups each chemical plan once without merging different tanks, sources or manual tasks", () => {
  const base = { tankId: 1, source: "alkalinity-plan", planId: "kh-1", state: "soon" as const };
  const tasks = [
    { ...base, id: 1, scheduledDate: "2026-09-06" },
    { ...base, id: 2, scheduledDate: "2026-09-05" },
    { ...base, id: 3, scheduledDate: "2026-09-04" },
    { ...base, id: 4, source: "lanthanum-plan", scheduledDate: "2026-09-05" },
    { ...base, id: 5, tankId: 2, scheduledDate: "2026-09-05" },
    { ...base, id: 6, planId: "kh-2", scheduledDate: "2026-09-05" },
    { ...base, id: 7, source: "manual", scheduledDate: "2026-09-05" },
    { ...base, id: 8, planId: undefined, scheduledDate: "2026-09-05" },
  ];
  const before = structuredClone(tasks);
  const groups = groupChemicalPlanTasks(tasks, "2026-09-05");
  assert.equal(groups.length, 6);
  assert.equal(groups[0].task.id, 2);
  assert.deepEqual(groups[0].members.map((task) => task.id), [3, 2, 1]);
  assert.equal(groups[4].isChemicalPlan, false);
  assert.equal(groups[5].isChemicalPlan, false);
  assert.deepEqual(tasks, before);
  const completedToday = tasks.map((task) => task.id === 2 ? { ...task, state: "done" as const } : task);
  assert.ok(!groupChemicalPlanTasks(pendingTasksOnDate(completedToday, "2026-09-05"), "2026-09-05").some((group) => group.key === groups[0].key));
  assert.ok(pendingTasksOnDate(completedToday, "2026-09-06").some((task) => task.id === 1));
});

for (const source of ["lanthanum-plan", "alkalinity-plan"] as const) {
  test(`${source}: replacement preserves history before its start date`, () => {
    const tasks = [
      { id: 1, tankId: 1, source, scheduledDate: "2026-09-01", state: "done" as const, handledAt: "already done" },
      { id: 2, tankId: 1, source, scheduledDate: "2026-09-02", state: "done" as const, handledAt: "already done" },
      { id: 3, tankId: 1, source, scheduledDate: "2026-09-03", state: "done" as const, handledAt: "already done" },
      { id: 4, tankId: 1, source, scheduledDate: "2026-09-04", state: "soon" as const },
      { id: 5, tankId: 1, source, scheduledDate: "2026-09-05", state: "soon" as const },
      { id: 6, tankId: 2, source, scheduledDate: "2026-09-04", state: "due" as const },
      { id: 7, tankId: 1, source: source === "lanthanum-plan" ? "alkalinity-plan" : "lanthanum-plan", scheduledDate: "2026-09-04", state: "due" as const },
      { id: 8, tankId: 1, scheduledDate: "2026-09-04", state: "due" as const },
    ];
    const before = structuredClone(tasks);
    assert.equal(hasChemicalPlanFromDate(tasks, 1, source, "2026-09-04"), true);
    const remaining = removeChemicalPlansFromDate(tasks, 1, source, "2026-09-04");
    assert.deepEqual(remaining.map((task) => task.id), [1, 2, 3, 6, 7, 8]);
    assert.deepEqual(tasks, before);
    assert.equal(hasChemicalPlanFromDate(remaining, 1, source, "2026-09-04"), false);
  });
}

test("existing browser data removes only old-plan days overlapped by a newer generation", () => {
  const tasks = [
    { id: 1, tankId: 1, source: "alkalinity-plan", planId: "kh-old", scheduledDate: "2026-09-01", state: "done" as const },
    { id: 2, tankId: 1, source: "alkalinity-plan", planId: "kh-old", scheduledDate: "2026-09-02", state: "done" as const },
    { id: 3, tankId: 1, source: "alkalinity-plan", planId: "kh-old", scheduledDate: "2026-09-03", state: "done" as const },
    { id: 4, tankId: 1, source: "alkalinity-plan", planId: "kh-old", scheduledDate: "2026-09-04", state: "soon" as const },
    { id: 5, tankId: 1, source: "alkalinity-plan", planId: "kh-old", scheduledDate: "2026-09-05", state: "soon" as const },
    { id: 10, tankId: 1, source: "alkalinity-plan", planId: "kh-new", scheduledDate: "2026-09-04", state: "due" as const },
    { id: 11, tankId: 1, source: "alkalinity-plan", planId: "kh-new", scheduledDate: "2026-09-05", state: "soon" as const },
    { id: 12, tankId: 1, source: "alkalinity-plan", planId: "kh-new", scheduledDate: "2026-09-06", state: "soon" as const },
    { id: 6, tankId: 2, source: "alkalinity-plan", planId: "other-tank", scheduledDate: "2026-09-04", state: "done" as const },
    { id: 7, tankId: 1, source: "manual", scheduledDate: "2026-09-04", state: "due" as const },
  ];

  assert.deepEqual(pruneSupersededChemicalPlanOverlaps(tasks).map((task) => task.id), [1, 2, 3, 10, 11, 12, 6, 7]);
  assert.equal(tasks.length, 10);
  const nativeTasks = tasks.map(task => ({ ...task, id: `native-${task.id}`, tankId: `tank-${task.tankId}` }));
  assert.deepEqual(pruneSupersededChemicalPlanOverlaps(nativeTasks), nativeTasks);
});

test("a completed task can be marked incomplete without changing other occurrences", () => {
  const tasks = [
    { id: 1, scheduledDate: "2026-09-05", state: "done" as const, handledAt: "刚刚完成" },
    { id: 2, scheduledDate: "2026-09-01", intervalDays: 2, state: "due" as const, completedDates: ["2026-09-03", "2026-09-05"] },
    { id: 3, scheduledDate: "2026-09-06", state: "done" as const },
  ];

  const reopenedOneOff = markTaskIncomplete(tasks, 1, "2026-09-05", "2026-09-05");
  assert.equal(reopenedOneOff[0].state, "due");
  assert.equal(reopenedOneOff[0].handledAt, undefined);
  const reopenedRecurring = markTaskIncomplete(tasks, 2, "2026-09-05", "2026-09-05");
  assert.deepEqual(reopenedRecurring[1].completedDates, ["2026-09-03"]);
  const reopenedFuture = markTaskIncomplete(tasks, 3, "2026-09-06", "2026-09-05");
  assert.equal(reopenedFuture[2].state, "soon");
});

test("recurring tasks started in the past default earlier occurrences to done and allow reopening one date", () => {
  const tasks = [{
    id: 1,
    scheduledDate: "2026-09-01",
    intervalDays: 2,
    state: "due" as const,
    defaultCompletedBeforeDate: "2026-09-05",
    reopenedDates: [],
  }];

  assert.equal(taskOccursOnDate(tasks[0], "2026-09-03"), true);
  assert.equal(taskStateOnDate(tasks[0], "2026-09-03", "2026-09-05"), "done");
  assert.equal(taskStateOnDate(tasks[0], "2026-09-05", "2026-09-05"), "due");
  const reopened = markTaskIncomplete(tasks, 1, "2026-09-03", "2026-09-05");
  assert.equal(taskStateOnDate(reopened[0], "2026-09-03", "2026-09-05"), "due");
  assert.deepEqual(reopened[0].reopenedDates, ["2026-09-03"]);
  assert.equal(taskStateOnDate(reopened[0], "2026-09-01", "2026-09-05"), "done");
});

test("expands a seven-day task only on matching dates", () => {
  const task = {
    scheduledDate: "2026-08-31",
    intervalDays: 7,
    state: "soon" as const,
  };

  assert.equal(taskOccursOnDate(task, "2026-08-31"), true);
  assert.equal(taskOccursOnDate(task, "2026-09-01"), false);
  assert.equal(taskOccursOnDate(task, "2026-09-07"), true);
  assert.equal(taskOccursOnDate(task, "2026-09-14"), true);
});

test("keeps one recurring rule and tracks each occurrence independently", () => {
  const task = {
    scheduledDate: "2026-08-31",
    intervalDays: 7,
    state: "soon" as const,
    completedDates: ["2026-09-07"],
    skippedDates: ["2026-09-14"],
  };

  assert.equal(taskStateOnDate(task, "2026-09-07", "2026-09-20"), "done");
  assert.equal(taskStateOnDate(task, "2026-09-14", "2026-09-20"), "skipped");
  assert.equal(taskStateOnDate(task, "2026-09-21", "2026-09-20"), "soon");

  const visibleDates = Array.from({ length: 42 }, (_, index) => {
    const date = new Date(Date.UTC(2026, 7, 31 + index));
    return date.toISOString().slice(0, 10);
  });
  assert.deepEqual(visibleDates.filter((key) => taskOccursOnDate(task, key)), [
    "2026-08-31",
    "2026-09-07",
    "2026-09-14",
    "2026-09-21",
    "2026-09-28",
    "2026-10-05",
  ]);
});

test("does not repeat finite one-off tasks such as lanthanum plan days", () => {
  const task = {
    scheduledDate: "2026-08-31",
    intervalDays: 1,
    oneOff: true,
    state: "soon" as const,
  };

  assert.equal(taskOccursOnDate(task, "2026-08-31"), true);
  assert.equal(taskOccursOnDate(task, "2026-09-01"), false);
});
