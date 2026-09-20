import type { AlkalinityPlan } from './alkalinity-calculator.ts';
import type { LanthanumPlan } from './lanthanum-calculator.ts';
import type { MaintenanceChemical, TheoryDosingPlan } from './maintenance-cycle.ts';
import type { MaintenanceInput } from './maintenance-dosing.ts';

export type TheoryDosingSettings = {
  solutionMl: number; flow: number; minutes: number; unit: 'ml/s' | 'ml/min';
  startDate: string; planId: string;
};

/** One concentration for the whole plan; reduce the final pump run, not its concentration. */
export function theoryDosingRecipe(plan: LanthanumPlan | AlkalinityPlan, settings: TheoryDosingSettings): {
  chemical: MaintenanceChemical; input: MaintenanceInput; theory: TheoryDosingPlan;
} {
  const first = plan.dailyPlan[0];
  const last = plan.dailyPlan.at(-1);
  const start = Date.parse(`${settings.startDate}T00:00:00Z`);
  if (!first || !last || !Number.isSafeInteger(plan.days) || plan.days < 1 || plan.days > 3650
    || !Number.isFinite(start) || new Date(start).toISOString().slice(0, 10) !== settings.startDate) {
    throw new Error('请核对理论计划与配液日期。');
  }
  const end = new Date(start + (plan.days - 1) * 86_400_000);
  if (end.getUTCFullYear() > 9999 || !Number.isFinite(end.getTime())) throw new Error('计划结束日期超出可用范围。');
  const po4 = 'targetPo4MgL' in plan;
  const dailyChange = po4 ? plan.dailyPlan[0].theoreticalPo4DropMgL : plan.dailyPlan[0].theoreticalDoseDkh;
  const lastChange = po4 ? plan.dailyPlan.at(-1)!.theoreticalPo4DropMgL : plan.dailyPlan.at(-1)!.theoreticalDoseDkh;
  if (!Number.isFinite(dailyChange) || dailyChange <= 0 || !Number.isFinite(lastChange) || lastChange <= 0) {
    throw new Error('理论计划没有有效的每日滴定需求。');
  }
  const input: MaintenanceInput = {
    solutionMl: settings.solutionMl, waterL: plan.netWaterVolumeL,
    po4Rise: po4 ? dailyChange : 0, khDrop: po4 ? 0 : dailyChange,
    khStrength: po4 ? 6 : plan.stockMlPer0_1Dkh100L,
    khPurity: po4 ? 100 : plan.purityPercent, temperature: po4 ? 20 : plan.stockTemperatureC,
    po4Flow: settings.flow, khFlow: settings.flow,
    po4Minutes: settings.minutes, khMinutes: settings.minutes,
    po4Unit: settings.unit, khUnit: settings.unit,
  };
  return { chemical: po4 ? 'po4' : 'kh', input, theory: {
    planId: settings.planId, source: po4 ? 'lanthanum-plan' : 'alkalinity-plan',
    target: po4 ? plan.targetPo4MgL : plan.targetDkh,
    planStartDate: settings.startDate, endDate: end.toISOString().slice(0, 10),
    lastDayRatio: Math.min(1, lastChange / dailyChange),
  } };
}
