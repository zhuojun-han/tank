'use client';
import { useEffect, useEffectEvent, useState, useSyncExternalStore } from 'react';
import { createCountdownClock, remainingSeconds } from './countdown-clock';

export function useDetectionTimer(running: boolean, onComplete: () => void) {
  const [clock] = useState(() => createCountdownClock());
  const completed = useEffectEvent(onComplete);
  useEffect(() => {
    if (!running) return;
    const deadline = Date.now() + clock.getSnapshot() * 1000;
    let fired = false;
    const tick = () => {
      const left = remainingSeconds(deadline, Date.now());
      clock.set(left);
      if (left === 0 && !fired) { fired = true; completed(); }
    };
    const id = window.setInterval(tick, 250);
    return () => window.clearInterval(id);
  }, [running, clock]);
  return { clock, setTimer: clock.set };
}

export function TimerRing({ clock, total, running, locked, parameterName }: {
  clock: ReturnType<typeof createCountdownClock>; total: number; running: boolean; locked: boolean; parameterName: string;
}) {
  const seconds = useSyncExternalStore(clock.subscribe, clock.getSnapshot, clock.getServerSnapshot);
  return <div className="timer-ring" style={{ '--progress': `${seconds / total * 360}deg` } as React.CSSProperties}>
    <div><strong>{String(Math.floor(seconds / 60)).padStart(2, '0')}:{String(seconds % 60).padStart(2, '0')}</strong>
      <small>{running ? '正在计时' : locked ? '计时已暂停' : `${parameterName} 默认时间`}</small></div>
  </div>;
}
