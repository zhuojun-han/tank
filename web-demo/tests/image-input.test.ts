import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile, readdir } from 'node:fs/promises';
import { checkImageDimensions, fitImageDimensions, inspectImageFile, loadImageElement, releaseImage } from '../app/image-input.ts';

function png(width: number, height: number, animated = false) {
  const bytes = Buffer.alloc(animated ? 61 : 41);
  bytes.set([137, 80, 78, 71, 13, 10, 26, 10]);
  bytes.writeUInt32BE(13, 8); bytes.write('IHDR', 12);
  bytes.writeUInt32BE(width, 16); bytes.writeUInt32BE(height, 20);
  if (animated) { bytes.writeUInt32BE(8, 33); bytes.write('acTL', 37); bytes.write('IDAT', 57); }
  else bytes.write('IDAT', 37);
  return new Blob([bytes]);
}
function jpeg(width: number, height: number, marker = 0xc0) {
  const bytes = Buffer.from([0xff, 0xd8, 0xff, marker, 0, 8, 8, 0, 0, 0, 0, 1]);
  bytes.writeUInt16BE(height, 7); bytes.writeUInt16BE(width, 9);
  return new Blob([bytes]);
}
function webp(width: number, height: number, extended = false, animated = false) {
  const bytes = Buffer.alloc(extended ? 44 : 26);
  bytes.write('RIFF', 0); bytes.writeUInt32LE(bytes.length - 8, 4); bytes.write('WEBP', 8);
  if (extended) {
    bytes.write('VP8X', 12); bytes.writeUInt32LE(10, 16); bytes[20] = animated ? 2 : 0;
    bytes.writeUIntLE(width - 1, 24, 3); bytes.writeUIntLE(height - 1, 27, 3);
  }
  const start = extended ? 30 : 12;
  bytes.write('VP8L', start); bytes.writeUInt32LE(5, start + 4); bytes[start + 8] = 0x2f;
  bytes.writeUInt32LE(((width - 1) | ((height - 1) << 14)) >>> 0, start + 9);
  return bytes;
}

test('rejects huge compressed-image headers before any pixel decoding', async () => {
  for (const blob of [png(12000, 12000), jpeg(12000, 12000), new Blob([webp(12000, 12000, true)])]) {
    assert.ok(blob.size < 100);
    await assert.rejects(inspectImageFile(blob), /尺寸过大/);
  }
  assert.deepEqual(checkImageDimensions(6000, 4000), { width: 6000, height: 4000 });
  assert.throws(() => checkImageDimensions(16385, 1), /尺寸过大/);
  assert.throws(() => checkImageDimensions(0, 1), /尺寸无效/);
});

test('recognizes actual PNG, baseline/progressive JPEG and WebP headers independent of MIME', async () => {
  for (const blob of [png(640, 480), jpeg(640, 480), jpeg(640, 480, 0xc2), new Blob([webp(640, 480)]), new Blob([webp(640, 480, true)])]) {
    assert.deepEqual(await inspectImageFile(blob), { width: 640, height: 480 });
  }
  await assert.rejects(inspectImageFile(new Blob(['<svg width="100" height="100"/>'], { type: 'image/png' })), /格式或尺寸无法读取/);
});

test('animated PNG/WebP and conflicting WebP canvas/frame dimensions cannot evade the budget', async () => {
  await assert.rejects(inspectImageFile(png(640, 480, true)), /静态图片/);
  await assert.rejects(inspectImageFile(new Blob([webp(640, 480, true, true)])), /静态图片/);
  const conflicting = webp(640, 480, true); conflicting.writeUIntLE(10, 24, 3);
  await assert.rejects(inspectImageFile(new Blob([conflicting])), /格式或尺寸无法读取/);
});

test('header inspection reads at most one MB and fails closed for missing dimensions', async () => {
  const reads: number[] = [];
  class TrackedBlob extends Blob {
    override slice(start?: number, end?: number) { reads.push(end ?? 0); return super.slice(start, end); }
  }
  const source = new TrackedBlob([Buffer.alloc(2 * 1024 * 1024)], { type: 'image/jpeg' });
  await assert.rejects(inspectImageFile(source), /格式或尺寸无法读取/);
  assert.deepEqual(reads, [1024 * 1024]);
  for (const bytes of [[], [0xff, 0xd8, 0xff, 0xc0], [82, 73, 70, 70]]) {
    await assert.rejects(inspectImageFile(new Blob([new Uint8Array(bytes)])), /格式或尺寸无法读取/);
  }
});

test('all shipped JPG, PNG and WebP samples/artwork still pass the dimension guard', async () => {
  const root = new URL('../public/', import.meta.url);
  const paths = await readdir(root, { recursive: true });
  const images = paths.filter(path => /\.(jpe?g|png|webp)$/i.test(path));
  assert.ok(images.length >= 15);
  for (const path of images) {
    const size = await inspectImageFile(new Blob([await readFile(new URL(path.replaceAll('\\', '/'), root))]));
    assert.ok(size.width > 0 && size.height > 0, path);
  }
});

test('thin photos always retain at least one output pixel after downscaling/rotation', () => {
  assert.deepEqual(fitImageDimensions(4096, 1, 1600), { width: 1600, height: 1 });
  assert.deepEqual(fitImageDimensions(1, 4096, 1600), { width: 1, height: 1600 });
  assert.deepEqual(fitImageDimensions(4000, 3000, 1600), { width: 1600, height: 1200 });
});

test('cancelled and failed decodes detach handlers and source; settled images can be released', async () => {
  const OriginalImage = globalThis.Image;
  const instances: FakeImage[] = [];
  class FakeImage {
    src = '';
    onload: (() => void) | null = null;
    onerror: (() => void) | null = null;
    constructor() { instances.push(this); }
    removeAttribute(name: string) { if (name === 'src') this.src = ''; }
  }
  globalThis.Image = FakeImage as unknown as typeof Image;
  try {
    const controller = new AbortController();
    const pending = loadImageElement('blob:pending', controller.signal);
    controller.abort();
    await assert.rejects(pending, { name: 'AbortError' });
    assert.equal(instances[0].src, ''); assert.equal(instances[0].onload, null); assert.equal(instances[0].onerror, null);
    const failed = loadImageElement('blob:failed'); instances[1].onerror?.();
    await assert.rejects(failed, /图片无法打开/); assert.equal(instances[1].src, '');
    const success = loadImageElement('blob:success'); instances[2].onload?.();
    const image = await success; releaseImage(image); assert.equal(image.src, '');
    await assert.rejects(loadImageElement('blob:already-cancelled', controller.signal), { name: 'AbortError' });
    assert.equal(instances[3].src, '');
  } finally { globalThis.Image = OriginalImage; }
});
