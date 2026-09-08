import { isCalendarDate } from './rolling-task.ts';

/** Calendar-day age, independent of local midnight length and daylight saving. */
export function tankAgeDays(startedOn: string | undefined, today: string): number | null {
  if (!isCalendarDate(startedOn) || !isCalendarDate(today) || startedOn > today) return null;
  return (Date.parse(`${today}T00:00:00Z`) - Date.parse(`${startedOn}T00:00:00Z`)) / 86_400_000;
}

/** Validate a user selection; reading an existing snapshot must not use this future-date check. */
export function validateTankStartDate(value: string, today: string): string | undefined {
  if (value === '') return undefined;
  if (!isCalendarDate(value)) throw new Error('请选择有效的开缸日期。');
  if (!isCalendarDate(today)) throw new Error('当前日期无效，请检查设备日期。');
  if (value > today) throw new Error('开缸日期不能晚于今天。');
  return value;
}
