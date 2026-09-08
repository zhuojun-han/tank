/** Only subscribers to the clock refresh; the surrounding page does not tick. */
export function createCountdownClock(initial = 300) {
  let value = initial;
  const listeners = new Set<() => void>();
  return {
    getSnapshot: () => value,
    getServerSnapshot: () => initial,
    subscribe(listener: () => void) { listeners.add(listener); return () => { listeners.delete(listener); }; },
    set(next: number) {
      if (value === next) return;
      value = next;
      listeners.forEach(listener => listener());
    },
  };
}
export function remainingSeconds(deadlineMs: number, nowMs: number) {
  return Math.max(0, Math.ceil((deadlineMs - nowMs) / 1000));
}
