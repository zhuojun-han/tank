import assert from 'node:assert/strict';
import { launchBrowser, baseURL } from './browser-support.mjs';

// Synthetic oversized headers are rejected without allocating the stated pixels.
const hugePng = Buffer.alloc(41);
hugePng.set([137, 80, 78, 71, 13, 10, 26, 10]);
hugePng.writeUInt32BE(13, 8); hugePng.write('IHDR', 12);
hugePng.writeUInt32BE(12000, 16); hugePng.writeUInt32BE(12000, 20); hugePng.write('IDAT', 37);
const browser = await launchBrowser();
try {
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  await page.addInitScript(() => {
    const probe = window.__imageProbe = { activeUrls: new Set(), images: [], canvases: [], holdHeader: false, releaseHeader: null, failCanvas: false };
    const createUrl = URL.createObjectURL.bind(URL), revokeUrl = URL.revokeObjectURL.bind(URL);
    URL.createObjectURL = value => { const url = createUrl(value); probe.activeUrls.add(url); return url; };
    URL.revokeObjectURL = url => { probe.activeUrls.delete(url); revokeUrl(url); };
    const OriginalImage = window.Image;
    window.Image = function (...args) { const image = new OriginalImage(...args); probe.images.push(image); return image; };
    window.Image.prototype = OriginalImage.prototype;
    const createElement = document.createElement.bind(document);
    document.createElement = (...args) => { const element = createElement(...args); if (args[0] === 'canvas') probe.canvases.push(element); return element; };
    const getContext = HTMLCanvasElement.prototype.getContext;
    HTMLCanvasElement.prototype.getContext = function (...args) {
      if (probe.failCanvas && args[0] === '2d') { probe.failCanvas = false; return null; }
      return getContext.apply(this, args);
    };
    const arrayBuffer = Blob.prototype.arrayBuffer;
    Blob.prototype.arrayBuffer = async function () {
      if (probe.holdHeader) { probe.holdHeader = false; await new Promise(resolve => { probe.releaseHeader = resolve; }); }
      return arrayBuffer.call(this);
    };
  });
  const ready = () => page.getByRole('button', { name: '↷ 顺时针90°', exact: true }).waitFor({ state: 'visible' }).then(() => page.waitForFunction(() => ![...document.querySelectorAll('button')].find(button => button.textContent === '↷ 顺时针90°').disabled));
  const resources = () => page.evaluate(() => ({ urls: window.__imageProbe.activeUrls.size, activeImages: window.__imageProbe.images.filter(image => image.getAttribute('src')).length, activeCanvases: window.__imageProbe.canvases.filter(canvas => canvas.width && canvas.height).length }));
  for (const route of ['color-match', 'po4-color-match']) {
    await page.goto(`${baseURL}/${route}`); await ready();
    assert.deepEqual(await resources(), { urls: 1, activeImages: 0, activeCanvases: 0 });
    const decodes = await page.evaluate(() => window.__imageProbe.images.length);
    await page.locator('input[type=file]').setInputFiles({ name: 'oversized.png', mimeType: 'image/png', buffer: hugePng });
    await page.getByRole('alert').filter({ hasText: '图片尺寸过大' }).waitFor();
    assert.equal(await page.evaluate(() => window.__imageProbe.images.length), decodes);
    assert.deepEqual(await resources(), { urls: 1, activeImages: 0, activeCanvases: 0 });
    await page.locator('input[type=file]').setInputFiles({ name: 'fake.png', mimeType: 'image/png', buffer: Buffer.from('<svg width="1" height="1"/>') });
    await page.getByRole('alert').filter({ hasText: '图片格式或尺寸无法读取' }).waitFor();
    const thin = await page.evaluate(() => {
      const canvas = document.createElement('canvas'); canvas.width = 4096; canvas.height = 1;
      const context = canvas.getContext('2d'); context.fillStyle = '#3388aa'; context.fillRect(0, 0, 4096, 1);
      const base64 = canvas.toDataURL('image/png').split(',')[1]; canvas.width = 0; canvas.height = 0; return base64;
    });
    for (let i = 0; i < 3; i++) {
      await page.locator('input[type=file]').setInputFiles({ name: `thin-${i}.png`, mimeType: 'image/png', buffer: Buffer.from(thin, 'base64') });
      await ready();
      assert.deepEqual(await page.locator('.cm-photo img').evaluate(async image => { await image.decode(); return [image.naturalWidth, image.naturalHeight]; }), [1600, 1]);
      assert.deepEqual(await resources(), { urls: 2, activeImages: 0, activeCanvases: 0 });
    }
    await page.getByRole('button', { name: '↷ 顺时针90°', exact: true }).click(); await ready();
    assert.deepEqual(await page.locator('.cm-photo img').evaluate(async image => { await image.decode(); return [image.naturalWidth, image.naturalHeight]; }), [1, 1600]);
    assert.deepEqual(await resources(), { urls: 2, activeImages: 0, activeCanvases: 0 });
    await page.evaluate(() => { window.__imageProbe.failCanvas = true; });
    await page.getByRole('button', { name: '使用你的示例照片' }).click();
    await page.getByRole('alert').filter({ hasText: '浏览器无法读取图片像素' }).waitFor();
    assert.equal(await page.getByRole('button', { name: '选择照片 / 拍照' }).isEnabled(), true);
    assert.deepEqual(await resources(), { urls: 1, activeImages: 0, activeCanvases: 0 });
    await page.getByRole('button', { name: '使用你的示例照片' }).click(); await ready();
    assert.deepEqual(await resources(), { urls: 1, activeImages: 0, activeCanvases: 0 });
  }
  await page.goto(`${baseURL}/`);
  await page.waitForFunction(() => localStorage.getItem('reef-demo-state-v10'));
  const originalStorage = await page.evaluate(() => localStorage.getItem('reef-demo-state-v10'));
  const openFish = async () => {
    await page.getByRole('button', { name: /编辑 .* 的鱼类档案/ }).click();
    await page.getByRole('tab', { name: '添加其他鱼种' }).click();
  };
  await openFish();
  await page.locator('.artwork-upload input').setInputFiles({ name: 'oversized.png', mimeType: 'image/png', buffer: hugePng });
  await page.getByRole('alert').filter({ hasText: '图片尺寸过大' }).waitFor();
  assert.deepEqual(await resources(), { urls: 0, activeImages: 0, activeCanvases: 0 });
  await page.evaluate(() => { window.__imageProbe.holdHeader = true; });
  await page.locator('.artwork-upload input').setInputFiles('public/fish-species/clownfish.webp');
  await page.waitForFunction(() => typeof window.__imageProbe.releaseHeader === 'function');
  await page.locator('.fish-manager-sheet .section-head button').click();
  await openFish();
  await page.locator('.artwork-upload input').setInputFiles('public/fish-species/ecsenius-midas.webp');
  const preview = page.getByRole('img', { name: '自定义鱼种立绘预览' }).locator('img');
  await preview.waitFor();
  const beforeRelease = await preview.getAttribute('src');
  await page.evaluate(async () => { window.__imageProbe.releaseHeader(); await new Promise(resolve => setTimeout(resolve, 30)); });
  assert.equal(await preview.getAttribute('src'), beforeRelease);
  assert.deepEqual(await resources(), { urls: 0, activeImages: 0, activeCanvases: 0 });
  await page.locator('.fish-manager-sheet .section-head button').click();
  assert.equal(await page.evaluate(() => localStorage.getItem('reef-demo-state-v10')), originalStorage);
  assert.deepEqual(errors, []);
  console.log('PASS: oversized/mislabeled input rejected before decoding, thin images and rotation, repeated upload resource release, canvas failure recovery, cancelled artwork upload cannot replace reopened draft, no saved data changes.');
} finally { await browser.close(); }
