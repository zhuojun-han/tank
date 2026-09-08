// Bound the decoded source before handing compressed bytes to the browser.
// 24 MP is 96 MB for one RGBA surface; output canvases have smaller limits.
export const MAX_IMAGE_PIXELS = 24_000_000;
export const MAX_IMAGE_EDGE = 16_384;
const MAX_HEADER_BYTES = 1024 * 1024;
type ImageSize = { width: number; height: number };

export function releaseImage(image: HTMLImageElement) {
  image.onload = null;
  image.onerror = null;
  image.removeAttribute("src");
}

export function loadImageElement(src: string, signal?: AbortSignal): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    const detach = () => {
      image.onload = null;
      image.onerror = null;
      signal?.removeEventListener("abort", abort);
    };
    const abort = () => {
      detach();
      releaseImage(image);
      reject(new DOMException("图片处理已取消。", "AbortError"));
    };
    image.onload = () => { detach(); resolve(image); };
    image.onerror = () => {
      detach();
      releaseImage(image);
      reject(new Error("图片无法打开，请换一张 JPG、PNG 或 WebP。"));
    };
    signal?.addEventListener("abort", abort, { once: true });
    if (signal?.aborted) abort();
    else image.src = src;
  });
}

export function checkImageDimensions(width: number, height: number): ImageSize {
  if (!Number.isInteger(width) || !Number.isInteger(height) || width <= 0 || height <= 0) {
    throw new Error("图片尺寸无效。");
  }
  if (width > MAX_IMAGE_EDGE || height > MAX_IMAGE_EDGE || width * height > MAX_IMAGE_PIXELS) {
    throw new Error("图片尺寸过大，请先缩小后重试（最多 2400 万像素）。");
  }
  return { width, height };
}

export function fitImageDimensions(width: number, height: number, edge: number): ImageSize {
  const scale = Math.min(1, edge / Math.max(width, height));
  return { width: Math.max(1, Math.round(width * scale)), height: Math.max(1, Math.round(height * scale)) };
}

// Only inspect a bounded header, never inflate pixels or trust the file's MIME.
// JPEG metadata beyond this budget is rejected instead of decoding unchecked.
export async function inspectImageFile(file: Blob): Promise<ImageSize> {
  const bytes = new Uint8Array(await file.slice(0, MAX_HEADER_BYTES).arrayBuffer());
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const tag = (offset: number) => String.fromCharCode(...bytes.subarray(offset, offset + 4));
  const invalid = () => new Error("图片格式或尺寸无法读取，请换一张 JPG、PNG 或 WebP。");
  const animated = () => new Error("请选择静态图片。");
  if (bytes.length >= 33 && [137, 80, 78, 71, 13, 10, 26, 10].every((value, i) => bytes[i] === value)) {
    if (tag(12) !== "IHDR" || view.getUint32(8) !== 13) throw invalid();
    const size = checkImageDimensions(view.getUint32(16), view.getUint32(20));
    // acTL must precede IDAT. Reject animations so frames cannot multiply the
    // decoded memory budget (the UI only needs a single still photograph).
    for (let offset = 33; offset + 8 <= bytes.length;) {
      const chunk = tag(offset + 4);
      if (chunk === "acTL") throw animated();
      if (chunk === "IDAT") return size;
      const next = offset + 12 + view.getUint32(offset);
      if (next > bytes.length) throw invalid();
      offset = next;
    }
    throw invalid();
  }
  if (bytes.length >= 4 && bytes[0] === 0xff && bytes[1] === 0xd8) {
    for (let offset = 2; offset + 4 <= bytes.length;) {
      if (bytes[offset++] !== 0xff) throw invalid();
      while (bytes[offset] === 0xff) offset++;
      const marker = bytes[offset++];
      if (marker === 0xda || marker === 0xd9 || offset + 2 > bytes.length) throw invalid();
      const length = view.getUint16(offset);
      if (length < 2 || offset + length > bytes.length) throw invalid();
      if (marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker)) {
        if (length < 8) throw invalid();
        return checkImageDimensions(view.getUint16(offset + 5), view.getUint16(offset + 3));
      }
      offset += length;
    }
    throw invalid();
  }
  if (bytes.length >= 20 && tag(0) === "RIFF" && tag(8) === "WEBP") {
    const tag24 = (offset: number) => bytes[offset] | bytes[offset + 1] << 8 | bytes[offset + 2] << 16;
    let canvasSize: ImageSize | undefined;
    for (let chunkStart = 12; chunkStart + 8 <= bytes.length;) {
      const chunk = tag(chunkStart), length = view.getUint32(chunkStart + 4, true), offset = chunkStart + 8;
      if (chunk === "ANIM" || chunk === "ANMF") throw animated();
      if (chunk === "VP8X") {
        if (length !== 10 || offset + 10 > bytes.length) throw invalid();
        if (bytes[offset] & 0x02) throw animated();
        canvasSize = checkImageDimensions(tag24(offset + 4) + 1, tag24(offset + 7) + 1);
      }
      let imageSize: ImageSize | undefined;
      if (chunk === "VP8 " && length >= 10 && offset + 10 <= bytes.length && bytes[offset + 3] === 0x9d && bytes[offset + 4] === 1 && bytes[offset + 5] === 0x2a) {
        imageSize = checkImageDimensions(view.getUint16(offset + 6, true) & 0x3fff, view.getUint16(offset + 8, true) & 0x3fff);
      }
      if (chunk === "VP8L" && length >= 5 && offset + 5 <= bytes.length && bytes[offset] === 0x2f) {
        const packed = view.getUint32(offset + 1, true);
        imageSize = checkImageDimensions((packed & 0x3fff) + 1, ((packed >>> 14) & 0x3fff) + 1);
      }
      if (imageSize) {
        if (canvasSize && (canvasSize.width !== imageSize.width || canvasSize.height !== imageSize.height)) throw invalid();
        return imageSize;
      }
      const next = offset + length + (length % 2);
      if (next > bytes.length) throw invalid();
      chunkStart = next;
    }
  }
  throw invalid();
}
