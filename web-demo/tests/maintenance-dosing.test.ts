import { test } from 'node:test';
import assert from 'node:assert/strict';
import { calculateMaintenance, type MaintenanceInput } from '../app/maintenance-dosing.ts';
const base: MaintenanceInput = { waterL: 200, po4Rise: .02, khDrop: .5, khStrength: 6, khPurity: 100, temperature: 20, po4Flow: 1.4, khFlow: 1.4, po4Minutes: 1, khMinutes: 1, po4Unit: 'ml/s', khUnit: 'ml/s' };
const near = (a: number, b: number) => assert.ok(Math.abs(a - b) < 1e-9, `${a} != ${b}`);
test('daily demand and exact reservoir recipe conserve both reagents', () => {
  const result = calculateMaintenance(base);
  near(result.po4.dailyStockMl, .4); near(result.kh.dailyStockMl, 60);
  near(result.khConcentration, 50.00416666666667);
  for (const channel of [result.po4, result.kh]) {
    near(channel.actualDays, 500 / 84);
    near(channel.stockMl / 500 * channel.dailyLiquidMl, channel.dailyStockMl);
  }
  near(result.kh.stockMl, 60 * 500 / 84);
});
test('old saved target days do not influence current formulas or validation', () => {
  for (const days of [0, 6, 100]) assert.deepEqual(calculateMaintenance({...base, days}), calculateMaintenance(base));
});
test('per-minute units and independent calibrated pumps determine reservoir duration', () => {
  const result = calculateMaintenance({...base, po4Unit: 'ml/min', po4Flow: 10, po4Minutes: 2, khFlow: 2, khMinutes: 2});
  near(result.po4.actualDays, 25); near(result.kh.actualDays, 500 / 240);
  near(result.po4.stockMl, 10);
});
test('oversized stock is infeasible, zero demand uses no stock, alternate strengths preserve effect', () => {
  assert.equal(calculateMaintenance({...base, khDrop: 2}).kh.feasible, false);
  assert.equal(calculateMaintenance({...base, po4Rise: 0, khDrop: 0}).kh.stockMl, 0);
  const dilute = calculateMaintenance({...base, khStrength: 8});
  near(dilute.kh.dailyStockMl, 80);
  assert.throws(() => calculateMaintenance({...base, khStrength: 4, temperature: 20}));
  near(calculateMaintenance({...base, khStrength: 4, temperature: 30}).kh.dailyStockMl, 40);
});
test('invalid values and low-temperature concentrated stock are rejected', () => {
  for (const key of ['waterL', 'po4Flow', 'khFlow', 'khMinutes', 'po4Minutes'] as const) {
    for (const value of [0, -1, NaN, Infinity]) assert.throws(() => calculateMaintenance({ ...base, [key]: value }));
  }
  for (const patch of [{ po4Rise: -1 }, { khDrop: NaN }, { khPurity: 101 }, { khStrength: 7 }, { temperature: 41 }, { temperature: 0, khStrength: 5 }, { waterL: Number.MAX_VALUE, khDrop: 10 }]) assert.throws(() => calculateMaintenance({ ...base, ...patch }));
});

test('custom reservoir estimates rounded days while recipe uses exact pump consumption', () => {
  for(const volume of [500,1000,750]) {
    const r=calculateMaintenance({...base,solutionMl:volume});
    for(const c of [r.po4,r.kh]) {
      near(c.actualDays,volume/84);assert.equal(c.estimatedDays,Math.round(volume/84));
      near(c.stockMl/volume*c.dailyLiquidMl,c.dailyStockMl);
    }
  }
  const perMinute=calculateMaintenance({...base,solutionMl:500,po4Unit:'ml/min',po4Flow:10,po4Minutes:2});
  assert.equal(perMinute.po4.estimatedDays,25);
  const demand=calculateMaintenance({...base,solutionMl:500,po4Rise:.04});
  assert.equal(demand.po4.estimatedDays,6);near(demand.po4.dailyStockMl,.8);
  for(const volume of [0,-1,NaN,Infinity])assert.throws(()=>calculateMaintenance({...base,solutionMl:volume}));
});
