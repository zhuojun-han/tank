import { useEffect, useEffectEvent, useRef, useState } from 'react';
import { isNativeApp, nativeRequest } from './native-bridge';
import { isAppVisible, observeAppVisibility } from './app-visibility';
import { createDraftWriteGuard } from './native-draft-guard';

type DraftEnvelope = { version: 1; sections: Record<string, unknown> };
let cached: DraftEnvelope | undefined;
let reading: Promise<DraftEnvelope> | undefined;
let writes: Promise<unknown> = Promise.resolve();
let suspended = false;
const writeGuard = createDraftWriteGuard();
export const protectNativeDraftWrites = writeGuard.protect;
export async function suspendNativeDraftWrites(value: boolean) {
  suspended = value;
  await writes;
}

async function loadDraftEnvelope(): Promise<DraftEnvelope> {
  if (cached) return cached;
  if (!reading) reading = nativeRequest<{ draft: unknown }>('draft.read').then(({ draft }) => {
    const candidate = draft as Partial<DraftEnvelope> | null;
    cached = candidate?.version === 1 && candidate.sections && typeof candidate.sections === 'object' && !Array.isArray(candidate.sections)
      ? candidate as DraftEnvelope : { version: 1, sections: {} };
    return cached;
  }).finally(() => { reading = undefined; });
  return reading;
}

/** Small UI drafts only. Photos use photoDraft.save and store an opaque reference here. */
export async function readNativeDraft<T>(section: string): Promise<T | null> {
  if (!isNativeApp()) return null;
  await writes;
  const envelope = await loadDraftEnvelope();
  return (envelope.sections[section] as T | undefined) ?? null;
}

/** Serialize read/merge/write so independent main-page and photo sections do not overwrite each other. */
export function writeNativeDraft(section: string, value: unknown | null): Promise<void> {
  if (!isNativeApp()) return Promise.resolve();
  if (suspended) return Promise.resolve();
  if (!/^[a-z][a-z0-9-]{0,31}$/.test(section)) return Promise.reject(new Error('草稿名称无效。'));
  const snapshot = writeGuard.apply(section, value === null ? null : structuredClone(value));
  const operation = writes.then(async () => {
    if (suspended) return;
    const envelope = await loadDraftEnvelope();
    const sections = { ...envelope.sections };
    // Also protect snapshots that were queued before a close was confirmed.
    const guarded = writeGuard.apply(section, snapshot);
    if (guarded === null) delete sections[section];
    else sections[section] = guarded;
    const next: DraftEnvelope = { version: 1, sections };
    if (JSON.stringify(next) === JSON.stringify(envelope)) return;
    if (new TextEncoder().encode(JSON.stringify(next)).length > 60 * 1024) throw new Error('草稿内容过大，暂时无法保留。');
    await nativeRequest('draft.save', { draft: next });
    cached = next;
  });
  writes = operation.catch(() => {});
  return operation;
}

/** Call after authoritative backup restore; the native restore already clears its draft file. */
export async function resetNativeDraftCache() {
  await writes;
  cached = undefined;
  reading = undefined;
}

/** Restore once, debounce edits, and flush on native pause. clear() prevents unmount from restoring a discarded draft. */
export function useNativeDraft<T>({ section, value, restore, enabled = true, suspendWrites = false }: {
  section: string; value: T | null; restore: (draft: T) => void; enabled?: boolean; suspendWrites?: boolean;
}) {
  const [loadedSection, setLoadedSection] = useState<string | null>(null);
  const ready = !isNativeApp() || !enabled || loadedSection === section;
  const [error, setError] = useState('');
  const latest = useRef({ section, value, canWrite: false });
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const cleared = useRef(false);
  const restoreValue = useEffectEvent(restore);
  useEffect(() => {
    // Clear the readiness gate on disable before any later re-enable can write.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    if (!isNativeApp() || !enabled) { setLoadedSection(null); return; }
    let active = true;
    cleared.current = false;
    void readNativeDraft<T>(section).then(draft => {
      if (!active) return;
      try { if (draft !== null) restoreValue(draft); }
      catch (caught) { setError((caught as Error).message); }
      setLoadedSection(section);
    }).catch(caught => { if (active) setError((caught as Error).message); });
    return () => { active = false; };
  }, [section, enabled]);
  useEffect(() => { latest.current = { section, value, canWrite: ready && enabled && !suspendWrites }; }, [section, value, ready, enabled, suspendWrites]);
  const persist = useEffectEvent(() => {
    clearTimeout(timer.current);
    if (!isNativeApp() || !enabled || !ready || suspendWrites || cleared.current) return;
    if (latest.current.section !== section || !latest.current.canWrite) return;
    void writeNativeDraft(section, latest.current.value).then(() => setError('')).catch(caught => setError((caught as Error).message));
  });
  useEffect(() => {
    if (!enabled || !ready || !isNativeApp() || suspendWrites || cleared.current) return;
    timer.current = setTimeout(persist, 250);
    return () => { clearTimeout(timer.current); };
  }, [section, value, ready, enabled, suspendWrites]);
  useEffect(() => {
    if (!enabled || !ready || !isNativeApp()) return;
    const stop = observeAppVisibility(() => { if (!isAppVisible()) persist(); });
    return () => {
      stop();
      // A new section can be rendered before the previous effect cleans up.
      // Never flush that section's value under the departing section's key.
      const departing = latest.current;
      if (departing.section === section && departing.canWrite && !cleared.current)
        void writeNativeDraft(section, departing.value).catch(() => {});
    };
  }, [section, ready, enabled]);
  async function clear() {
    cleared.current = true;
    clearTimeout(timer.current);
    try { await writeNativeDraft(section, null); setError(''); }
    catch (caught) { cleared.current = false; throw caught; }
  }
  return { ready, error, clear };
}
