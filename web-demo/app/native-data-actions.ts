import type { EntityId } from './entity-id';
import { nativeRequest } from './native-bridge';
import { prepareNativeRemoval } from './application-storage';
import { resetNativeDraftCache, suspendNativeDraftWrites } from './native-drafts';

export async function removeNativeData(tankId?: EntityId) {
  let message = '';
  try {
    const expectedRevision = await prepareNativeRemoval();
    await suspendNativeDraftWrites(true);
    const result = await nativeRequest<{ removed: boolean; warnings?: string[] }>(
      tankId === undefined ? 'data.reset' : 'data.deleteTank',
      { confirmed: true, expectedRevision, ...(tankId === undefined ? {} : { tankId: String(tankId) }) },
    );
    if (!result.removed) throw new Error('删除未完成，请重新读取数据。');
    message = result.warnings?.join(' ') ?? '';
  } catch (error) {
    message = `${(error as Error).message} 请核对重新读取后的数据。`;
  }
  // A lost reply can mean the deletion committed. Never resume the old page's
  // autosave against a freshly read revision and resurrect its stale snapshot.
  await resetNativeDraftCache().catch(() => {});
  try { if (message) sessionStorage.setItem('lanjiao-removal-warning', message); }
  catch { /* Reload remains required even if optional UI storage is unavailable. */ }
  window.location.reload();
}
