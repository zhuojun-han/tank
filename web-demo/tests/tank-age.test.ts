import test from 'node:test';
import assert from 'node:assert/strict';
import { tankAgeDays, validateTankStartDate } from '../app/tank-age.ts';

test('tank age is zero on the start day and counts calendar boundaries across months and leap years', () => {
  for (const [startedOn, today, expected] of [
    ['2026-09-08', '2026-09-08', 0],
    ['2026-09-07', '2026-09-08', 1],
    ['2026-08-31', '2026-09-01', 1],
    ['2025-12-31', '2026-01-01', 1],
    ['2024-02-28', '2024-03-01', 2],
    ['2025-02-28', '2025-03-01', 1],
    ['2024-02-29', '2025-02-28', 365],
    ['0099-12-31', '0100-01-01', 1],
  ] as const) assert.equal(tankAgeDays(startedOn, today), expected, `${startedOn} -> ${today}`);
});

test('DST transitions and timezone changes do not change the calendar-day result', () => {
  const originalTimezone = process.env.TZ;
  try {
    for (const timezone of ['Asia/Shanghai', 'America/New_York', 'Europe/Berlin', 'Pacific/Auckland']) {
      process.env.TZ = timezone;
      for (const [startedOn, today] of [
        ['2026-03-07', '2026-03-09'],
        ['2026-10-31', '2026-11-02'],
        ['2026-03-28', '2026-03-30'],
        ['2026-10-24', '2026-10-26'],
      ]) assert.equal(tankAgeDays(startedOn, today), 2, timezone);
    }
  } finally {
    if (originalTimezone === undefined) delete process.env.TZ;
    else process.env.TZ = originalTimezone;
  }
});

test('missing, malformed and temporarily future start dates do not produce a fabricated or negative age', () => {
  for (const startedOn of [undefined, '', '2026-09-09', '2026-02-30', '2025-02-29', '2026-9-8', '2026-09-08T00:00:00Z', 'unknown']) {
    assert.equal(tankAgeDays(startedOn, '2026-09-08'), null, String(startedOn));
  }
  assert.equal(tankAgeDays('2026-09-08', 'invalid'), null);
  assert.equal(tankAgeDays('2026-09-09', '2026-09-09'), 0, 'a preserved future date becomes usable when the local day catches up');
});

test('date selection allows clearing and valid past or current days but rejects future or invalid dates', () => {
  assert.equal(validateTankStartDate('', '2026-09-08'), undefined);
  assert.equal(validateTankStartDate('2024-02-29', '2026-09-08'), '2024-02-29');
  assert.equal(validateTankStartDate('2026-09-08', '2026-09-08'), '2026-09-08');
  assert.throws(() => validateTankStartDate('2026-09-09', '2026-09-08'), /不能晚于今天/);
  for (const value of ['2026-02-30', '2025-02-29', '2026-00-01', '2026-13-01', '2026-09-00', '2026-9-8', '2026-09-08T00:00:00Z', ' 2026-09-08 ', 'bad']) {
    assert.throws(() => validateTankStartDate(value, '2026-09-08'), /有效的开缸日期/, value);
  }
  assert.throws(() => validateTankStartDate('2026-09-08', 'bad'), /当前日期无效/);
});
