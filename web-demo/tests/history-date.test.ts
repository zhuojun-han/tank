import test from 'node:test';
import assert from 'node:assert/strict';
import { historyDate } from '../app/history-date.ts';
test('legacy times are not truncated into chart dates; legacy and ISO sort chronologically',()=>{
  assert.equal(historyDate('8月3日 19:42',2026).label,'08-03');
  assert.equal(historyDate('7月20日 19:10',2026).label,'07-20');
  assert.equal(historyDate('7月27日 18:20',2026).label,'07-27');
  assert.ok(historyDate('8月3日 19:42',2026).time<historyDate('2026-08-22T12:00:00+08:00',2026).time);
  assert.equal(historyDate('unknown',2026).label,'日期待确认');
});
