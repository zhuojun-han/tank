import { loadDemoState, saveDemoState, validateDemoState, type DemoState } from './demo-storage';
import { isNativeApp, nativeRequest, NativeRequestError } from './native-bridge';

export type NativeStateEnvelope = { revision: number; state: DemoState };
let envelope: NativeStateEnvelope | undefined;
let persisted = '';
let operations: Promise<unknown> = Promise.resolve();
let uncertain = false;
let writing = 0;
function busy(delta: number) {
  writing += delta;
  window.dispatchEvent(new CustomEvent('lanjiao:storage-busy', { detail: writing > 0 }));
}
function accept(value: NativeStateEnvelope) {
  if (!Number.isSafeInteger(value.revision) || !value.state || !Array.isArray(value.state.tanks)) throw new Error('本机返回的数据格式异常。');
  if (value.state.tanks.length) validateDemoState(value.state);
  envelope = value;
  persisted = JSON.stringify(value.state);
  return value.state;
}
function enqueue<T>(work: () => Promise<T>, changesData: boolean): Promise<T> {
  if (changesData) busy(1);
  const operation = operations.then(work);
  operations = operation.catch(() => {});
  return operation.catch(error => {
    if (!(error instanceof NativeRequestError && error.code === 'invalid_input')) uncertain = true;
    throw error;
  }).finally(() => { if (changesData) busy(-1); });
}
export function nativeStateCommand(method: string, params: Record<string, unknown>) {
  return enqueue(async () => {
    if (!envelope || uncertain) throw new Error('请先重新读取本机数据。');
    return accept(await nativeRequest<NativeStateEnvelope>(method, { ...params, expectedRevision: envelope.revision }));
  }, true);
}
export function readNativeState() {
  return enqueue(async () => {
    const result = accept(await nativeRequest<NativeStateEnvelope>('state.read'));
    uncertain = false;
    return result;
  }, false);
}
export async function prepareNativeRestore() {
  await operations;
  uncertain = true;
}
export async function prepareNativeRemoval() {
  await operations;
  if (!envelope || uncertain) throw new Error('请重新读取本机数据后再删除。');
  uncertain = true;
  return envelope.revision;
}
export async function loadApplicationState(defaults: DemoState) {
  if (!isNativeApp()) return loadDemoState(() => window.localStorage, defaults);
  if (!envelope) throw new Error('本机数据尚未读取。');
  return { state: envelope.state, blocked: false, message: '' };
}
export async function saveApplicationState(state: DemoState): Promise<{ ok: true; state?: DemoState } | { ok: false; message: string }> {
  if (!isNativeApp()) return saveDemoState(() => window.localStorage, state);
  const snapshot = structuredClone(state);
  try {
    const committed = await enqueue(async () => {
      if (!envelope || uncertain) throw new Error('请重新读取本机数据后再保存，避免覆盖未确认的更改。');
      validateDemoState(snapshot);
      const encoded = JSON.stringify(snapshot);
      if (encoded === persisted) return envelope.state;
      return accept(await nativeRequest<NativeStateEnvelope>('state.save', { state: snapshot, expectedRevision: envelope.revision }));
    }, true);
    return { ok: true, state: committed };
  } catch (error) {
    return { ok: false, message: error instanceof Error ? error.message : '保存失败，请重新读取本机数据。' };
  }
}
