import assert from "node:assert/strict";
import test from "node:test";

import {
  AlkalinityCalculationError,
  DEFAULT_ALKALINITY_STOCK_FINAL_VOLUME_ML,
  DEFAULT_DAILY_DKH_CONSUMPTION,
  DEFAULT_MAX_DAILY_DKH_RISE,
  DEFAULT_SODIUM_BICARBONATE_PURITY_PERCENT,
  DEFAULT_STOCK_ML_PER_0_1_DKH_100L,
  DKH_PER_MEQ_L,
  SODIUM_BICARBONATE_MOLAR_MASS_G_PER_MOL,
  calculateAlkalinityPlan,
  sodiumBicarbonateSolubilityAt,
  type AlkalinityPlanInput,
} from "../app/alkalinity-calculator.ts";

const baseInput: AlkalinityPlanInput = {
  currentDkh: 6.5,
  targetDkh: 8,
  netWaterVolumeL: 200,
  purityPercent: 100,
  maxDailyDkhRise: 0.5,
  dailyDkhConsumption: 0.5,
  stockFinalVolumeMl: 500,
  stockMlPer0_1Dkh100L: 6,
  stockTemperatureC: 0,
};

function closeTo(actual: number, expected: number, tolerance = 1e-10) {
  assert.ok(Math.abs(actual - expected) <= tolerance, `expected ${actual} to be within ${tolerance} of ${expected}`);
}

test("uses one alkalinity equivalent per mole and a tidy six-millilitre stock", () => {
  const plan = calculateAlkalinityPlan(baseInput);

  assert.equal(plan.additiveFormula, "NaHCO₃");
  assert.equal(plan.alkalinityEquivalentsPerMole, 1);
  assert.equal(plan.dkhPerMeqL, 2.8);
  closeTo(plan.gramsPurePer100LPerDkh, 3.00025);
  closeTo(plan.stockStrengthDkhPerMlPer100L, 0.1 / 6);
  closeTo(plan.pureStockConcentrationGPerL, 50.00416666666667);
  closeTo(plan.stockSolidMassToWeighG, 25.002083333333335);
  closeTo(6 * plan.stockStrengthDkhPerMlPer100L, 0.1);
});

test("adds daily consumption to the dose while net KH rises by 0.5 per day", () => {
  const plan = calculateAlkalinityPlan(baseInput);

  assert.equal(plan.days, 3);
  assert.equal(plan.totalDkhRise, 1.5);
  assert.equal(plan.totalAssumedDkhConsumption, 1.5);
  assert.equal(plan.totalTheoreticalDoseDkh, 3);
  assert.deepEqual(plan.dailyPlan.map((day) => day.plannedNetDkhRise), [0.5, 0.5, 0.5]);
  assert.deepEqual(plan.dailyPlan.map((day) => day.theoreticalDoseDkh), [1, 1, 1]);
  assert.deepEqual(plan.dailyPlan.map((day) => day.stockToUseMl), [120, 120, 120]);
  assert.deepEqual(plan.dailyPlan.map((day) => day.expectedEndingDkh), [7, 7.5, 8]);
  assert.deepEqual(plan.dailyPlan.map((day) => day.postDoseDkh), [7.5, 8, 8.5]);
  closeTo(plan.totalStockRequiredMl, 360);
  assert.equal(plan.stockShortfallMl, 0);
  assert.equal(plan.stockBatchesRequired, 1);
});

test("keeps a smaller final net rise but still replaces that day's consumption", () => {
  const plan = calculateAlkalinityPlan({ ...baseInput, currentDkh: 7.2, purityPercent: 99 });

  assert.equal(plan.days, 2);
  closeTo(plan.dailyPlan[0].plannedNetDkhRise, 0.5);
  closeTo(plan.dailyPlan[1].plannedNetDkhRise, 0.3);
  closeTo(plan.dailyPlan[1].theoreticalDoseDkh, 0.8);
  closeTo(plan.dailyPlan[1].stockToUseMl, 96);
  closeTo(plan.dailyPlan[1].expectedEndingDkh, 8);
  closeTo(plan.stockReagentConcentrationGPerL, plan.pureStockConcentrationGPerL / 0.99);
});

test("interpolates 0-40 C solubility and rejects an over-concentrated cold stock", () => {
  closeTo(sodiumBicarbonateSolubilityAt(0), 6.4);
  closeTo(sodiumBicarbonateSolubilityAt(15), 8.15);
  closeTo(sodiumBicarbonateSolubilityAt(40), 11.3);
  const safe = calculateAlkalinityPlan(baseInput);
  assert.ok(safe.stockReagentConcentrationGPerL < safe.conservativeMaxStockConcentrationGPerL);
  assert.throws(
    () => calculateAlkalinityPlan({ ...baseInput, stockMlPer0_1Dkh100L: 4, stockTemperatureC: 0 }),
    (error: unknown) => error instanceof AlkalinityCalculationError && error.code === "stock-concentration-exceeds-solubility-margin",
  );
  assert.doesNotThrow(() => calculateAlkalinityPlan({ ...baseInput, stockMlPer0_1Dkh100L: 4, stockTemperatureC: 30 }));
});

test("reports stock shortfall and required batch count for a small container", () => {
  const plan = calculateAlkalinityPlan({ ...baseInput, stockFinalVolumeMl: 100 });

  closeTo(plan.totalStockRequiredMl, 360);
  closeTo(plan.stockShortfallMl, 260);
  assert.equal(plan.stockBatchesRequired, 4);
  closeTo(plan.stockSolidMassToWeighG, 5.000416666666667);
});

test("rejects invalid inputs", () => {
  const invalidCases: Array<{ input: AlkalinityPlanInput; code: AlkalinityCalculationError["code"] }> = [
    { input: { ...baseInput, currentDkh: Number.NaN }, code: "invalid-current-dkh" },
    { input: { ...baseInput, targetDkh: 0 }, code: "invalid-target-dkh" },
    { input: { ...baseInput, targetDkh: baseInput.currentDkh }, code: "target-not-above-current" },
    { input: { ...baseInput, netWaterVolumeL: Number.POSITIVE_INFINITY }, code: "invalid-water-volume" },
    { input: { ...baseInput, purityPercent: 100.1 }, code: "invalid-purity" },
    { input: { ...baseInput, maxDailyDkhRise: 0 }, code: "invalid-max-daily-rise" },
    { input: { ...baseInput, dailyDkhConsumption: -0.1 }, code: "invalid-daily-consumption" },
    { input: { ...baseInput, stockFinalVolumeMl: 0 }, code: "invalid-stock-volume" },
    { input: { ...baseInput, stockTemperatureC: 41 }, code: "invalid-stock-temperature" },
    { input: { ...baseInput, stockMlPer0_1Dkh100L: 7 }, code: "invalid-stock-strength" },
  ];
  invalidCases.forEach(({ input, code }) => assert.throws(
    () => calculateAlkalinityPlan(input),
    (error: unknown) => error instanceof AlkalinityCalculationError && error.code === code,
  ));
});

test("exports planner defaults", () => {
  assert.equal(DKH_PER_MEQ_L, 2.8);
  assert.equal(SODIUM_BICARBONATE_MOLAR_MASS_G_PER_MOL, 84.007);
  assert.equal(DEFAULT_MAX_DAILY_DKH_RISE, 0.5);
  assert.equal(DEFAULT_DAILY_DKH_CONSUMPTION, 0.5);
  assert.equal(DEFAULT_SODIUM_BICARBONATE_PURITY_PERCENT, 100);
  assert.equal(DEFAULT_ALKALINITY_STOCK_FINAL_VOLUME_ML, 500);
  assert.equal(DEFAULT_STOCK_ML_PER_0_1_DKH_100L, 6);
});
