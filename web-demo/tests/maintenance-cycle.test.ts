import { test } from 'node:test';
import assert from 'node:assert/strict';
import { addMaintenanceCycle, currentMaintenanceCycle, cycleDailyLiquidMl, cycleNeedsRefill, cycleRemainingDays, cycleRemainingMl, cycleResidualMl, delayMaintenanceCycle, maintenanceReminderDate, maintenanceTasksOnDate, overdueMaintenanceTasks, prepareMaintenanceCycle } from '../app/maintenance-cycle.ts';
import { pendingTasksOnDate, completedTasksOnDate } from '../app/task-calendar.ts';
import type { MaintenanceInput } from '../app/maintenance-dosing.ts';
import { calculateAlkalinityPlan } from '../app/alkalinity-calculator.ts';
import { calculateLanthanumPlan } from '../app/lanthanum-calculator.ts';
import { theoryDosingRecipe } from '../app/theory-dosing.ts';

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
  const native = prepareMaintenanceCycle(input, 'po4', '9007199254740993', start, undefined, 0, 'fbc9e91d-63e2-47f1-9c20-af429ea0a631');
  const nativeDue = maintenanceTasksOnDate(JSON.parse(JSON.stringify([native])), native.tankId, native.refillDate, native.refillDate)[0];
  assert.equal(nativeDue.id, `maintenance:${native.id}`);
  assert.equal(nativeDue.maintenanceCycleId, native.id);
  assert.equal(nativeDue.tankId, native.tankId);
  assert.equal(delayMaintenanceCycle([native], native.id, 2, native.refillDate)[0].refillDeferredUntil, '2026-09-14');
});

test('fractional duration uses final run day, not displayed rounded days; one-day and month/year boundaries', () => {
  assert.equal(prepareMaintenanceCycle({ ...input, solutionMl: 510 }, 'po4', 1, start).refillDate, '2026-09-13');
  assert.equal(prepareMaintenanceCycle({ ...input, solutionMl: 50 }, 'po4', 1, start).refillDate, start);
  assert.equal(prepareMaintenanceCycle(input, 'po4', 1, '2026-12-29').refillDate, '2027-01-02');
  assert.equal(prepareMaintenanceCycle(input, 'po4', 1, '2028-02-27').refillDate, '2028-03-02');
});

test('one unresolved refill rolls to today without duplicating old or future reminders', () => {
  const c = prepare();
  assert.deepEqual(maintenanceTasksOnDate([c], 1, '2026-09-07', start), []);
  assert.equal(maintenanceTasksOnDate([c], 1, c.refillDate, c.refillDate)[0].state, 'due');
  assert.deepEqual(overdueMaintenanceTasks([c], 1, c.refillDate), []);
  for (const date of ['2026-09-13', '2026-09-15', '2026-10-01']) {
    assert.deepEqual(maintenanceTasksOnDate([c], 1, date, start), []);
    assert.equal(maintenanceTasksOnDate([c], 1, date, date).length, 1);
    assert.deepEqual(maintenanceTasksOnDate([c], 1, c.refillDate, date), []);
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

test('custom delay changes only the reminder, survives reload, and new recipe cancels it in its own scope', () => {
  for (const chemical of ['po4', 'kh'] as const) {
    const old = prepare(chemical);
    const other = prepare(chemical === 'po4' ? 'kh' : 'po4');
    const otherTank = { ...old, id: 900, tankId: 2 };
    const today = '2026-09-13';
    const original = [old, other, otherTank];
    const snapshot = structuredClone(original);
    const delayed = delayMaintenanceCycle(original, old.id, 2, today);
    const selected = delayed.find(c => c.id === old.id)!;
    assert.equal(selected.refillDate, '2026-09-12');
    assert.equal(maintenanceReminderDate(selected, today), '2026-09-15');
    assert.equal(cycleRemainingDays(selected, today), 0);
    assert.equal(cycleRemainingMl(selected, today), 0);
    assert.equal(maintenanceTasksOnDate(delayed, 1, today, today).length, 1);
    assert.equal(maintenanceTasksOnDate(delayed, 1, '2026-09-15', today)[0].maintenanceCycleId, old.id);
    assert.equal(maintenanceTasksOnDate(delayed, 1, '2026-09-16', '2026-09-16').length, 2);
    const next = prepareMaintenanceCycle({ ...input, po4Rise: 0.06, khDrop: 0.6 }, chemical, 1, '2026-09-12', selected, 0, 1000);
    const renewed = addMaintenanceCycle(JSON.parse(JSON.stringify(delayed)), next);
    assert.equal(renewed.find(c => c.id === old.id)?.closedOnDate, '2026-09-12');
    assert.ok(!maintenanceTasksOnDate(renewed, 1, '2026-09-15', today).some(t => t.maintenanceCycleId === old.id));
    assert.deepEqual(renewed.find(c => c.id === other.id), JSON.parse(JSON.stringify(other)));
    assert.deepEqual(renewed.find(c => c.id === otherTank.id), JSON.parse(JSON.stringify(otherTank)));
    assert.equal(next.refillDeferredUntil, undefined);
    assert.deepEqual(original, snapshot);
    for (const days of [0, -1, 1.5, NaN, Infinity, Number.MAX_SAFE_INTEGER]) assert.throws(() => delayMaintenanceCycle(original, old.id, days, today));
    assert.throws(() => delayMaintenanceCycle(renewed, old.id, 1, today), /周期已变化/);
  }
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

const po4Theory = () => theoryDosingRecipe(calculateLanthanumPlan({
  currentPo4MgL: 0.65, targetPo4MgL: 0.1, netWaterVolumeL: 100,
  maxDailyPo4DropMgL: 0.2, stockFinalVolumeMl: 500,
}), { solutionMl: 500, flow: 100, minutes: 1, unit: 'ml/min', startDate: start, planId: 'po4-plan' });

test('finite PO4 and KH plans preserve total demand, shorten only the last run, and freeze remaining liquid after ending', () => {
  const po4 = po4Theory();
  const kh = theoryDosingRecipe(calculateAlkalinityPlan({
    currentDkh: 7, targetDkh: 8.2, netWaterVolumeL: 100, maxDailyDkhRise: 0.5,
    dailyDkhConsumption: 0.3, purityPercent: 100, stockFinalVolumeMl: 500,
    stockMlPer0_1Dkh100L: 6, stockTemperatureC: 20,
  }), { solutionMl: 500, flow: 100 / 60, minutes: 1, unit: 'ml/s', startDate: start, planId: 'kh-plan' });
  near(kh.input.khDrop, 0.8);
  near(kh.theory.lastDayRatio, 0.5 / 0.8); // Last net rise plus the full daily consumption.
  for (const [recipe, totalEffect] of [[po4, 55], [kh, 2.1]] as const) {
    const cycle = prepareMaintenanceCycle(recipe.input, recipe.chemical, 1, start, undefined, 0, recipe.theory.planId, recipe.theory);
    const finalDate = '2026-09-10';
    assert.equal(cycle.theory!.endDate, finalDate);
    near(cycleDailyLiquidMl(cycle, finalDate), 100 * recipe.theory.lastDayRatio);
    const consumed = 200 + cycleDailyLiquidMl(cycle, finalDate);
    near(consumed * cycle.effectPerMl, totalEffect);
    near(cycleRemainingMl(cycle, finalDate), 300);
    near(cycleRemainingMl(cycle, '2026-09-11'), 500 - consumed);
    near(cycleRemainingMl(cycle, '2027-01-01'), 500 - consumed);
    near(cycleRemainingDays(cycle, '2027-01-01'), (500 - consumed) / 100);
    assert.equal(cycleDailyLiquidMl(cycle, '2026-09-11'), 0);
    assert.equal(cycleNeedsRefill(cycle), false);
    for (const date of [start, '2026-09-09', finalDate]) {
      const tasks = maintenanceTasksOnDate([cycle], 1, date, date);
      assert.equal(tasks.length, 1);
      assert.equal(tasks[0].state, 'done');
      assert.match(tasks[0].title, /理论计划/);
      assert.doesNotMatch(tasks[0].title, /添加滴定液/);
    }
    assert.match(maintenanceTasksOnDate([cycle], 1, finalDate, finalDate)[0].detail, /运行 .* min 后停止/);
    assert.deepEqual(maintenanceTasksOnDate([cycle], 1, '2026-09-11', '2026-09-11'), []);
    assert.deepEqual(cycle.input, recipe.input);
    assert.deepEqual(JSON.parse(JSON.stringify(cycle)).theory, recipe.theory);
    recipe.input.solutionMl = 999;
    recipe.theory.target = 999;
    assert.equal(cycle.solutionMl, 500);
    assert.notEqual(cycle.theory!.target, 999);
  }
});

test('theory refills only when the remaining plan needs more than one bottle; postponement ends with the plan', () => {
  const recipe = po4Theory();
  for (const volume of [500, 275, 275 - 1e-9]) {
    const cycle = prepareMaintenanceCycle({ ...recipe.input, solutionMl: volume }, 'po4', 1, start, undefined, 0, 700, recipe.theory);
    assert.equal(cycleNeedsRefill(cycle), false);
    assert.equal(maintenanceTasksOnDate([cycle], 1, '2026-09-10', '2026-09-10')[0].state, 'done');
  }
  const short = prepareMaintenanceCycle({ ...recipe.input, solutionMl: 200 }, 'po4', 1, start, undefined, 0, 700, recipe.theory);
  assert.equal(cycleNeedsRefill(short), true);
  assert.equal(short.refillDate, '2026-09-09');
  assert.equal(maintenanceTasksOnDate([short], 1, short.refillDate, short.refillDate)[0].state, 'due');
  const delayed = delayMaintenanceCycle([short], short.id, 99, short.refillDate)[0];
  assert.equal(delayed.refillDeferredUntil, recipe.theory.endDate);
  assert.equal(cycleRemainingMl(delayed, recipe.theory.endDate), 0);
  assert.equal(maintenanceTasksOnDate([delayed], 1, recipe.theory.endDate, recipe.theory.endDate)[0].state, 'due');
  assert.throws(() => delayMaintenanceCycle([delayed], short.id, 1, recipe.theory.endDate), /无需继续补液/);
  assert.deepEqual(overdueMaintenanceTasks([delayed], 1, '2026-09-11'), []);
  assert.equal(maintenanceTasksOnDate([delayed], 1, recipe.theory.endDate, '2026-09-11')[0].state, 'done');
});

test('theory renewal retains solute and original deadline while replacing only its tank and chemical', () => {
  const recipe = po4Theory();
  const old = prepareMaintenanceCycle(recipe.input, 'po4', 1, start, undefined, 0, 700, recipe.theory);
  const otherTank = { ...old, id: 701, tankId: 2 };
  const otherChemical = prepare('kh');
  const next = prepareMaintenanceCycle(recipe.input, 'po4', 1, '2026-09-10', old, 300, 702, recipe.theory);
  near(next.addedStockMl, 4);
  near(next.addedWaterMl, 196);
  const cycles = addMaintenanceCycle([old, otherTank, otherChemical], next);
  assert.equal(cycles[0].closedOnDate, '2026-09-10');
  near(cycleRemainingMl(cycles[0], '2027-01-01'), 300);
  assert.equal(next.theory!.planStartDate, start);
  assert.equal(next.theory!.endDate, '2026-09-10');
  assert.equal(currentMaintenanceCycle(cycles, 1, 'po4')!.id, next.id);
  assert.deepEqual(currentMaintenanceCycle(cycles, 2, 'po4'), otherTank);
  assert.deepEqual(currentMaintenanceCycle(cycles, 1, 'kh'), otherChemical);
  assert.equal(cycleNeedsRefill(next), false);
  assert.equal(maintenanceTasksOnDate(cycles, 1, '2026-09-10', '2026-09-10').filter(t => t.maintenanceCycleId === old.id).length, 0);
  assert.throws(() => prepareMaintenanceCycle(recipe.input, 'po4', 1, '2026-09-11', next, 0, 703, recipe.theory), /已结束/);
  assert.throws(() => prepareMaintenanceCycle(recipe.input, 'kh', 1, start, undefined, 0, 703, recipe.theory), /不匹配/);
  const stableReplacement = prepareMaintenanceCycle(input, 'po4', 1, '2026-09-11', next, 0, 704);
  assert.equal(currentMaintenanceCycle(addMaintenanceCycle(cycles, stableReplacement), 1, 'po4')!.theory, undefined);
});

test('refill after dosing subtracts old daily use once and respects the final partial day', () => {
  for (const chemical of ['po4', 'kh'] as const) {
    const cycle = prepare(chemical);
    near(cycleResidualMl(cycle, '2026-09-09'), 400);
    near(cycleResidualMl(cycle, '2026-09-09', true), 300);
    near(cycleResidualMl(cycle, '2026-09-09', true), 300);
    near(cycleResidualMl(cycle, '2026-09-13', true), 0);
    const partial = { ...cycle, theory: { planId: 'partial', source: 'alkalinity-plan' as const, target: 8, planStartDate: start, endDate: '2026-09-09', lastDayRatio: 0.25 } };
    near(cycleResidualMl(partial, '2026-09-09', true), 375);
    near(cycleResidualMl(partial, '2026-09-10', true), 375);
  }
});
