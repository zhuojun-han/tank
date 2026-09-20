import { checkImageDimensions, fitImageDimensions, loadImageElement, releaseImage } from '../image-input';
import { nativeRequest } from '../native-bridge';
import { readNativeDraft, writeNativeDraft } from '../native-drafts';
import { validRect, type Rect } from './color-analysis';

export type NativePhotoDraft = {
  tankId: string; parameterId: 'no3' | 'po4'; photoToken: string; photoUrl: string;
  rotation: number; card: Rect; liquid: Rect; cardReady: boolean; liquidReady: boolean;
  swatchRects: Rect[]; compared: boolean; mode: string; sourceName: string;
};

export function isNativePhotoDraft(value: unknown): value is NativePhotoDraft {
  if (!value || typeof value !== 'object') return false;
  const draft = value as NativePhotoDraft;
  return typeof draft.tankId === 'string' && draft.tankId.length > 0
    && ['no3', 'po4'].includes(draft.parameterId)
    && typeof draft.photoToken === 'string' && /^[0-9a-f-]{36}$/i.test(draft.photoToken)
    && draft.photoUrl === `https://appassets.androidplatform.net/native-photo/${draft.photoToken}.jpg`
    && [0, 90, 180, 270].includes(draft.rotation)
    && validDraftRect(draft.card) && validDraftRect(draft.liquid)
    && typeof draft.cardReady === 'boolean' && typeof draft.liquidReady === 'boolean'
    && typeof draft.compared === 'boolean' && typeof draft.sourceName === 'string' && draft.sourceName.length <= 512
    && ['card', 'liquid', '0', '1', '2', '3', '4', '5', '6', '7'].includes(draft.mode)
    && Array.isArray(draft.swatchRects) && [0, 8].includes(draft.swatchRects.length) && draft.swatchRects.every(validDraftRect);
}

function validDraftRect(value: unknown): value is Rect {
  return !!value && typeof value === 'object' && validRect(value as Rect);
}

/** Analyze the cached JPEG immediately too, so restoring does not introduce another compression pass. */
export async function cacheNativePhoto(file: File, tankId: string, signal: AbortSignal) {
  const source = URL.createObjectURL(file);
  const canvas = document.createElement('canvas');
  let image: HTMLImageElement | undefined;
  try {
    image = await loadImageElement(source, signal);
    checkImageDimensions(image.naturalWidth, image.naturalHeight);
    const size = fitImageDimensions(image.naturalWidth, image.naturalHeight, 1600);
    canvas.width = size.width; canvas.height = size.height;
    const context = canvas.getContext('2d');
    if (!context) throw new Error('暂时无法读取照片。');
    context.drawImage(image, 0, 0, canvas.width, canvas.height);
    releaseImage(image); image = undefined;
    let dataUrl = '';
    for (const quality of [.94, .88, .8]) {
      dataUrl = canvas.toDataURL('image/jpeg', quality);
      if (dataUrl.length <= 2 * 1024 * 1024 * 4 / 3) break;
    }
    if (dataUrl.length > 2 * 1024 * 1024 * 4 / 3) throw new Error('照片处理后仍过大，请裁剪后重试。');
    signal.throwIfAborted();
    const result = await nativeRequest<{ photoToken: string; photoUrl: string }>('photoDraft.save', { tankId, dataUrl });
    if (signal.aborted) { await nativeRequest('photoDraft.remove', { tankId, photoToken: result.photoToken }); signal.throwIfAborted(); }
    return result;
  } finally {
    if (image) releaseImage(image);
    URL.revokeObjectURL(source);
    canvas.width = 0; canvas.height = 0;
  }
}

export async function removeNativePhoto(draft: Pick<NativePhotoDraft, 'tankId' | 'photoToken'>) {
  await nativeRequest('photoDraft.remove', { tankId: draft.tankId, photoToken: draft.photoToken });
}

/** Use when explicitly abandoning a tank's detection or replacing data from backup. */
export async function clearNativePhotoDraft(tankId?: string) {
  const draft = await readNativeDraft<NativePhotoDraft>('photo');
  if (draft === null || (tankId !== undefined && draft.tankId !== tankId)) return;
  await writeNativeDraft('photo', null);
  if (isNativePhotoDraft(draft)) await removeNativePhoto(draft);
}
