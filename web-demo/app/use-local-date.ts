'use client';

import { useEffect, useEffectEvent, useState } from 'react';
import { localCycleDate } from './maintenance-cycle';

/** Refresh at local midnight or when the page resumes, without background polling. */
export function useLocalDate(onChange: (next: string, previous: string) => void): string {
  const [today, setToday] = useState(() => localCycleDate());
  const refresh = useEffectEvent((next: string) => {
    if (next === today) return;
    onChange(next, today);
    setToday(next);
  });
  useEffect(() => {
    let timeout: number;
    const update = () => {
      window.clearTimeout(timeout);
      refresh(localCycleDate());
      if (document.visibilityState === 'hidden') return;
      const now = new Date();
      const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
      timeout = window.setTimeout(update, midnight.getTime() - now.getTime() + 10);
    };
    timeout = window.setTimeout(update, 0);
    window.addEventListener('focus', update);
    document.addEventListener('visibilitychange', update);
    return () => {
      window.clearTimeout(timeout);
      window.removeEventListener('focus', update);
      document.removeEventListener('visibilitychange', update);
    };
  }, []);
  return today;
}
