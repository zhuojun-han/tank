import { test } from 'node:test';
import assert from 'node:assert/strict';
import { addMaintenanceCycle, currentMaintenanceCycle, cycleRemainingDays, cycleRemainingMl, maintenanceTasksOnDate, overdueMaintenanceTasks, prepareMaintenanceCycle } from '../app/maintenance-cycle.ts';
import { pendingTasksOnDate, completedTasksOnDate } from '../app/task-calendar.ts';
import type { MaintenanceInput } from '../app/maintenance-dosing.ts';

const input: MaintenanceInput = { solutionMl: 500, waterL: 200, po4Rise: 0.05, khDrop: 0.5, days: 6, khStrength: 6, khPurity: 100, temperature: 20, po4Flow: 100, khFlow: 100, po4Minutes: 1, khMinutes: 1, po4Unit: 'ml/min', khUnit: 'ml/min' };
const start = '2026-09-08';
const near = (a: number, b: number) => assert.ok(Math.abs(a - b) < 1e-8, `${a} != ${b}`);
const prepare = (chemical: 'po4' | 'kh' = 'po4') => prepareMaintenanceCycle(input, chemical, 1, start, undefined, 0, chemical === 'po4' ? 100 : 101);

test('five-day reservoir is completed on days 1–4 and needs refill on day 5', () => {
  const cycle = prepare();
  assert.equal(cycle.refillDate, '2026-09-12');
  for (const day of ['2026-09-08', '2026-09-09', '2026-09-10', '2026-09-11']) {
    const tasks = maintenanceTasksOnDate([cycle], 1, day, start);
    assert.equal(pendingTasksOnDate(tasks, day).length, 0);
    assert.equal(completedTasksOnDate(tasks, day).length, 1);
  }
  assert.match(maintenanceTasksOnDate([cycle], 1, '2026-09-10', start)[0].cycle, /3 天/);
  assert.equal(maintenanceTasksOnDate([cycle], 1, '2026-09-12', start)[0].state, 'soon');
  const due = maintenanceTasksOnDate([cycle], 1, '2026-09-12', '2026-09-12');
  assert.equal(pendingTasksOnDate(due, '2026-09-12').length, 1);
  assert.equal(due[0].state, 'due');
});

test('fractional duration uses final run day, not displayed rounded days; one-day and month/year boundaries', () => {
  assert.equal(prepareMaintenanceCycle({ ...input, solutionMl: 510 }, 'po4', 1, start).refillDate, '2026-09-13');
  assert.equal(prepareMaintenanceCycle({ ...input, solutionMl: 50 }, 'po4', 1, start).refillDate, start);
  assert.equal(prepareMaintenanceCycle(input, 'po4', 1, '2026-12-29').refillDate, '2027-01-02');
  assert.equal(prepareMaintenanceCycle(input, 'po4', 1, '2028-02-27').refillDate, '2028-03-02');
});

test('calendar stops at the last day while a separate overdue reminder remains pending today', () => {
  const c = prepare();
  assert.deepEqual(maintenanceTasksOnDate([c], 1, '2026-09-07', start), []);
  assert.equal(maintenanceTasksOnDate([c], 1, c.refillDate, c.refillDate)[0].state, 'due');
  assert.deepEqual(overdueMaintenanceTasks([c], 1, c.refillDate), []);
  for (const date of ['2026-09-13', '2026-09-15', '2026-10-01']) {
    assert.deepEqual(maintenanceTasksOnDate([c], 1, date, start), []);
    assert.deepEqual(maintenanceTasksOnDate([c], 1, date, date), []);
    const overdue = overdueMaintenanceTasks([c], 1, date);
    assert.equal(overdue.length, 1);
    assert.equal(overdue[0].state, 'due');
    assert.equal(overdue[0].scheduledDate, date);
    assert.equal(overdue[0].maintenanceCycleId, c.id);
    assert.equal(pendingTasksOnDate(overdue, date).length, 1);
    assert.match(overdue[0].cycle, /预计还可用 0 天/);
    assert.match(overdue[0].detail, /剩余 0 mL.*逾期/);
  }
  near(cycleRemainingMl(c, '2026-09-10'), 300);
  near(cycleRemainingMl(c, '2026-10-01'), 0);
});

test('500 mL at 84 mL per day shows six dates with decreasing days and volume for both chemicals', () => {
  for (const chemical of ['po4', 'kh'] as const) {
    const c = prepareMaintenanceCycle({ ...input, po4Flow: 84, khFlow: 84 }, chemical, 1, start, undefined, 0, 301);
    const snapshot = structuredClone(c);
    assert.equal(c.refillDate, '2026-09-13');
    near(cycleRemainingDays(c, start), 500 / 84);
    near(cycleRemainingDays(c, '2026-09-09'), 500 / 84 - 1);
    near(cycleRemainingDays(c, '2026-09-07'), 500 / 84);
    const dates = ['2026-09-08', '2026-09-09', '2026-09-10', '2026-09-11', '2026-09-12', '2026-09-13'];
    const volumes = [500, 416, 332, 248, 164, 80];
    const dayLabels = ['5.95', '4.95', '3.95', '2.95', '1.95', '0.952'];
    for (const [index, date] of dates.entries()) {
      const tasks = maintenanceTasksOnDate([c], 1, date, date);
      assert.equal(tasks.length, 1);
      near(cycleRemainingDays(c, date), 500 / 84 - index);
      near(cycleRemainingMl(c, date), volumes[index]);
      assert.ok(tasks[0].cycle.includes(`（${dayLabels[index]} 天）`));
      assert.ok(tasks[0].detail.includes(`剩余 ${volumes[index]} mL`));
      assert.equal(tasks[0].state, index < 5 ? 'done' : 'due');
    }
    const futureRefill = maintenanceTasksOnDate([c], 1, c.refillDate, start)[0];
    assert.equal(futureRefill.state, 'soon');
    assert.match(futureRefill.cycle, /0\.952 天/);
    assert.match(futureRefill.detail, /80 mL.*2026-09-13 需配液/);
    assert.deepEqual(maintenanceTasksOnDate([c], 1, '2026-09-14', start), []);
    assert.deepEqual(maintenanceTasksOnDate([c], 1, '2027-01-01', '2027-01-02'), []);
    assert.equal(cycleRemainingDays(c, '2026-09-14'), 0);
    assert.equal(cycleRemainingMl(c, '2026-09-14'), 0);
    assert.deepEqual(c, snapshot);
  }
});

test('sub-day and exact-day durations have finite calendar windows and retain final-day volume', () => {
  for (const [volume, count] of [[50, 1], [100, 1], [500, 5]]) {
    const c = prepareMaintenanceCycle({ ...input, solutionMl: volume }, 'po4', 1, start);
    const dates = Array.from({ length: 7 }, (_, index) => `2026-09-${String(8 + index).padStart(2, '0')}`);
    assert.equal(dates.flatMap(date => maintenanceTasksOnDate([c], 1, date, start)).length, count);
    const last = maintenanceTasksOnDate([c], 1, c.refillDate, c.refillDate)[0];
    assert.equal(last.state, 'due');
    near(cycleRemainingDays(c, c.refillDate), volume < 100 ? 0.5 : 1);
    near(cycleRemainingMl(c, c.refillDate), volume < 100 ? 50 : 100);
    assert.match(last.detail, /需配液/);
  }
});

test('remaining days count calendar dates across month, year, leap day and daylight-saving transitions', () => {
  for (const [first, second, last] of [
    ['2026-09-29', '2026-09-30', '2026-10-03'],
    ['2026-12-29', '2026-12-30', '2027-01-02'],
    ['2028-02-27', '2028-02-28', '2028-03-02'],
    ['2026-03-07', '2026-03-08', '2026-03-11'],
  ]) {
    const c = prepareMaintenanceCycle(input, 'po4', 1, first);
    assert.equal(c.refillDate, last);
    near(cycleRemainingDays(c, second), 4);
    near(cycleRemainingDays(c, last), 1);
    assert.equal(maintenanceTasksOnDate([c], 1, last, last).length, 1);
  }
});

test('PO4 residual subtracts its existing solute and liquid volume', () => {
  const old = prepare();
  const next = prepareMaintenanceCycle(input, 'po4', 1, '2026-09-10', old, 300, 200);
  near(next.addedStockMl, 2);
  near(next.addedWaterMl, 198);
  near(300 * old.effectPerMl + next.addedStockMl * 10, next.effectPerMl * 500);
});

test('KH carryover stays correct when mother-stock strength and purity change', () => {
  const old = prepare('kh');
  const next = prepareMaintenanceCycle({ ...input, khStrength: 8, khPurity: 95 }, 'kh', 1, '2026-09-10', old, 300, 200);
  near(next.addedStockMl, 160);
  near(next.addedWaterMl, 40);
  near(old.effectPerMl * 300 + next.addedStockMl * 0.1 / 8, 5);
});

test('empty reservoir makes a full new recipe; edited actual residual overrides forecast', () => {
  const old = prepare();
  near(prepareMaintenanceCycle(input, 'po4', 1, '2026-09-10', old, 0).addedStockMl, 5);
  near(prepareMaintenanceCycle(input, 'po4', 1, '2026-09-10', old, 200).addedStockMl, 3);
});

test('too much residual solute or liquid cannot produce negative stock/water recipes', () => {
  const old = prepare('kh');
  assert.throws(() => prepareMaintenanceCycle({ ...input, khDrop: 0.1 }, 'kh', 1, start, old, 300), /药量已超过/);
  const weak = prepareMaintenanceCycle({ ...input, khDrop: 0.05 }, 'kh', 1, start);
  assert.throws(() => prepareMaintenanceCycle(input, 'kh', 1, start, weak, 400), /超过容量/);
  for (const amount of [-1, NaN, Infinity, 501]) assert.throws(() => prepareMaintenanceCycle(input, 'po4', 1, start, prepare(), amount));
});

test('cross-tank, cross-chemical, closed, missing, stale, and future residuals are rejected', () => {
  const old = prepare();
  assert.throws(() => prepareMaintenanceCycle(input, 'po4', 2, start, old, 100));
  assert.throws(() => prepareMaintenanceCycle(input, 'kh', 1, start, old, 100));
  assert.throws(() => prepareMaintenanceCycle(input, 'po4', 1, start, { ...old, closedOnDate: start }, 100));
  assert.throws(() => prepareMaintenanceCycle(input, 'po4', 1, start, undefined, 100));
  assert.throws(() => prepareMaintenanceCycle(input, 'po4', 1, '2026-09-07', old, 100));
  assert.throws(() => addMaintenanceCycle([old], prepare()));
});

test('early replacement preserves history, cancels old future refill, and isolates tank/chemical', () => {
  const old = prepare(); const kh = prepare('kh');
  const tank2 = { ...old, id: 102, tankId: 2 };
  const original = [old, kh, tank2];
  const next = prepareMaintenanceCycle(input, 'po4', 1, '2026-09-10', old, 300, 200);
  const cycles = addMaintenanceCycle(original, next);
  assert.equal(old.closedOnDate, undefined);
  assert.equal(cycles[0].closedOnDate, '2026-09-10');
  assert.equal(currentMaintenanceCycle(cycles, 1, 'po4')?.id, 200);
  assert.equal(currentMaintenanceCycle(cycles, 1, 'kh')?.id, 101);
  assert.equal(currentMaintenanceCycle(cycles, 2, 'po4')?.id, 102);
  assert.equal(maintenanceTasksOnDate(cycles, 1, '2026-09-09', start).find(t => t.maintenanceCycleId === 100)?.state, 'done');
  assert.ok(!maintenanceTasksOnDate(cycles, 1, '2026-09-12', '2026-09-12').some(t => t.maintenanceCycleId === 100));
  assert.equal(maintenanceTasksOnDate(cycles, 1, '2026-09-12', '2026-09-12').find(t => t.maintenanceCycleId === 200)?.state, 'done');
  assert.deepEqual(maintenanceTasksOnDate(JSON.parse(JSON.stringify(cycles)), 1, '2026-09-12', '2026-09-12'), maintenanceTasksOnDate(cycles, 1, '2026-09-12', '2026-09-12'));
});

test('late replacement resolves the original final-day history and removes only its overdue reminder', () => {
  const old = prepare();
  const kh = prepare('kh');
  const tank2 = { ...old, id: 102, tankId: 2 };
  const original = [old, kh, tank2];
  const snapshot = structuredClone(original);
  const today = '2026-09-16';
  assert.equal(overdueMaintenanceTasks(original, 1, today).length, 2);
  assert.equal(overdueMaintenanceTasks(original, 2, today).length, 1);
  const next = prepareMaintenanceCycle(input, 'po4', 1, today, old, 0, 200);
  const cycles = addMaintenanceCycle(original, next);
  const reminders = overdueMaintenanceTasks(cycles, 1, today);
  assert.equal(reminders.length, 1);
  assert.equal(reminders[0].maintenanceCycleId, kh.id);
  assert.equal(overdueMaintenanceTasks(cycles, 2, today)[0].maintenanceCycleId, tank2.id);
  const previousLastDay = maintenanceTasksOnDate(cycles, 1, old.refillDate, today).find(task => task.maintenanceCycleId === old.id)!;
  assert.equal(previousLastDay.state, 'done');
  assert.match(previousLastDay.detail, /2026-09-16 续配/);
  for (const date of ['2026-09-13', '2026-09-15', today]) {
    assert.ok(!maintenanceTasksOnDate(cycles, 1, date, today).some(task => task.maintenanceCycleId === old.id));
  }
  assert.deepEqual(original, snapshot);
  assert.deepEqual(overdueMaintenanceTasks(JSON.parse(JSON.stringify(cycles)), 1, today), reminders);
});

test('zero demand, invalid dates, and unrepresentable refill dates cannot be saved', () => {
  assert.throws(() => prepareMaintenanceCycle({ ...input, po4Rise: 0 }, 'po4', 1, start));
  assert.throws(() => prepareMaintenanceCycle(input, 'po4', 1, '2026-02-30'));
  assert.throws(() => prepareMaintenanceCycle({ ...input, po4Rise: 1e-20, po4Flow: 1e-15 }, 'po4', 1, start), /日期超出/);
});
