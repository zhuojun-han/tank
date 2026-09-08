import assert from "node:assert/strict";
import test from "node:test";

import {
  calculateSaltMix,
  SalinityCalculationError,
} from "../app/salinity-calculator.ts";

test("treats initial zero as unsalted water and calculates the reference dose", () => {
  const result = calculateSaltMix({
    initialSg: 0,
    targetSg: 1.025,
    waterVolumeL: 20,
    labelReferenceSg: 1.0255,
    saltGramsPerLitreAtReference: 38.2,
  });

  assert.equal(result.effectiveInitialSg, 1);
  assert.ok(Math.abs(result.requiredSaltG - 749.0196078431372) < 1e-9);
  assert.ok(Math.abs(result.initialAdditionG - 674.1176470588235) < 1e-9);
  assert.ok(Math.abs(result.reservedAdjustmentG - 74.9019607843137) < 1e-9);
});

test("scales the estimate from an existing specific gravity", () => {
  const result = calculateSaltMix({
    initialSg: 1.02,
    targetSg: 1.025,
    waterVolumeL: 20,
    labelReferenceSg: 1.0255,
    saltGramsPerLitreAtReference: 38.2,
  });

  assert.ok(Math.abs(result.progressFraction - (0.005 / 0.0255)) < 1e-9);
  assert.ok(Math.abs(result.requiredSaltG - 149.80392156862743) < 1e-9);
});

test("rejects physical and workflow-invalid inputs", () => {
  const base = {
    initialSg: 0,
    targetSg: 1.025,
    waterVolumeL: 20,
    labelReferenceSg: 1.0255,
    saltGramsPerLitreAtReference: 38.2,
  };

  assert.throws(
    () => calculateSaltMix({ ...base, initialSg: 0.5 }),
    SalinityCalculationError,
  );
  assert.throws(
    () => calculateSaltMix({ ...base, initialSg: 1.026 }),
    /目标比重必须高于初始比重/,
  );
  assert.throws(
    () => calculateSaltMix({ ...base, waterVolumeL: 0 }),
    /水量必须大于/,
  );
});
