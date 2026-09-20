export type NativeReply = { version: 1; id: string; ok: boolean; result?: unknown; error?: { code?: string; message?: string } | string };
declare global {
  interface Window {
    LanJiaoNative?: { postMessage(message: string): void };
    __lanjiaoReceive?: (reply: NativeReply) => void;
    __lanjiaoHandleBack?: () => boolean;
  }
}
const pending = new Map<string, { resolve(value: unknown): void; reject(error: Error): void; timer: ReturnType<typeof setTimeout> }>();
export function isNativeApp() { return typeof window !== 'undefined' && location.origin === 'https://appassets.androidplatform.net'; }
export class NativeRequestError extends Error {
  constructor(message: string, public code: string) { super(message); }
}
export function nativeRequest<T>(method: string, params: Record<string, unknown> = {}): Promise<T> {
  if (!isNativeApp() || !window.LanJiaoNative) return Promise.reject(new Error('本机连接尚未就绪，请重新打开应用。'));
  window.__lanjiaoReceive = reply => {
    if (reply.version !== 1) return;
    const call = pending.get(reply.id);
    if (!call) return;
    clearTimeout(call.timer); pending.delete(reply.id);
    if (reply.ok) call.resolve(reply.result);
    else call.reject(new NativeRequestError(typeof reply.error === 'string' ? reply.error : reply.error?.message ?? '本机操作失败。', typeof reply.error === 'string' ? 'operation_failed' : reply.error?.code ?? 'operation_failed'));
  };
  return new Promise<T>((resolve, reject) => {
    const id = crypto.randomUUID();
    const timer = setTimeout(() => { pending.delete(id); reject(new NativeRequestError('操作尚未确认完成，请重新读取数据后重试。', 'timeout')); }, method.startsWith('backup.') ? 180000 : 30000);
    pending.set(id, { resolve: value => resolve(value as T), reject, timer });
    try { window.LanJiaoNative!.postMessage(JSON.stringify({ version: 1, id, method, params })); }
    catch (error) { clearTimeout(timer); pending.delete(id); reject(error); }
  });
}
