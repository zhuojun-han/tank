import {
  isFishArtworkDataUrl,
  MAX_FISH_ARTWORK_DATA_URL_LENGTH,
  MAX_FISH_ARTWORK_INPUT_BYTES,
} from "./aquarium-data";
import { checkImageDimensions, inspectImageFile, loadImageElement, releaseImage } from "./image-input";

const ALLOWED_ARTWORK_TYPES = new Set(["image/png", "image/jpeg", "image/webp"]);

function renderArtwork(
  image: HTMLImageElement,
  width: number,
  quality: number,
) {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = Math.round(width * 50 / 88);
  try {
    const context = canvas.getContext("2d");
    if (!context) throw new Error("当前浏览器无法处理上传图片。");

    const padding = Math.round(width * 0.035);
    const availableWidth = canvas.width - padding * 2;
    const availableHeight = canvas.height - padding * 2;
    const scale = Math.min(availableWidth / image.naturalWidth, availableHeight / image.naturalHeight);
    const drawWidth = Math.max(1, image.naturalWidth * scale);
    const drawHeight = Math.max(1, image.naturalHeight * scale);
    const x = (canvas.width - drawWidth) / 2;
    const y = (canvas.height - drawHeight) / 2;
    context.clearRect(0, 0, canvas.width, canvas.height);
    context.drawImage(image, x, y, drawWidth, drawHeight);
    return canvas.toDataURL("image/webp", quality);
  } finally {
    canvas.width = 0;
    canvas.height = 0;
  }
}

export async function prepareFishArtwork(file: File, signal?: AbortSignal) {
  if (!ALLOWED_ARTWORK_TYPES.has(file.type)) {
    throw new Error("只支持 PNG、JPG 或 WebP 图片。");
  }
  if (file.size <= 0 || file.size > MAX_FISH_ARTWORK_INPUT_BYTES) {
    throw new Error("原图不能超过 8 MB。");
  }

  signal?.throwIfAborted();
  await inspectImageFile(file);
  signal?.throwIfAborted();
  const objectUrl = URL.createObjectURL(file);
  let image: HTMLImageElement | undefined;
  try {
    image = await loadImageElement(objectUrl, signal);
    signal?.throwIfAborted();
    checkImageDimensions(image.naturalWidth, image.naturalHeight);
    for (const [width, quality] of [[512, 0.84], [384, 0.74], [300, 0.66]] as const) {
      const dataUrl = renderArtwork(image, width, quality);
      if (isFishArtworkDataUrl(dataUrl) && dataUrl.length <= MAX_FISH_ARTWORK_DATA_URL_LENGTH) {
        return dataUrl;
      }
    }
    throw new Error("压缩后图片仍然过大，请选择背景更简单的立绘。");
  } finally {
    if (image) releaseImage(image);
    URL.revokeObjectURL(objectUrl);
  }
}
