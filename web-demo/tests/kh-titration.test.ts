import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import contract from '../../contracts/kh-titration.json' with { type: 'json' };
import { calculateKhTitration, KH_TITRATION_TABLE_ID } from '../app/kh-titration.ts';

const near = (actual: number, expected: number) =>
  assert.ok(Math.abs(actual - expected) < 1e-12, `${actual} != ${expected}`);

test('KH table is the single versioned transcription of the supplied photo', () => {
  const image = readFileSync(new URL(`../../${contract.source.path}`, import.meta.url));
  assert.equal(createHash('sha256').update(image).digest('hex'), contract.source.sha256);
  assert.equal(contract.schemaVersion, 1);
  assert.equal(KH_TITRATION_TABLE_ID, contract.contract);
  assert.equal(contract.source.version, 'user-photo-transcription-v1');
  assert.equal(contract.rows.length, 50);
  assert.equal(contract.extrapolation, false);
  for (const [index, row] of contract.rows.entries()) {
    near(row.readingMl, index * 0.02);
    if (index > 0) assert.ok(row.dkh < contract.rows[index - 1].dkh);
  }
});

test('uses actual nonlinear printed values, including both endpoints', () => {
  for (const [reading, dkh, display] of [
    [0, 15.7, '15.7'], [0.02, 15.3, '15.3'], [0.48, 8, '8.0'],
    [0.50, 7.7, '7.7'], [0.98, 0, '0.0'],
  ] as const) {
    const result = calculateKhTitration(1, reading);
    assert.equal(result.dkh, dkh);
    assert.equal(result.displayDkh, display);
    assert.equal(result.interpolated, false);
    assert.equal(result.tableReadingMl, reading);
  }
  for (const row of contract.rows) {
    const result = calculateKhTitration(1, row.readingMl);
    assert.equal(result.dkh, row.dkh);
    assert.equal(result.interpolated, false);
  }
});

test('non-default initial volume uses 1 minus consumed volume, not the remaining reading alone', () => {
  const result = calculateKhTitration(0.8, 0.28);
  assert.equal(result.initialMl, 0.8);
  assert.equal(result.remainingMl, 0.28);
  near(result.usedMl, 0.52);
  assert.equal(result.tableReadingMl, 0.48);
  assert.equal(result.dkh, 8);
  assert.equal(result.displayDkh, '8.0');
  assert.equal(result.interpolated, false);
  const another = calculateKhTitration(0.7, 0.2);
  near(another.usedMl, 0.5);
  assert.equal(another.dkh, 7.7);
  assert.equal(calculateKhTitration(0.02, 0).dkh, 0);
});

test('interpolates only between adjacent rows and preserves the unrounded dKH', () => {
  const middle = calculateKhTitration(1, 0.49);
  near(middle.dkh, 7.85);
  assert.equal(middle.displayDkh, '7.9');
  assert.equal(middle.interpolated, true);
  const nonDefault = calculateKhTitration(0.8, 0.31);
  near(nonDefault.tableReadingMl, 0.51);
  near(nonDefault.dkh, 7.5);
  assert.equal(nonDefault.displayDkh, '7.5');
  assert.equal(nonDefault.interpolated, true);
  near(calculateKhTitration(1, 0.025).dkh, 15.225);
});

test('one decimal rounds half upward despite binary float noise without rounding real values below the boundary up', () => {
  assert.equal(calculateKhTitration(1, 0.03).displayDkh, '15.2');
  assert.equal(calculateKhTitration(1, 0.55).displayDkh, '6.9');
  assert.equal(calculateKhTitration(1, 0.55 + 1e-10).displayDkh, '6.8');
  assert.equal(calculateKhTitration(1, 0.55 - 1e-10).displayDkh, '6.9');
  assert.equal(calculateKhTitration(1, 0.979).displayDkh, '0.0');
  assert.ok(calculateKhTitration(1, 0.979).dkh > 0);
});

test('rejects non-finite volumes and invalid syringe bounds with readable errors', () => {
  for (const invalid of [NaN, Infinity, -Infinity]) {
    assert.throws(() => calculateKhTitration(invalid, 0.3), /有效/);
    assert.throws(() => calculateKhTitration(1, invalid), /有效/);
  }
  for (const initial of [-0.01, 1.01]) {
    assert.throws(() => calculateKhTitration(initial, 0), /初始容积/);
  }
  assert.throws(() => calculateKhTitration(1, -0.01), /剩余溶剂/);
  assert.throws(() => calculateKhTitration(0.5, 0.51), /剩余溶剂/);
});

test('does not invent a 1.00 mL row or extrapolate above the final printed 0.98 mL row', () => {
  for (const [initial, remaining] of [[1, 1], [0, 0], [0.5, 0.5], [1, 0.99], [1, 0.980001], [0.019, 0]]) {
    assert.throws(() => calculateKhTitration(initial, remaining), /0\.00–0\.98 mL.*无法查表/);
  }
});
