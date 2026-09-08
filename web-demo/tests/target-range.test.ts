import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { Target } from '../app/demo-state.ts';
import { calculatorTargetDefault, createParameterTarget, DEFAULT_KH_TARGET_RANGE, initializeKhTargetRanges } from '../app/target-range.ts';

test('new KH targets use 7–9 while other parameters remain unset', () => {
  assert.deepEqual(DEFAULT_KH_TARGET_RANGE, { min: 7, max: 9 });
  assert.deepEqual(createParameterTarget(12, 'kh'), { tankId: 12, parameterId: 'kh', min: 7, max: 9 });
  for (const parameterId of ['no3', 'po4', 'custom-1']) {
    assert.deepEqual(createParameterTarget(9, parameterId), { tankId: 9, parameterId, min: null, max: null });
  }
  const changed = createParameterTarget(12, 'kh');
  changed.min = 6;
  assert.equal(createParameterTarget(13, 'kh').min, 7);
});

test('initialization fills only enabled KH with two null bounds, leaves input untouched and is idempotent', () => {
  const targets: readonly Target[] = Object.freeze([
    Object.freeze({ tankId: 1, parameterId: 'kh', min: null, max: null }),
    Object.freeze({ tankId: 2, parameterId: 'kh', min: 7.8, max: 8.2 }),
    Object.freeze({ tankId: 3, parameterId: 'kh', min: 7, max: null }),
    Object.freeze({ tankId: 4, parameterId: 'kh', min: null, max: 9 }),
    Object.freeze({ tankId: 5, parameterId: 'kh', min: 0, max: 0 }),
    Object.freeze({ tankId: 6, parameterId: 'po4', min: null, max: null }),
  ]);
  const initialized = initializeKhTargetRanges(targets);
  assert.notEqual(initialized, targets);
  assert.equal(initialized.length, targets.length);
  assert.deepEqual(initialized[0], { tankId: 1, parameterId: 'kh', min: 7, max: 9 });
  assert.deepEqual(targets[0], { tankId: 1, parameterId: 'kh', min: null, max: null });
  for (let index = 1; index < targets.length; index++) assert.equal(initialized[index], targets[index]);
  assert.deepEqual(initializeKhTargetRanges(initialized), initialized);
  assert.deepEqual(initializeKhTargetRanges([]), []);
  assert.deepEqual(initializeKhTargetRanges([targets[5]]), [targets[5]]);
});

test('unset targets use fallback values, while one-sided ranges require user input', () => {
  assert.equal(calculatorTargetDefault('po4'), 0.03);
  assert.equal(calculatorTargetDefault('kh'), 8);
  for (const parameterId of ['po4', 'kh'] as const) {
    assert.equal(calculatorTargetDefault(parameterId, { min: null, max: null }), parameterId === 'kh' ? 8 : 0.03);
    for (const target of [{ min: 0, max: null }, { min: null, max: 0 }, { min: 7, max: null }, { min: null, max: 9 }]) {
      assert.equal(calculatorTargetDefault(parameterId, target), '');
    }
  }
});

test('complete ranges use exact decimal midpoints without clamping PO4 to 0.03', () => {
  assert.equal(calculatorTargetDefault('po4', { min: 0.03, max: 0.1 }), 0.065);
  assert.equal(calculatorTargetDefault('kh', { min: 7, max: 9 }), 8);
  assert.equal(calculatorTargetDefault('kh', { min: 7.8, max: 7.81 }), 7.805);
  assert.equal(calculatorTargetDefault('po4', { min: 0.01, max: 0.02 }), 0.015);
  assert.equal(calculatorTargetDefault('po4', { min: 0, max: 0 }), 0);
});

test('midpoints preserve meaningful precision and remain finite for large finite bounds', () => {
  const precise = 1.2345678901234567;
  assert.equal(calculatorTargetDefault('kh', { min: precise, max: precise }), precise);
  assert.equal(calculatorTargetDefault('kh', { min: 1.23456789012345, max: 1.23456789012347 }), 1.23456789012346);
  assert.equal(calculatorTargetDefault('po4', { min: 1e-200, max: 3e-200 }), 2e-200);
  assert.equal(calculatorTargetDefault('kh', { min: Number.MAX_VALUE, max: Number.MAX_VALUE }), Number.MAX_VALUE);
});

test('negative, non-finite, reversed and malformed boundaries never become calculator defaults', () => {
  const invalid = [
    { min: -1, max: 9 }, { min: 0, max: -1 }, { min: 9, max: 7 },
    { min: NaN, max: 9 }, { min: 7, max: Infinity }, { min: -Infinity, max: 9 },
    { min: NaN, max: null }, { min: null, max: Infinity },
    { min: undefined, max: 9 }, { min: '7', max: 9 },
  ];
  for (const parameterId of ['po4', 'kh'] as const) {
    for (const target of invalid) {
      assert.equal(calculatorTargetDefault(parameterId, target as Pick<Target, 'min' | 'max'>), '');
    }
  }
});
