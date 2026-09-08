import { test } from 'node:test';
import assert from 'node:assert/strict';
import { addMaintenanceCycle, currentMaintenanceCycle, cycleRemainingMl, maintenanceTasksOnDate, prepareMaintenanceCycle } from '../app/maintenance-cycle.ts';
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

test('overdue refill remains pending each day until a replacement; no items before start', () => {
  const c = prepare();
  assert.deepEqual(maintenanceTasksOnDate([c], 1, '2026-09-07', start), []);
  for (const date of ['2026-09-12', '2026-09-15', '2026-10-01']) {
    assert.equal(maintenanceTasksOnDate([c], 1, date, date)[0].state, 'due');
  }
  near(cycleRemainingMl(c, '2026-09-10'), 300);
  near(cycleRemainingMl(c, '2026-10-01'), 0);
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

test('zero demand, invalid dates, and unrepresentable refill dates cannot be saved', () => {
  assert.throws(() => prepareMaintenanceCycle({ ...input, po4Rise: 0 }, 'po4', 1, start));
  assert.throws(() => prepareMaintenanceCycle(input, 'po4', 1, '2026-02-30'));
  assert.throws(() => prepareMaintenanceCycle({ ...input, po4Rise: 1e-20, po4Flow: 1e-15 }, 'po4', 1, start), /日期超出/);
});
