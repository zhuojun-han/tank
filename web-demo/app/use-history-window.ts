'use client';

import { useCallback, useEffect, useRef, useState } from 'react';

/** Keep the full scroll range, but mount only nearby records in long histories. */
export function useHistoryWindow(count: number, signature: string) {
  const ref = useRef<HTMLDivElement>(null);
  const [position, setPosition] = useState({ first: Math.max(0, count - 5), offset: 0 });
  const virtual = count > 40;
  const measure = useCallback(() => {
    const el = ref.current;
    if (!el || el.clientWidth === 0 || !virtual) return;
    const offset = el.scrollLeft / el.clientWidth * 350;
    const first = Math.floor(offset / 70);
    setPosition(previous => previous.first === first && previous.offset === offset ? previous : { first, offset });
  }, [virtual]);

  useEffect(() => {
    const el = ref.current;
    if (el) el.scrollLeft = el.scrollWidth;
    const frame = requestAnimationFrame(measure);
    return () => cancelAnimationFrame(frame);
  }, [signature, measure]);
  useEffect(() => {
    const el = ref.current;
    if (!el || !virtual) return;
    const observer = new ResizeObserver(measure);
    observer.observe(el);
    return () => observer.disconnect();
  }, [measure, virtual]);

  const first = Math.min(Math.max(0, count - 5), position.first);
  const start = virtual ? Math.max(0, first - 5) : 0;
  const end = virtual ? Math.min(count, first + 11) : count;
  const move = (direction: number) => {
    const el = ref.current;
    el?.scrollBy({ left: direction * el.clientWidth, behavior: 'smooth' });
  };
  return { ref, start, end, virtual, offset: position.offset, measure, move };
}
