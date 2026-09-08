import test from 'node:test';
import assert from 'node:assert/strict';
import { createCountdownClock, remainingSeconds } from '../app/countdown-clock.ts';
test('clock only publishes changed displayed seconds and unsubscribes independently', () => {
  const clock = createCountdownClock(10), seen: number[] = [];
  const unsubscribe = clock.subscribe(() => seen.push(clock.getSnapshot()));
  clock.set(10); clock.set(9); clock.set(9); clock.set(8);
  unsubscribe(); clock.set(7);
  assert.deepEqual(seen, [9, 8]);
  assert.equal(clock.getSnapshot(), 7);
});
test('a delayed foreground callback settles elapsed wall time rather than subtracting one tick', () => {
  assert.equal(remainingSeconds(10_000, 100), 10);
  assert.equal(remainingSeconds(10_000, 4300), 6);
  assert.equal(remainingSeconds(10_000, 10_000), 0);
  assert.equal(remainingSeconds(10_000, 90_000), 0);
});
