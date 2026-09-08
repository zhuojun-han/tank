export const PO4_MOLAR_MASS_G_PER_MOL = 94.971;

export const DEFAULT_PLAN_STOCK_FINAL_VOLUME_ML = 500;

export const DAILY_DILUTION_FINAL_VOLUME_ML = 500;

export const MIN_TARGET_PO4_MG_L = 0.03;

export const MIN_DAILY_PO4_DROP_MG_L = 0.1;

export const MAX_DAILY_PO4_DROP_MG_L = 0.5;

/** One millilitre of stock is defined to remove 0.1 mg/L PO4 from 100 L. */
export const STOCK_PO4_REMOVAL_MG_PER_ML = 10;

/** Prevent pathological inputs from allocating an unbounded daily array. */
export const MAX_PLAN_DAYS = 3_650;

export const LANTHANUM_CHLORIDE_HEPTAHYDRATE = {
  formula: "LaCl₃·7H₂O",
  label: "七水合氯化镧（LaCl₃·7H₂O）",
  molarMassGPerMol: 371.37,
  purityPercent: 99.9,
} as const;

export type LanthanumCalculationErrorCode =
  | "invalid-current-po4"
  | "invalid-target-po4"
  | "target-not-below-current"
  | "invalid-water-volume"
  | "invalid-stock-volume"
  | "invalid-max-daily-drop"
  | "daily-dose-exceeds-dilution"
  | "plan-too-long";

export class LanthanumCalculationError extends Error {
  readonly code: LanthanumCalculationErrorCode;

  constructor(code: LanthanumCalculationErrorCode, message: string) {
    super(message);
    this.name = "LanthanumCalculationError";
    this.code = code;
  }
}

export type LanthanumPlanInput = {
  /** Latest confirmed PO4 result, expressed as mg/L of PO4 (not mg/L of P). */
  currentPo4MgL: number;
  /** User-selected target, expressed as mg/L of PO4. */
  targetPo4MgL: number;
  /** Actual net system water volume after displacement, in litres. */
  netWaterVolumeL: number;
  /** Maximum theoretical PO4 reduction per day explicitly accepted by the user. */
  maxDailyPo4DropMgL: number;
  /** User-selected final volume of one stock batch. */
  stockFinalVolumeMl: number;
};

export type LanthanumPlanDay = {
  day: number;
  startingPo4MgL: number;
  theoreticalPo4DropMgL: number;
  endingPo4MgL: number;
  theoreticalPo4MassMg: number;
  stockToUseMl: number;
  rodiToFinalVolumeMl: number;
  dilutedFinalVolumeMl: number;
  solidMassInAliquotG: number;
};

export type LanthanumPlan = {
  modelVersion: "lacl3-heptahydrate-variable-volume-v4";
  measurementBasis: "PO4";
  stoichiometricMolarRatioLaToPo4: 1;
  efficiencyCompensationApplied: false;
  saltForm: "heptahydrate";
  saltFormula: string;
  saltMolarMassGPerMol: number;
  purityPercent: number;
  currentPo4MgL: number;
  targetPo4MgL: number;
  totalTheoreticalPo4DropMgL: number;
  netWaterVolumeL: number;
  totalTheoreticalPo4MassMg: number;
  totalPo4Moles: number;
  stoichiometricPureSaltMassG: number;
  solidMassToWeighG: number;
  planStockFinalVolumeMl: number;
  planStockConcentrationMgPerMl: number;
  stockPo4RemovalMgPerMl: number;
  totalStockRequiredMl: number;
  stockBatchesRequired: number;
  maxDailyPo4DropMgL: number;
  days: number;
  dailyPlan: LanthanumPlanDay[];
};

function requireFinitePositive(
  value: number,
  code: LanthanumCalculationErrorCode,
  message: string,
) {
  if (!Number.isFinite(value) || value <= 0) {
    throw new LanthanumCalculationError(code, message);
  }
}

/**
 * Builds a theoretical LaCl3 plan from the 1:1 La:PO4 precipitation ratio.
 *
 * The function deliberately does not compensate for reaction efficiency,
 * carbonate/organic competition, test error, or filtration losses. The user's
 * fixed stock strength is 10 mg PO4 per mL (0.1 mg/L in 100 L). Daily
 * aliquots are calculated from that strength and never include an efficiency
 * correction.
 */
export function calculateLanthanumPlan(
  input: LanthanumPlanInput,
): LanthanumPlan {
  requireFinitePositive(
    input.currentPo4MgL,
    "invalid-current-po4",
    "当前 PO4 必须是大于 0 的有限数值。",
  );
  requireFinitePositive(
    input.targetPo4MgL,
    "invalid-target-po4",
    "目标 PO4 必须是大于 0 的有限数值。",
  );
  if (input.targetPo4MgL < MIN_TARGET_PO4_MG_L) {
    throw new LanthanumCalculationError(
      "invalid-target-po4",
      `目标 PO4 不能低于 ${MIN_TARGET_PO4_MG_L} mg/L。`,
    );
  }
  if (input.targetPo4MgL >= input.currentPo4MgL) {
    throw new LanthanumCalculationError(
      "target-not-below-current",
      "目标 PO4 必须低于当前 PO4；当前情况不需要生成降磷计划。",
    );
  }
  requireFinitePositive(
    input.netWaterVolumeL,
    "invalid-water-volume",
    "净水量必须是大于 0 的有限数值。",
  );
  requireFinitePositive(
    input.stockFinalVolumeMl,
    "invalid-stock-volume",
    "母液最终体积必须是大于 0 的有限数值。",
  );
  requireFinitePositive(
    input.maxDailyPo4DropMgL,
    "invalid-max-daily-drop",
    `计划单日降幅必须在 ${MIN_DAILY_PO4_DROP_MG_L}–${MAX_DAILY_PO4_DROP_MG_L} mg/L 之间。`,
  );
  if (
    input.maxDailyPo4DropMgL < MIN_DAILY_PO4_DROP_MG_L ||
    input.maxDailyPo4DropMgL > MAX_DAILY_PO4_DROP_MG_L
  ) {
    throw new LanthanumCalculationError(
      "invalid-max-daily-drop",
      `计划单日降幅必须在 ${MIN_DAILY_PO4_DROP_MG_L}–${MAX_DAILY_PO4_DROP_MG_L} mg/L 之间。`,
    );
  }

  const salt = LANTHANUM_CHLORIDE_HEPTAHYDRATE;
  const totalTheoreticalPo4DropMgL =
    input.currentPo4MgL - input.targetPo4MgL;
  const totalTheoreticalPo4MassMg =
    totalTheoreticalPo4DropMgL * input.netWaterVolumeL;
  const totalPo4Moles =
    totalTheoreticalPo4MassMg / 1_000 / PO4_MOLAR_MASS_G_PER_MOL;
  const stoichiometricPureSaltMassG =
    totalPo4Moles * salt.molarMassGPerMol;
  const stockPo4MolesPerMl =
    STOCK_PO4_REMOVAL_MG_PER_ML / 1_000 / PO4_MOLAR_MASS_G_PER_MOL;
  const stockPureSaltMassGPerMl =
    stockPo4MolesPerMl * salt.molarMassGPerMol;
  const planStockConcentrationMgPerMl =
    (stockPureSaltMassGPerMl / (salt.purityPercent / 100)) * 1_000;
  const solidMassToWeighG =
    (planStockConcentrationMgPerMl * input.stockFinalVolumeMl) / 1_000;
  const totalStockRequiredMl =
    totalTheoreticalPo4MassMg / STOCK_PO4_REMOVAL_MG_PER_ML;
  const stockBatchesRequired = Math.ceil(
    totalStockRequiredMl / input.stockFinalVolumeMl,
  );
  const days = Math.ceil(
    totalTheoreticalPo4DropMgL / input.maxDailyPo4DropMgL - 1e-12,
  );
  if (days > MAX_PLAN_DAYS) {
    throw new LanthanumCalculationError(
      "plan-too-long",
      `输入会生成超过 ${MAX_PLAN_DAYS} 天的计划，请核对单位与每日计划降幅。`,
    );
  }

  let remainingDropMgL = totalTheoreticalPo4DropMgL;
  let startingPo4MgL = input.currentPo4MgL;

  const dailyPlan = Array.from({ length: days }, (_, index) => {
    const day = index + 1;
    const isLastDay = day === days;
    const theoreticalPo4DropMgL = isLastDay
      ? remainingDropMgL
      : Math.min(input.maxDailyPo4DropMgL, remainingDropMgL);
    const theoreticalPo4MassMg =
      theoreticalPo4DropMgL * input.netWaterVolumeL;
    const stockToUseMl =
      theoreticalPo4MassMg / STOCK_PO4_REMOVAL_MG_PER_ML;
    if (stockToUseMl > DAILY_DILUTION_FINAL_VOLUME_ML) {
      throw new LanthanumCalculationError(
        "daily-dose-exceeds-dilution",
        "当日母液用量超过 500 mL 工作液容量，请降低单日降幅。",
      );
    }
    const solidMassInAliquotG =
      (stockToUseMl * planStockConcentrationMgPerMl) / 1_000;
    const endingPo4MgL = isLastDay
      ? input.targetPo4MgL
      : startingPo4MgL - theoreticalPo4DropMgL;

    const planDay: LanthanumPlanDay = {
      day,
      startingPo4MgL,
      theoreticalPo4DropMgL,
      endingPo4MgL,
      theoreticalPo4MassMg,
      stockToUseMl,
      rodiToFinalVolumeMl: DAILY_DILUTION_FINAL_VOLUME_ML - stockToUseMl,
      dilutedFinalVolumeMl: DAILY_DILUTION_FINAL_VOLUME_ML,
      solidMassInAliquotG,
    };

    remainingDropMgL -= theoreticalPo4DropMgL;
    startingPo4MgL = endingPo4MgL;
    return planDay;
  });

  return {
    modelVersion: "lacl3-heptahydrate-variable-volume-v4",
    measurementBasis: "PO4",
    stoichiometricMolarRatioLaToPo4: 1,
    efficiencyCompensationApplied: false,
    saltForm: "heptahydrate",
    saltFormula: salt.formula,
    saltMolarMassGPerMol: salt.molarMassGPerMol,
    purityPercent: salt.purityPercent,
    currentPo4MgL: input.currentPo4MgL,
    targetPo4MgL: input.targetPo4MgL,
    totalTheoreticalPo4DropMgL,
    netWaterVolumeL: input.netWaterVolumeL,
    totalTheoreticalPo4MassMg,
    totalPo4Moles,
    stoichiometricPureSaltMassG,
    solidMassToWeighG,
    planStockFinalVolumeMl: input.stockFinalVolumeMl,
    planStockConcentrationMgPerMl,
    stockPo4RemovalMgPerMl: STOCK_PO4_REMOVAL_MG_PER_ML,
    totalStockRequiredMl,
    stockBatchesRequired,
    maxDailyPo4DropMgL: input.maxDailyPo4DropMgL,
    days,
    dailyPlan,
  };
}
