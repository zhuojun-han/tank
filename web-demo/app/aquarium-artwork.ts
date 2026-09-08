import {
  isFishArtworkDataUrl,
  MAX_FISH_ARTWORK_DATA_URL_LENGTH,
  MAX_FISH_ARTWORK_INPUT_BYTES,
} from "./aquarium-data";

const ALLOWED_ARTWORK_TYPES = new Set(["image/png", "image/jpeg", "image/webp"]);

function loadArtworkImage(file: File) {
  return new Promise<HTMLImageElement>((resolve, reject) => {
    const objectUrl = URL.createObjectURL(file);
    const image = new Image();
    image.onload = () => {
      URL.revokeObjectURL(objectUrl);
      resolve(image);
    };
    image.onerror = () => {
      URL.revokeObjectURL(objectUrl);
      reject(new Error("图片无法读取，请换一张 PNG、JPG 或 WebP。"));
    };
    image.src = objectUrl;
  });
}

function renderArtwork(
  image: HTMLImageElement,
  width: number,
  quality: number,
) {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = Math.round(width * 50 / 88);
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
}

export async function prepareFishArtwork(file: File) {
  if (!ALLOWED_ARTWORK_TYPES.has(file.type)) {
    throw new Error("只支持 PNG、JPG 或 WebP 图片。");
  }
  if (file.size <= 0 || file.size > MAX_FISH_ARTWORK_INPUT_BYTES) {
    throw new Error("原图不能超过 8 MB。");
  }

  const image = await loadArtworkImage(file);
  if (!image.naturalWidth || !image.naturalHeight) {
    throw new Error("图片尺寸无效。");
  }

  for (const [width, quality] of [[512, 0.84], [384, 0.74], [300, 0.66]] as const) {
    const dataUrl = renderArtwork(image, width, quality);
    if (isFishArtworkDataUrl(dataUrl) && dataUrl.length <= MAX_FISH_ARTWORK_DATA_URL_LENGTH) {
      return dataUrl;
    }
  }
  throw new Error("压缩后图片仍然过大，请选择背景更简单的立绘。");
}
