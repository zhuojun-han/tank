import assert from "node:assert/strict";
import test from "node:test";

import {
  DAILY_DILUTION_FINAL_VOLUME_ML,
  LanthanumCalculationError,
  MAX_DAILY_PO4_DROP_MG_L,
  MIN_DAILY_PO4_DROP_MG_L,
  MIN_TARGET_PO4_MG_L,
  DEFAULT_PLAN_STOCK_FINAL_VOLUME_ML,
  STOCK_PO4_REMOVAL_MG_PER_ML,
  calculateLanthanumPlan,
  type LanthanumPlanInput,
} from "../app/lanthanum-calculator.ts";

const baseInput: LanthanumPlanInput = {
  currentPo4MgL: 0.33,
  targetPo4MgL: 0.03,
  netWaterVolumeL: 200,
  maxDailyPo4DropMgL: 0.1,
  stockFinalVolumeMl: DEFAULT_PLAN_STOCK_FINAL_VOLUME_ML,
};

function closeTo(actual: number, expected: number, tolerance = 1e-12) {
  assert.ok(
    Math.abs(actual - expected) <= tolerance,
    `expected ${actual} to be within ${tolerance} of ${expected}`,
  );
}

test("uses fixed 99.9% LaCl3 heptahydrate at a 1:1 molar ratio", () => {
  const plan = calculateLanthanumPlan(baseInput);
  const expectedPo4Moles = 60 / 1_000 / 94.971;
  const expectedPureMassG = expectedPo4Moles * 371.37;

  closeTo(plan.totalPo4Moles, expectedPo4Moles);
  closeTo(plan.stoichiometricPureSaltMassG, expectedPureMassG);
  assert.equal(plan.stoichiometricMolarRatioLaToPo4, 1);
  assert.equal(plan.efficiencyCompensationApplied, false);
  assert.equal(plan.saltFormula, "LaCl₃·7H₂O");
  assert.equal(plan.saltForm, "heptahydrate");
  assert.equal(plan.purityPercent, 99.9);
});

test("scales the stock recipe while 1 mL always removes 10 mg PO4", () => {
  const plan = calculateLanthanumPlan(baseInput);
  const expectedReagentMgPerMl =
    ((10 / 1_000 / 94.971) * 371.37 * 1_000) / 0.999;

  closeTo(plan.planStockConcentrationMgPerMl, expectedReagentMgPerMl);
  closeTo(plan.solidMassToWeighG, expectedReagentMgPerMl / 2);
  assert.equal(plan.planStockFinalVolumeMl, 500);
  assert.equal(plan.stockPo4RemovalMgPerMl, 10);

  const smaller = calculateLanthanumPlan({ ...baseInput, stockFinalVolumeMl: 250 });
  closeTo(smaller.solidMassToWeighG, plan.solidMassToWeighG / 2);
  assert.equal(smaller.planStockFinalVolumeMl, 250);
  closeTo(smaller.planStockConcentrationMgPerMl, plan.planStockConcentrationMgPerMl);
});

test("uses 2 mL stock to lower 200 L by 0.1 mg/L", () => {
  const plan = calculateLanthanumPlan({
    ...baseInput,
    currentPo4MgL: 0.28,
    targetPo4MgL: 0.03,
    maxDailyPo4DropMgL: 0.1,
  });

  assert.equal(plan.days, 3);
  plan.dailyPlan.forEach((day, index) => {
    closeTo(day.theoreticalPo4DropMgL, [0.1, 0.1, 0.05][index]);
    closeTo(day.stockToUseMl, [2, 2, 1][index]);
    assert.ok(day.theoreticalPo4DropMgL <= 0.1);
    closeTo(
      day.stockToUseMl + day.rodiToFinalVolumeMl,
      DAILY_DILUTION_FINAL_VOLUME_ML,
    );
    assert.equal(day.dilutedFinalVolumeMl, 500);
  });

  closeTo(
    plan.dailyPlan.reduce(
      (total, day) => total + day.theoreticalPo4DropMgL,
      0,
    ),
    plan.totalTheoreticalPo4DropMgL,
  );
  closeTo(plan.totalStockRequiredMl, 5);
  assert.equal(plan.stockBatchesRequired, 1);
  closeTo(
    plan.dailyPlan.reduce(
      (total, day) => total + day.solidMassInAliquotG,
      0,
    ),
    (plan.totalStockRequiredMl * plan.planStockConcentrationMgPerMl) / 1_000,
  );
  closeTo(plan.dailyPlan.at(-1)?.endingPo4MgL ?? Number.NaN, 0.03);
});

test("allows a final daily drop smaller than the configured 0.1 minimum", () => {
  const plan = calculateLanthanumPlan({
    ...baseInput,
    currentPo4MgL: 0.08,
    maxDailyPo4DropMgL: 0.1,
  });

  assert.equal(plan.days, 1);
  closeTo(plan.dailyPlan[0].theoreticalPo4DropMgL, 0.05);
  closeTo(plan.dailyPlan[0].stockToUseMl, 1);
  closeTo(plan.dailyPlan[0].rodiToFinalVolumeMl, 499);
  assert.equal(plan.dailyPlan[0].dilutedFinalVolumeMl, 500);
});

test("uses 10 mL stock for the 0.5 mg/L upper plan limit in 200 L", () => {
  const plan = calculateLanthanumPlan({
    ...baseInput,
    currentPo4MgL: 0.53,
    maxDailyPo4DropMgL: 0.5,
  });

  assert.equal(plan.days, 1);
  closeTo(plan.dailyPlan[0].theoreticalPo4DropMgL, 0.5);
  closeTo(plan.dailyPlan[0].stockToUseMl, 10);
  closeTo(plan.dailyPlan[0].rodiToFinalVolumeMl, 490);
});

test("rejects non-finite, non-positive, out-of-range and non-lowering inputs", () => {
  const invalidCases: Array<{
    input: LanthanumPlanInput;
    code: LanthanumCalculationError["code"];
  }> = [
    {
      input: { ...baseInput, currentPo4MgL: Number.NaN },
      code: "invalid-current-po4",
    },
    {
      input: { ...baseInput, targetPo4MgL: MIN_TARGET_PO4_MG_L - 0.001 },
      code: "invalid-target-po4",
    },
    {
      input: { ...baseInput, targetPo4MgL: baseInput.currentPo4MgL },
      code: "target-not-below-current",
    },
    {
      input: { ...baseInput, netWaterVolumeL: Number.POSITIVE_INFINITY },
      code: "invalid-water-volume",
    },
    {
      input: { ...baseInput, stockFinalVolumeMl: 0 },
      code: "invalid-stock-volume",
    },
    {
      input: {
        ...baseInput,
        maxDailyPo4DropMgL: MIN_DAILY_PO4_DROP_MG_L - 0.01,
      },
      code: "invalid-max-daily-drop",
    },
    {
      input: {
        ...baseInput,
        maxDailyPo4DropMgL: MAX_DAILY_PO4_DROP_MG_L + 0.01,
      },
      code: "invalid-max-daily-drop",
    },
  ];

  invalidCases.forEach(({ input, code }) => {
    assert.throws(
      () => calculateLanthanumPlan(input),
      (error: unknown) =>
        error instanceof LanthanumCalculationError && error.code === code,
    );
  });
});

test("exports the requested planner constants", () => {
  assert.equal(MIN_TARGET_PO4_MG_L, 0.03);
  assert.equal(MIN_DAILY_PO4_DROP_MG_L, 0.1);
  assert.equal(MAX_DAILY_PO4_DROP_MG_L, 0.5);
  assert.equal(STOCK_PO4_REMOVAL_MG_PER_ML, 10);
  assert.equal(DEFAULT_PLAN_STOCK_FINAL_VOLUME_ML, 500);
});
