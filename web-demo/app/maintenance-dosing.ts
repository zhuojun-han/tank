import { DKH_PER_MEQ_L, SODIUM_BICARBONATE_MOLAR_MASS_G_PER_MOL, sodiumBicarbonateSolubilityAt, SOLUBILITY_MARGIN_FRACTION, STOCK_ML_PER_0_1_DKH_100L_OPTIONS } from './alkalinity-calculator.ts';
import { STOCK_PO4_REMOVAL_MG_PER_ML } from './lanthanum-calculator.ts';

export type MaintenanceInput = {
  solutionMl?: number; waterL: number; po4Rise: number; khDrop: number; days?: number;
  khStrength: number; khPurity: number; temperature: number;
  po4Flow: number; khFlow: number; po4Minutes: number; khMinutes: number;
  po4Unit: 'ml/s' | 'ml/min'; khUnit: 'ml/s' | 'ml/min';
};

/** Separate reagent reservoir volume; no efficiency correction. */
export function calculateMaintenance(input: MaintenanceInput) {
  const solutionMl = input.solutionMl ?? 500;
  if (!Number.isFinite(solutionMl) || solutionMl <= 0) throw new Error('滴定溶液体积必须大于 0。');
  for (const [key, value] of Object.entries(input)) {
    if (key.endsWith('Unit') || key === 'days') continue; // Legacy saved days is no longer an input.
    if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) throw new Error('请填写有效的非负数值。');
  }
  if ([input.waterL, input.po4Flow, input.khFlow, input.po4Minutes, input.khMinutes, input.khPurity].some(v => v <= 0)) throw new Error('净水量、流速、运行时间和纯度必须大于 0。');
  if (input.khPurity > 100 || !STOCK_ML_PER_0_1_DKH_100L_OPTIONS.some(v => v === input.khStrength)) throw new Error('请核对 KH 母液档位和纯度。');
  if (![input.po4Unit, input.khUnit].every(v => v === 'ml/s' || v === 'ml/min')) throw new Error('请选择 ml/s 或 ml/min。');
  const khConcentration = SODIUM_BICARBONATE_MOLAR_MASS_G_PER_MOL * 10 / DKH_PER_MEQ_L / input.khStrength / (input.khPurity / 100);
  if (khConcentration > sodiumBicarbonateSolubilityAt(input.temperature) * 10 * SOLUBILITY_MARGIN_FRACTION + 1e-12) throw new Error('KH 母液超过该温度下的既有溶解度余量，请选择更稀的档位或核对最低温度。');
  function channel(dailyStockMl: number, flow: number, minutes: number, unit: 'ml/s' | 'ml/min') {
    const flowMlMinute = flow * (unit === 'ml/s' ? 60 : 1);
    const dailyLiquidMl = flowMlMinute * minutes;
    const actualDays = solutionMl / dailyLiquidMl;
    const stockMl = dailyStockMl * actualDays;
    const values = [dailyLiquidMl, actualDays, stockMl];
    if (!values.every(Number.isFinite) || dailyLiquidMl <= 0 || actualDays <= 0) throw new Error('输入超出可计算范围，请核对数值。');
    return { dailyStockMl, dailyLiquidMl, actualDays, stockMl,
      estimatedDays: Math.round(actualDays), solutionMl, feasible: stockMl <= solutionMl };
  }
  return {
    khConcentration,
    po4: channel(input.po4Rise * input.waterL / STOCK_PO4_REMOVAL_MG_PER_ML, input.po4Flow, input.po4Minutes, input.po4Unit),
    kh: channel(input.khDrop * input.waterL / 100 / 0.1 * input.khStrength, input.khFlow, input.khMinutes, input.khUnit),
  };
}
