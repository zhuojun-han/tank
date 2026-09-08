import { calculateMaintenance, type MaintenanceInput } from './maintenance-dosing.ts';
import { STOCK_PO4_REMOVAL_MG_PER_ML } from './lanthanum-calculator.ts';

export type MaintenanceChemical = 'po4' | 'kh';
export type MaintenanceCycle = {
  id: number; tankId: number; chemical: MaintenanceChemical;
  input: MaintenanceInput; startDate: string; refillDate: string;
  solutionMl: number; dailyLiquidMl: number; effectPerMl: number;
  retainedMl: number; addedStockMl: number; addedWaterMl: number;
  previousCycleId?: number; closedOnDate?: string;
};

const dayMs = 86_400_000;
function ordinal(date: string) {
  const value = Date.parse(`${date}T00:00:00Z`);
  if (!Number.isFinite(value) || new Date(value).toISOString().slice(0, 10) !== date) throw new Error('请核对配液日期。');
  return value / dayMs;
}
export function localCycleDate(now = new Date()) {
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
}
export function cycleRemainingMl(cycle: MaintenanceCycle, date: string) {
  // Completed calendar days only: the user confirms the actual remaining volume.
  return Math.max(0, cycle.solutionMl - Math.max(0, ordinal(date) - ordinal(cycle.startDate)) * cycle.dailyLiquidMl);
}
export function cycleRemainingDays(cycle: MaintenanceCycle, date: string) {
  const elapsedDays = Math.max(0, ordinal(date) - ordinal(cycle.startDate));
  return Math.max(0, cycle.solutionMl / cycle.dailyLiquidMl - elapsedDays);
}
export function currentMaintenanceCycle(cycles: MaintenanceCycle[], tankId: number, chemical: MaintenanceChemical) {
  return cycles.filter(c => c.tankId === tankId && c.chemical === chemical && !c.closedOnDate).at(-1);
}

export function prepareMaintenanceCycle(input: MaintenanceInput, chemical: MaintenanceChemical, tankId: number,
  startDate: string, previous?: MaintenanceCycle, retainedMl = 0, id = Date.now()): MaintenanceCycle {
  const r = calculateMaintenance(input)[chemical];
  if (r.dailyStockMl <= 0) throw new Error('每日变化为 0，无需添加滴定周期。');
  if (!r.feasible) throw new Error('所需母液超过容量，请调整配方。');
  if (!Number.isFinite(retainedMl) || retainedMl < 0 || retainedMl > r.solutionMl) throw new Error('残液体积须在 0 与新配液总体积之间。');
  if (previous && (previous.tankId !== tankId || previous.chemical !== chemical || previous.closedOnDate || startDate < previous.startDate)) throw new Error('上次配液记录不匹配，请重新打开配方。');
  if (retainedMl > 0 && (!previous || retainedMl > previous.solutionMl)) throw new Error('残液体积不能超过上次配液体积。');
  // PO4: mg removal equivalent. KH: dKH increase in 100 L. Mother-stock
  // purity is already compensated by calculateMaintenance's stock recipe.
  const stockEffect = chemical === 'po4' ? STOCK_PO4_REMOVAL_MG_PER_ML : 0.1 / input.khStrength;
  const effectPerMl = r.stockMl * stockEffect / r.solutionMl;
  const retainedEffect = retainedMl * (previous?.effectPerMl ?? 0);
  const neededStock = (effectPerMl * r.solutionMl - retainedEffect) / stockEffect;
  const waterMl = r.solutionMl - retainedMl - neededStock;
  if (neededStock < -1e-8) throw new Error('残液中的药量已超过新配方需要，请减少保留残液或增加总体积。');
  if (waterMl < -1e-8) throw new Error('残液加所需母液超过容量，请减少保留残液或增加总体积。');
  const refillOrdinal = ordinal(startDate) + Math.max(0, Math.ceil(r.actualDays - 1e-10) - 1);
  const refillTime = refillOrdinal * dayMs;
  if (!Number.isFinite(refillTime) || refillTime > Date.UTC(9999, 11, 31)) throw new Error('预计补液日期超出可用范围，请核对流速。');
  return { id, tankId, chemical, input: { ...input }, startDate,
    refillDate: new Date(refillTime).toISOString().slice(0, 10), solutionMl: r.solutionMl,
    dailyLiquidMl: r.dailyLiquidMl, effectPerMl, retainedMl,
    addedStockMl: Math.max(0, neededStock), addedWaterMl: Math.max(0, waterMl), previousCycleId: previous?.id };
}

/** Append only when confirmed; retain previous dates and close its future cycle. */
export function addMaintenanceCycle(cycles: MaintenanceCycle[], next: MaintenanceCycle) {
  const current = currentMaintenanceCycle(cycles, next.tankId, next.chemical);
  if (current?.id !== next.previousCycleId) throw new Error('配液周期已变化，请重新计算。');
  return [...cycles.map(c => c.id === current?.id ? { ...c, closedOnDate: next.startDate } : c), next];
}

function makeTask(cycle: MaintenanceCycle, date: string, today: string, overdue = false) {
  const refill = overdue || date === cycle.refillDate;
  const days = cycleRemainingDays(cycle, date);
  const remainingMl = cycleRemainingMl(cycle, date);
  const volume = remainingMl > 0 && remainingMl < 0.001
    ? remainingMl.toExponential(3) : String(Number(remainingMl.toFixed(3)));
  const remaining = `预计剩余 ${volume} mL`;
  const name = cycle.chemical === 'po4' ? 'PO₄' : 'KH';
  const state: 'done' | 'due' | 'soon' = !refill || cycle.closedOnDate ? 'done' : date <= today ? 'due' : 'soon';
  const detail = cycle.closedOnDate ? `${remaining} · 已于 ${cycle.closedOnDate} 续配`
    : overdue ? `${remaining} · 补液已逾期，请添加滴定液`
      : refill ? `${remaining} · ${cycle.refillDate} 需配液` : `${remaining} · ${cycle.refillDate} 补液`;
  return { id: -cycle.id, tankId: cycle.tankId, source: 'maintenance-cycle' as const, maintenanceCycleId: cycle.id,
    title: `${name} 每日平衡${refill ? ' · 添加滴定液' : ''}`,
    cycle: `预计还可用 ${Math.round(days)} 天（${days.toPrecision(3)} 天）`,
    due: `${cycle.refillDate} 补液`, scheduledDate: date, oneOff: true, state, detail,
  };
}

/** Finite calendar occurrences; overdue reminders are projected separately. */
export function maintenanceTasksOnDate(cycles: MaintenanceCycle[], tankId: number, date: string, today: string) {
  return cycles.filter(c => c.tankId === tankId && date >= c.startDate && date <= c.refillDate
    && (!c.closedOnDate || date < c.closedOnDate)).map(c => makeTask(c, date, today));
}

/** One reminder per overdue active cycle, for today's pending views, never the calendar. */
export function overdueMaintenanceTasks(cycles: MaintenanceCycle[], tankId: number, today: string) {
  return cycles.filter(c => c.tankId === tankId && !c.closedOnDate && today > c.refillDate)
    .map(c => makeTask(c, today, today, true));
}
