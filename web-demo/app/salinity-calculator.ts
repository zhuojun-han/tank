export const FRESHWATER_SG = 1.0;
export const DEFAULT_TARGET_SG = 1.025;
export const DEFAULT_LABEL_REFERENCE_SG = 1.0255;
export const DEFAULT_SALT_GRAMS_PER_LITRE_AT_REFERENCE = 38.2;

export type SalinityCalculationInput = {
  initialSg: number;
  targetSg: number;
  waterVolumeL: number;
  labelReferenceSg: number;
  saltGramsPerLitreAtReference: number;
};

export type SalinityCalculationResult = SalinityCalculationInput & {
  effectiveInitialSg: number;
  requiredSaltG: number;
  initialAdditionG: number;
  reservedAdjustmentG: number;
  progressFraction: number;
};

export class SalinityCalculationError extends Error {}

export function calculateSaltMix({
  initialSg,
  targetSg,
  waterVolumeL,
  labelReferenceSg,
  saltGramsPerLitreAtReference,
}: SalinityCalculationInput): SalinityCalculationResult {
  const values = [initialSg, targetSg, waterVolumeL, labelReferenceSg, saltGramsPerLitreAtReference];
  if (values.some((value) => !Number.isFinite(value))) {
    throw new SalinityCalculationError("请填写有效数字。");
  }

  if (initialSg !== 0 && (initialSg < FRESHWATER_SG || initialSg > 1.04)) {
    throw new SalinityCalculationError("初始比重请填写 0（无盐水），或 1.000–1.040。");
  }
  if (targetSg <= FRESHWATER_SG || targetSg > 1.04) {
    throw new SalinityCalculationError("目标比重请填写大于 1.000 且不高于 1.040 的数值。");
  }
  if (waterVolumeL <= 0) {
    throw new SalinityCalculationError("水量必须大于 0 L。");
  }
  if (labelReferenceSg <= FRESHWATER_SG || labelReferenceSg > 1.04) {
    throw new SalinityCalculationError("包装基准比重请填写大于 1.000 且不高于 1.040 的数值。");
  }
  if (saltGramsPerLitreAtReference <= 0 || saltGramsPerLitreAtReference > 100) {
    throw new SalinityCalculationError("包装标注配盐量请填写大于 0 且不高于 100 g/L 的数值。");
  }

  const effectiveInitialSg = initialSg === 0 ? FRESHWATER_SG : initialSg;
  if (targetSg <= effectiveInitialSg) {
    throw new SalinityCalculationError("目标比重必须高于初始比重；降低盐度需要另行计算换水量。");
  }

  const progressFraction =
    (targetSg - effectiveInitialSg) / (labelReferenceSg - FRESHWATER_SG);
  const requiredSaltG =
    waterVolumeL * saltGramsPerLitreAtReference * progressFraction;
  const initialAdditionG = requiredSaltG * 0.9;

  return {
    initialSg,
    targetSg,
    waterVolumeL,
    labelReferenceSg,
    saltGramsPerLitreAtReference,
    effectiveInitialSg,
    requiredSaltG,
    initialAdditionG,
    reservedAdjustmentG: requiredSaltG - initialAdditionG,
    progressFraction,
  };
}
