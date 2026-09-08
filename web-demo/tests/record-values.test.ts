import assert from 'node:assert/strict';
import test from 'node:test';
import { readRecordValues, recordPoint, recordValueText } from '../app/record-values.ts';
test('range and interpolation stay independent, old ranges are not invented points', () => {
  assert.deepEqual(readRecordValues('10', '25', '17.3'), { low:10, high:25, interpolation:17.3 });
  assert.equal(recordPoint({low:10,high:25}),null);
  assert.equal(recordPoint({low:.08,high:.08}),.08);
  assert.equal(readRecordValues('.05','.1','.072').interpolation,.072);
});
test('invalid input and points outside range are rejected without clamping', () => {
  for(const args of [['','25',''], ['25','10','17'], ['10','25','30'], ['10','25','NaN'], ['-1','25','']]) assert.throws(()=>readRecordValues(...args as [string,string,string]));
  assert.equal(readRecordValues('10','25','').interpolation,null);
});

test('KH titration labels keep one decimal from the current confirmed value, including after editing', () => {
  const record = { parameterId: 'kh', khTitration: { displayDkh: '8.0' } };
  assert.equal(recordValueText(8, record), '8.0');
  assert.equal(recordValueText(0, record), '0.0');
  assert.equal(recordValueText(8.1, record), '8.1');
  assert.equal(recordValueText(0.083, { parameterId: 'po4' }), '0.083');
  assert.equal(recordValueText(8, { parameterId: 'kh' }), '8');
});
