import { type EntityId } from "./entity-id.ts";
import { calculateMaintenance, type MaintenanceInput } from './maintenance-dosing.ts';
import { STOCK_PO4_REMOVAL_MG_PER_ML } from './lanthanum-calculator.ts';

export type MaintenanceChemical = 'po4' | 'kh';
export type TheoryDosingPlan = {
  planId: string; source: 'lanthanum-plan' | 'alkalinity-plan'; target: number;
  planStartDate: string; endDate: string; lastDayRatio: number;
};
export type MaintenanceCycle = {
  id: EntityId; tankId: EntityId; chemical: MaintenanceChemical;
  input: MaintenanceInput; startDate: string; refillDate: string;
  solutionMl: number; dailyLiquidMl: number; effectPerMl: number;
  retainedMl: number; addedStockMl: number; addedWaterMl: number;
  previousCycleId?: EntityId; closedOnDate?: string; refillDeferredUntil?: string;
  theory?: TheoryDosingPlan;
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
  const start = ordinal(cycle.startDate);
  let elapsedDays = Math.max(0, ordinal(date) - start);
  if (cycle.theory) {
    const end = ordinal(cycle.theory.endDate);
    const until = Math.max(start, Math.min(ordinal(date), end + 1,
      cycle.closedOnDate ? ordinal(cycle.closedOnDate) : Infinity));
    elapsedDays = Math.max(0, Math.min(until, end) - start)
      + (until > end && start <= end ? cycle.theory.lastDayRatio : 0);
  }
  return Math.max(0, cycle.solutionMl - elapsedDays * cycle.dailyLiquidMl);
}
export function cycleRemainingDays(cycle: MaintenanceCycle, date: string) {
  return cycleRemainingMl(cycle, date) / cycle.dailyLiquidMl;
}
/** The theoretical plan's last day can use a shorter pump run. */
export function cycleDailyLiquidMl(cycle: MaintenanceCycle, date: string) {
  if (date < cycle.startDate || (cycle.closedOnDate && date >= cycle.closedOnDate)) return 0;
  if (cycle.theory && date > cycle.theory.endDate) return 0;
  return cycle.dailyLiquidMl * (cycle.theory && date === cycle.theory.endDate ? cycle.theory.lastDayRatio : 1);
}
/** Residual for refill, optionally after the old recipe's dose on this date. */
export function cycleResidualMl(cycle: MaintenanceCycle, date: string, dosed = false) {
  return Math.max(0, cycleRemainingMl(cycle, date) - (dosed ? cycleDailyLiquidMl(cycle, date) : 0));
}
/** A bottle that covers the entire remaining finite plan never asks for a refill. */
export function cycleNeedsRefill(cycle: MaintenanceCycle) {
  if (!cycle.theory) return true;
  const fullDays = Math.max(0, ordinal(cycle.theory.endDate) - ordinal(cycle.startDate));
  const demand = (fullDays + cycle.theory.lastDayRatio) * cycle.dailyLiquidMl;
  return cycle.startDate <= cycle.theory.endDate
    && demand > cycle.solutionMl + Math.max(1, cycle.solutionMl, demand) * 1e-10;
}
export function currentMaintenanceCycle(cycles: MaintenanceCycle[], tankId: EntityId, chemical: MaintenanceChemical) {
  return cycles.filter(c => c.tankId === tankId && c.chemical === chemical && !c.closedOnDate).at(-1);
}

export function prepareMaintenanceCycle(input: MaintenanceInput, chemical: MaintenanceChemical, tankId: EntityId,
  startDate: string, previous?: MaintenanceCycle, retainedMl = 0, id: EntityId = Date.now(), theory?: TheoryDosingPlan): MaintenanceCycle {
  if (theory) {
    const first = ordinal(theory.planStartDate);
    const last = ordinal(theory.endDate);
    if (!theory.planId?.trim() || theory.source !== (chemical === 'po4' ? 'lanthanum-plan' : 'alkalinity-plan')
      || !Number.isFinite(theory.target) || theory.target <= 0
      || last < first || last - first >= 3650 || ordinal(startDate) < first || ordinal(startDate) > last
      || !Number.isFinite(theory.lastDayRatio) || theory.lastDayRatio <= 0 || theory.lastDayRatio > 1 + 1e-10) {
      throw new Error('理论计划已结束或参数不匹配，请重新计算。');
    }
  }
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
    addedStockMl: Math.max(0, neededStock), addedWaterMl: Math.max(0, waterMl), previousCycleId: previous?.id,
    ...(theory ? { theory: { ...theory, lastDayRatio: Math.min(1, theory.lastDayRatio) } } : {}) };
}

/** Append only when confirmed; retain previous dates and close its future cycle. */
export function addMaintenanceCycle(cycles: MaintenanceCycle[], next: MaintenanceCycle) {
  const current = currentMaintenanceCycle(cycles, next.tankId, next.chemical);
  if (current?.id !== next.previousCycleId) throw new Error('配液周期已变化，请重新计算。');
  return [...cycles.map(c => c.id === current?.id ? { ...c, closedOnDate: next.startDate } : c), next];
}

function makeTask(cycle: MaintenanceCycle, date: string, today: string, overdue = false) {
  const refill = cycleNeedsRefill(cycle) && (overdue || date >= cycle.refillDate);
  const days = cycleRemainingDays(cycle, date);
  const remainingMl = cycleRemainingMl(cycle, date);
  const volume = remainingMl > 0 && remainingMl < 0.001
    ? remainingMl.toExponential(3) : String(Number(remainingMl.toFixed(3)));
  const remaining = `预计剩余 ${volume} mL`;
  const name = cycle.chemical === 'po4' ? 'PO₄' : 'KH';
  const ended = cycle.theory && today > cycle.theory.endDate;
  const state: 'done' | 'due' | 'soon' = !refill || cycle.closedOnDate || ended ? 'done' : date <= today ? 'due' : 'soon';
  const detail = cycle.closedOnDate ? `${remaining} · 已于 ${cycle.closedOnDate} ${cycle.theory ? '结束' : '续配'}`
    : ended ? `${remaining} · 计划已结束`
    : cycle.theory && !cycleNeedsRefill(cycle) ? `${remaining} · ${cycle.theory.endDate} 计划结束`
    : overdue ? `${remaining} · ${date} 提醒配液${date <= today ? '，补液已逾期' : ''}`
      : refill ? `${remaining} · ${cycle.refillDate} 需配液` : `${remaining} · ${cycle.refillDate} 补液`;
  return { id: typeof cycle.id === 'number' ? -cycle.id : `maintenance:${cycle.id}`, tankId: cycle.tankId, source: 'maintenance-cycle' as const, maintenanceCycleId: cycle.id,
    title: `${name} ${cycle.theory ? '理论计划' : '每日平衡'}${refill ? ' · 添加滴定液' : ''}`,
    cycle: `预计还可用 ${Math.round(days)} 天（${days.toPrecision(3)} 天）`,
    due: cycle.theory && !cycleNeedsRefill(cycle) ? `${cycle.theory.endDate} 计划结束` : `${refill ? date : cycle.refillDate} 补液`,
    scheduledDate: date, oneOff: true, state,
    detail: cycle.theory && !cycle.closedOnDate && !ended
      ? `${detail} · 运行 ${Number(((cycle.chemical === 'po4' ? cycle.input.po4Minutes : cycle.input.khMinutes)
        * cycleDailyLiquidMl(cycle, date) / cycle.dailyLiquidMl).toPrecision(3))} min${date === cycle.theory.endDate ? ' 后停止' : ''}` : detail,
  };
}

export function maintenanceReminderDate(cycle: MaintenanceCycle, today: string) {
  const date = [cycle.refillDate, cycle.refillDeferredUntil ?? cycle.refillDate, today].sort().at(-1)!;
  return cycle.theory && date > cycle.theory.endDate ? cycle.theory.endDate : date;
}

/** Delay only the reminder, never the physical reservoir forecast. */
export function delayMaintenanceCycle(cycles: MaintenanceCycle[], id: EntityId, days: number, today: string) {
  const cycle = cycles.find(c => c.id === id && !c.closedOnDate);
  if (!cycle) throw new Error('补液周期已变化，请重新打开任务。');
  if (!Number.isSafeInteger(days) || days < 1) throw new Error('延迟天数须为大于 0 的整数。');
  if (cycle.theory && (!cycleNeedsRefill(cycle) || today >= cycle.theory.endDate)) throw new Error('理论计划无需继续补液，请重新检测后计算。');
  const time = (ordinal(maintenanceReminderDate(cycle, today)) + days) * dayMs;
  if (!Number.isFinite(time) || time > Date.UTC(9999, 11, 31)) throw new Error('延迟日期超出可用范围。');
  const requestedDate = new Date(time).toISOString().slice(0, 10);
  const refillDeferredUntil = cycle.theory && requestedDate > cycle.theory.endDate ? cycle.theory.endDate : requestedDate;
  return cycles.map(c => c.id === id ? { ...c, refillDeferredUntil } : c);
}

/** Finite daily status plus one outstanding refill that rolls forward until confirmed. */
export function maintenanceTasksOnDate(cycles: MaintenanceCycle[], tankId: EntityId, date: string, today: string) {
  return cycles.filter(c => c.tankId === tankId && date >= c.startDate &&
    (!c.theory || date <= c.theory.endDate) &&
    (c.closedOnDate ? date < c.closedOnDate && (!cycleNeedsRefill(c) || date <= c.refillDate)
      : !cycleNeedsRefill(c) || date < c.refillDate || date === maintenanceReminderDate(c, today)))
    .map(c => makeTask(c, date, today, date > c.refillDate));
}

/** Compatibility accessor; callers must not merge this with the same day's projection. */
export function overdueMaintenanceTasks(cycles: MaintenanceCycle[], tankId: EntityId, today: string) {
  return maintenanceTasksOnDate(cycles, tankId, today, today)
    .filter(task => task.state === 'due' && cycles.some(c => c.id === task.maintenanceCycleId && today > c.refillDate));
}
