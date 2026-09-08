export const SODIUM_BICARBONATE_MOLAR_MASS_G_PER_MOL = 84.007;

/** One milliequivalent per litre equals approximately 2.8 dKH. */
export const DKH_PER_MEQ_L = 2.8;

export const DEFAULT_SODIUM_BICARBONATE_PURITY_PERCENT = 100;
export const DEFAULT_MAX_DAILY_DKH_RISE = 0.5;
export const DEFAULT_DAILY_DKH_CONSUMPTION = 0.5;
export const DEFAULT_ALKALINITY_STOCK_FINAL_VOLUME_ML = 500;
export const DEFAULT_STOCK_ML_PER_0_1_DKH_100L = 6;
export const STOCK_ML_PER_0_1_DKH_100L_OPTIONS = [4, 6, 8, 10] as const;

export const MIN_DAILY_DKH_RISE = 0.1;
export const MAX_DAILY_DKH_RISE = 1.0;
export const MIN_STOCK_TEMPERATURE_C = 0;
export const MAX_STOCK_TEMPERATURE_C = 40;
export const SOLUBILITY_MARGIN_FRACTION = 0.8;

export const SODIUM_BICARBONATE_SOLUBILITY = [
  { temperatureC: 0, gramsPer100gSolution: 6.4 },
  { temperatureC: 10, gramsPer100gSolution: 7.6 },
  { temperatureC: 20, gramsPer100gSolution: 8.7 },
  { temperatureC: 30, gramsPer100gSolution: 10.0 },
  { temperatureC: 40, gramsPer100gSolution: 11.3 },
] as const;

/** Prevent pathological inputs from allocating an unbounded daily array. */
export const MAX_ALKALINITY_PLAN_DAYS = 3_650;

export type AlkalinityCalculationErrorCode =
  | "invalid-current-dkh"
  | "invalid-target-dkh"
  | "target-not-above-current"
  | "invalid-water-volume"
  | "invalid-purity"
  | "invalid-max-daily-rise"
  | "invalid-daily-consumption"
  | "invalid-stock-volume"
  | "invalid-stock-temperature"
  | "invalid-stock-strength"
  | "stock-concentration-exceeds-solubility-margin"
  | "plan-too-long";

export class AlkalinityCalculationError extends Error {
  readonly code: AlkalinityCalculationErrorCode;

  constructor(code: AlkalinityCalculationErrorCode, message: string) {
    super(message);
    this.name = "AlkalinityCalculationError";
    this.code = code;
  }
}

export type AlkalinityPlanInput = {
  currentDkh: number;
  targetDkh: number;
  netWaterVolumeL: number;
  purityPercent: number;
  /** Maximum planned net dKH gain per day, after assumed consumption. */
  maxDailyDkhRise: number;
  dailyDkhConsumption: number;
  /** Final volume of one prepared stock batch. */
  stockFinalVolumeMl: number;
  /** Integer stock dose that contributes 0.1 dKH to 100 L. */
  stockMlPer0_1Dkh100L: number;
  /** Lowest expected stock-solution temperature. */
  stockTemperatureC: number;
};

export type AlkalinityPlanDay = {
  day: number;
  startingDkh: number;
  plannedNetDkhRise: number;
  assumedDkhConsumption: number;
  theoreticalDoseDkh: number;
  postDoseDkh: number;
  expectedEndingDkh: number;
  alkalinityAddedMeqL: number;
  pureSodiumBicarbonateMassG: number;
  reagentMassInAliquotG: number;
  stockToUseMl: number;
};

export type AlkalinityPlan = {
  modelVersion: "nahco3-dkh-stock-v2";
  additiveFormula: "NaHCO₃";
  molarMassGPerMol: number;
  alkalinityEquivalentsPerMole: 1;
  dkhPerMeqL: number;
  currentDkh: number;
  targetDkh: number;
  totalDkhRise: number;
  netWaterVolumeL: number;
  purityPercent: number;
  maxDailyDkhRise: number;
  dailyDkhConsumption: number;
  totalAssumedDkhConsumption: number;
  totalTheoreticalDoseDkh: number;
  totalAlkalinityMeqL: number;
  totalAlkalinityMilliequivalents: number;
  totalPureSodiumBicarbonateMassG: number;
  totalReagentMassRequiredG: number;
  gramsPurePer100LPerDkh: number;
  stockFinalVolumeMl: number;
  stockMlPer0_1Dkh100L: number;
  stockStrengthDkhPerMlPer100L: number;
  pureStockConcentrationGPerL: number;
  stockReagentConcentrationGPerL: number;
  stockSolidMassToWeighG: number;
  stockTemperatureC: number;
  solubilityGramsPer100gSolution: number;
  approximateSaturationConcentrationGPerL: number;
  conservativeMaxStockConcentrationGPerL: number;
  solubilityUtilizationPercent: number;
  totalStockRequiredMl: number;
  stockShortfallMl: number;
  stockBatchesRequired: number;
  days: number;
  dailyPlan: AlkalinityPlanDay[];
};

function requireFiniteNonNegative(value: number, code: AlkalinityCalculationErrorCode, message: string) {
  if (!Number.isFinite(value) || value < 0) throw new AlkalinityCalculationError(code, message);
}

function requireFinitePositive(value: number, code: AlkalinityCalculationErrorCode, message: string) {
  if (!Number.isFinite(value) || value <= 0) throw new AlkalinityCalculationError(code, message);
}

export function sodiumBicarbonateSolubilityAt(temperatureC: number) {
  if (!Number.isFinite(temperatureC) || temperatureC < MIN_STOCK_TEMPERATURE_C || temperatureC > MAX_STOCK_TEMPERATURE_C) {
    throw new AlkalinityCalculationError("invalid-stock-temperature", `母液最低温度必须在 ${MIN_STOCK_TEMPERATURE_C}–${MAX_STOCK_TEMPERATURE_C}°C 之间。`);
  }
  const upperIndex = SODIUM_BICARBONATE_SOLUBILITY.findIndex((point) => point.temperatureC >= temperatureC);
  if (upperIndex <= 0) return SODIUM_BICARBONATE_SOLUBILITY[0].gramsPer100gSolution;
  const lower = SODIUM_BICARBONATE_SOLUBILITY[upperIndex - 1];
  const upper = SODIUM_BICARBONATE_SOLUBILITY[upperIndex];
  const ratio = (temperatureC - lower.temperatureC) / (upper.temperatureC - lower.temperatureC);
  return lower.gramsPer100gSolution + ratio * (upper.gramsPer100gSolution - lower.gramsPer100gSolution);
}

/**
 * Builds a theoretical NaHCO3 stock-solution plan from alkalinity equivalents.
 * Solubility points are g/100 g solution. The UI guard converts them with a
 * conservative 1 kg/L reference, then keeps an additional 20% margin.
 */
export function calculateAlkalinityPlan(input: AlkalinityPlanInput): AlkalinityPlan {
  requireFiniteNonNegative(input.currentDkh, "invalid-current-dkh", "当前 KH 必须是大于或等于 0 的有限数值。");
  requireFinitePositive(input.targetDkh, "invalid-target-dkh", "目标 KH 必须是大于 0 的有限数值。");
  if (input.targetDkh <= input.currentDkh) throw new AlkalinityCalculationError("target-not-above-current", "目标 KH 必须高于当前 KH；当前情况不需要生成提升计划。");
  requireFinitePositive(input.netWaterVolumeL, "invalid-water-volume", "净水量必须是大于 0 的有限数值。");
  requireFinitePositive(input.purityPercent, "invalid-purity", "纯度必须是大于 0 且不超过 100% 的有限数值。");
  if (input.purityPercent > 100) throw new AlkalinityCalculationError("invalid-purity", "纯度必须是大于 0 且不超过 100% 的有限数值。");
  requireFinitePositive(input.maxDailyDkhRise, "invalid-max-daily-rise", `计划单日净升幅必须在 ${MIN_DAILY_DKH_RISE}–${MAX_DAILY_DKH_RISE} dKH 之间。`);
  if (input.maxDailyDkhRise < MIN_DAILY_DKH_RISE || input.maxDailyDkhRise > MAX_DAILY_DKH_RISE) throw new AlkalinityCalculationError("invalid-max-daily-rise", `计划单日净升幅必须在 ${MIN_DAILY_DKH_RISE}–${MAX_DAILY_DKH_RISE} dKH 之间。`);
  requireFiniteNonNegative(input.dailyDkhConsumption, "invalid-daily-consumption", "每日 KH 消耗量必须是大于或等于 0 的有限数值。");
  requireFinitePositive(input.stockFinalVolumeMl, "invalid-stock-volume", "母液最终体积必须是大于 0 的有限数值。");
  if (!Number.isInteger(input.stockMlPer0_1Dkh100L) || !STOCK_ML_PER_0_1_DKH_100L_OPTIONS.includes(input.stockMlPer0_1Dkh100L as (typeof STOCK_ML_PER_0_1_DKH_100L_OPTIONS)[number])) {
    throw new AlkalinityCalculationError("invalid-stock-strength", `母液强度必须选择 ${STOCK_ML_PER_0_1_DKH_100L_OPTIONS.join("、")} mL 档位之一。`);
  }

  const solubilityGramsPer100gSolution = sodiumBicarbonateSolubilityAt(input.stockTemperatureC);
  const gramsPurePer100LPerDkh = (100 / DKH_PER_MEQ_L / 1_000) * SODIUM_BICARBONATE_MOLAR_MASS_G_PER_MOL;
  const stockStrengthDkhPerMlPer100L = 0.1 / input.stockMlPer0_1Dkh100L;
  const pureStockConcentrationGPerL = (gramsPurePer100LPerDkh * 0.1 * 1_000) / input.stockMlPer0_1Dkh100L;
  const stockReagentConcentrationGPerL = pureStockConcentrationGPerL / (input.purityPercent / 100);
  const approximateSaturationConcentrationGPerL = solubilityGramsPer100gSolution * 10;
  const conservativeMaxStockConcentrationGPerL = approximateSaturationConcentrationGPerL * SOLUBILITY_MARGIN_FRACTION;
  if (stockReagentConcentrationGPerL > conservativeMaxStockConcentrationGPerL + 1e-12) {
    throw new AlkalinityCalculationError("stock-concentration-exceeds-solubility-margin", `该档位需约 ${stockReagentConcentrationGPerL.toFixed(3)} g/L，超过 ${input.stockTemperatureC}°C 下采用 20% 余量后的 ${conservativeMaxStockConcentrationGPerL.toFixed(3)} g/L 上限；请选择更大的每 0.1 dKH 毫升数或更高且真实可保持的最低温度。`);
  }

  const totalDkhRise = input.targetDkh - input.currentDkh;
  const days = Math.ceil(totalDkhRise / input.maxDailyDkhRise - 1e-12);
  if (days > MAX_ALKALINITY_PLAN_DAYS) throw new AlkalinityCalculationError("plan-too-long", `输入会生成超过 ${MAX_ALKALINITY_PLAN_DAYS} 天的计划，请核对单位与每日计划净升幅。`);

  let remainingRiseDkh = totalDkhRise;
  let startingDkh = input.currentDkh;
  const dailyPlan = Array.from({ length: days }, (_, index) => {
    const day = index + 1;
    const isLastDay = day === days;
    const plannedNetDkhRise = isLastDay ? remainingRiseDkh : Math.min(input.maxDailyDkhRise, remainingRiseDkh);
    const theoreticalDoseDkh = plannedNetDkhRise + input.dailyDkhConsumption;
    const alkalinityAddedMeqL = theoreticalDoseDkh / DKH_PER_MEQ_L;
    const pureSodiumBicarbonateMassG = ((alkalinityAddedMeqL * input.netWaterVolumeL) / 1_000) * SODIUM_BICARBONATE_MOLAR_MASS_G_PER_MOL;
    const reagentMassInAliquotG = pureSodiumBicarbonateMassG / (input.purityPercent / 100);
    const stockToUseMl = (theoreticalDoseDkh * (input.netWaterVolumeL / 100)) / stockStrengthDkhPerMlPer100L;
    const postDoseDkh = startingDkh + theoreticalDoseDkh;
    const expectedEndingDkh = isLastDay ? input.targetDkh : startingDkh + plannedNetDkhRise;
    const planDay: AlkalinityPlanDay = { day, startingDkh, plannedNetDkhRise, assumedDkhConsumption: input.dailyDkhConsumption, theoreticalDoseDkh, postDoseDkh, expectedEndingDkh, alkalinityAddedMeqL, pureSodiumBicarbonateMassG, reagentMassInAliquotG, stockToUseMl };
    remainingRiseDkh -= plannedNetDkhRise;
    startingDkh = expectedEndingDkh;
    return planDay;
  });

  const totalAssumedDkhConsumption = input.dailyDkhConsumption * days;
  const totalTheoreticalDoseDkh = totalDkhRise + totalAssumedDkhConsumption;
  const totalAlkalinityMeqL = totalTheoreticalDoseDkh / DKH_PER_MEQ_L;
  const totalAlkalinityMilliequivalents = totalAlkalinityMeqL * input.netWaterVolumeL;
  const totalPureSodiumBicarbonateMassG = dailyPlan.reduce((total, day) => total + day.pureSodiumBicarbonateMassG, 0);
  const totalReagentMassRequiredG = dailyPlan.reduce((total, day) => total + day.reagentMassInAliquotG, 0);
  const totalStockRequiredMl = dailyPlan.reduce((total, day) => total + day.stockToUseMl, 0);
  const stockSolidMassToWeighG = (stockReagentConcentrationGPerL * input.stockFinalVolumeMl) / 1_000;

  return {
    modelVersion: "nahco3-dkh-stock-v2", additiveFormula: "NaHCO₃", molarMassGPerMol: SODIUM_BICARBONATE_MOLAR_MASS_G_PER_MOL,
    alkalinityEquivalentsPerMole: 1, dkhPerMeqL: DKH_PER_MEQ_L, currentDkh: input.currentDkh, targetDkh: input.targetDkh,
    totalDkhRise, netWaterVolumeL: input.netWaterVolumeL, purityPercent: input.purityPercent, maxDailyDkhRise: input.maxDailyDkhRise,
    dailyDkhConsumption: input.dailyDkhConsumption, totalAssumedDkhConsumption, totalTheoreticalDoseDkh, totalAlkalinityMeqL,
    totalAlkalinityMilliequivalents, totalPureSodiumBicarbonateMassG, totalReagentMassRequiredG, gramsPurePer100LPerDkh,
    stockFinalVolumeMl: input.stockFinalVolumeMl, stockMlPer0_1Dkh100L: input.stockMlPer0_1Dkh100L, stockStrengthDkhPerMlPer100L,
    pureStockConcentrationGPerL, stockReagentConcentrationGPerL, stockSolidMassToWeighG, stockTemperatureC: input.stockTemperatureC,
    solubilityGramsPer100gSolution, approximateSaturationConcentrationGPerL, conservativeMaxStockConcentrationGPerL,
    solubilityUtilizationPercent: (stockReagentConcentrationGPerL / approximateSaturationConcentrationGPerL) * 100,
    totalStockRequiredMl, stockShortfallMl: Math.max(0, totalStockRequiredMl - input.stockFinalVolumeMl),
    stockBatchesRequired: Math.ceil(totalStockRequiredMl / input.stockFinalVolumeMl), days, dailyPlan,
  };
}
