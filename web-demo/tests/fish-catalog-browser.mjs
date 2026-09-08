import assert from 'node:assert/strict';
import { expect } from '@playwright/test';
import { launchBrowser, baseURL } from './browser-support.mjs';

const key = 'reef-demo-state-v10';
const newFish = [
  ['paracanthurus-hepatus', '蓝吊'], ['foxface', '黄狐狸'], ['lamarck', '拉马克'],
  ['tomato-clownfish', '番茄小丑'], ['bannerfish', '关刀'], ['emperor', '皇后'],
  ['saddleback', '马鞍'], ['golden-towel', '金毛巾'], ['blueface', '蓝面'],
  ['violet-anthias', '紫罗兰'], ['yellow-tang', '黄金吊'],
];
const expectedNames = [
  '小丑鱼', '双斑宝石海金鱼（公）', '双斑宝石海金鱼（母）', '蓝眼海金鱼（公）',
  '深水樱花宝石', '火焰仙', '紫吊', '粉蓝吊', '东非金剪刀', ...newFish.map(([, name]) => name),
];
const browser = await launchBrowser();
const errors = [];
const failedAssets = [];
const sortedStock = items => [...items].sort((a, b) => a.id.localeCompare(b.id));

async function scenario({ reducedMotion = 'no-preference' } = {}) {
  // Every scenario owns a fresh storage area, never the user's browser profile.
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, reducedMotion });
  const page = await context.newPage();
  page.setDefaultTimeout(8_000);
  page.on('pageerror', error => errors.push(error.message));
  page.on('response', response => {
    if (new URL(response.url()).pathname.startsWith('/fish-species/') && response.status() >= 400) {
      failedAssets.push(`${response.status()} ${response.url()}`);
    }
  });
  const ready = () => page.locator('main[aria-busy=false]').waitFor();
  await page.goto(`${baseURL}/`);
  await ready();
  await page.waitForFunction(key => !!localStorage.getItem(key), key);
  const read = () => page.evaluate(key => JSON.parse(localStorage.getItem(key)), key);
  const reload = async () => { await page.reload(); await ready(); };
  const manager = page.locator('.fish-manager-sheet');
  const openFish = async () => {
    await page.getByRole('button', { name: /^编辑 .* 的鱼类档案/ }).click();
    await expect(manager).toBeVisible();
  };
  const switchTank = async name => {
    await page.locator('.tank-switcher').click();
    await page.locator('.tank-popover button').filter({ hasText: name }).click();
    await expect(page.locator('.tank-switcher strong')).toHaveText(name);
  };
  const yellowSwimmers = page.locator('.aquarium-fish').filter({ has: page.locator('img[src="/fish-species/yellow-tang.webp"]') });
  const addYellow = async (tankId, quantity) => {
    const last = manager.locator('.fish-species-catalog > button').last();
    await expect(last.locator('strong')).toHaveText('黄金吊');
    await last.click();
    await expect(last).toHaveClass('selected');
    const add = manager.locator('.add-fish-species');
    await add.getByLabel('数量', { exact: true }).fill(String(quantity));
    await add.getByLabel('入缸日期', { exact: true }).fill('2026-09-01');
    await add.getByRole('button', { name: '＋ 加入鱼类档案', exact: true }).click();
    const entry = manager.locator('.fish-stock-editor article').filter({ has: page.locator('.fish-stock-title strong', { hasText: /^黄金吊$/ }) });
    await expect(entry.getByLabel('数量', { exact: true })).toHaveValue(String(quantity));
    await expect(entry.locator('img')).toHaveAttribute('src', '/fish-species/yellow-tang.webp');
    await manager.getByRole('button', { name: '保存鱼类档案', exact: true }).click();
    await expect(manager).toHaveCount(0);
    await page.waitForFunction(({ key, tankId, quantity }) => {
      const state = JSON.parse(localStorage.getItem(key));
      return state.fishStock.some(fish => fish.tankId === tankId && fish.artwork.id === 'yellow-tang' && fish.quantity === quantity);
    }, { key, tankId, quantity });
    await expect(yellowSwimmers).toHaveCount(quantity);
  };
  return { context, page, read, reload, manager, openFish, switchTank, yellowSwimmers, addYellow };
}

try {
  {
    const s = await scenario();
    const before = await s.read();
    const firstTank = before.tanks.find(tank => tank.id === before.tankId);
    const otherTank = before.tanks.find(tank => tank.id !== before.tankId);
    assert.ok(firstTank && otherTank, 'The isolated fixture needs two tanks.');
    await s.openFish();
    const catalog = s.manager.locator('.fish-species-catalog > button');
    await expect(catalog).toHaveCount(20);
    assert.deepEqual(await catalog.locator('strong').allTextContents(), expectedNames);

    const resources = await catalog.evaluateAll(async (buttons, newFish) => {
      const results = [];
      for (const [id, name] of newFish) {
        const button = buttons.find(item => item.querySelector('strong')?.textContent === name);
        const image = button?.querySelector('img');
        if (!image) throw new Error(`Missing catalog artwork: ${id}`);
        await image.decode();
        const canvas = document.createElement('canvas');
        canvas.width = 128; canvas.height = 128;
        const context = canvas.getContext('2d');
        if (!context) throw new Error('Canvas unavailable');
        // Fill the whole sample with the source, so letterboxing cannot fake alpha.
        context.drawImage(image, 0, 0, 128, 128);
        const pixels = context.getImageData(0, 0, 128, 128).data;
        let clear = 0, visible = 0;
        for (let index = 3; index < pixels.length; index += 4) {
          if (pixels[index] === 0) clear++;
          if (pixels[index] > 32) visible++;
        }
        results.push({ id, path: new URL(image.currentSrc).pathname,
          width: image.naturalWidth, height: image.naturalHeight, clear, visible });
        canvas.width = 0; canvas.height = 0;
      }
      return results;
    }, newFish);
    for (const resource of resources) {
      assert.equal(resource.path, `/fish-species/${resource.id}.webp`);
      assert.ok(resource.width > 0 && resource.height > 0, `${resource.id} decodes`);
      assert.ok(resource.clear > 0 && resource.visible > 0, `${resource.id} has real transparency and nonempty fish pixels`);
    }
    assert.equal(await s.manager.evaluate(element => element.scrollWidth <= element.clientWidth + 1), true);
    await catalog.last().scrollIntoViewIfNeeded();
    await s.page.screenshot({ path: 'artifacts/fish-catalog-390.png', animations: 'disabled' });
    await s.addYellow(firstTank.id, 3);
    const firstSave = await s.read();
    const savedYellow = firstSave.fishStock.find(fish => fish.tankId === firstTank.id && fish.artwork.id === 'yellow-tang');
    assert.deepEqual({ species: savedYellow.species, quantity: savedYellow.quantity, introducedOn: savedYellow.introducedOn, artwork: savedYellow.artwork },
      { species: '黄金吊', quantity: 3, introducedOn: '2026-09-01', artwork: { source: 'builtin', id: 'yellow-tang' } });
    assert.deepEqual(sortedStock(firstSave.fishStock.filter(fish => fish.id !== savedYellow.id)), sortedStock(before.fishStock));
    await s.reload();
    await expect(s.yellowSwimmers).toHaveCount(3);
    assert.deepEqual((await s.read()).fishStock, firstSave.fishStock);
    await s.openFish();
    const savedEntry = s.manager.locator('.fish-stock-editor article').filter({ has: s.page.locator('.fish-stock-title strong', { hasText: /^黄金吊$/ }) });
    await expect(savedEntry.getByLabel('数量', { exact: true })).toHaveValue('3');
    await expect(savedEntry.locator('img')).toHaveAttribute('src', '/fish-species/yellow-tang.webp');
    await s.manager.locator('.section-head button').click();

    await s.switchTank(otherTank.name);
    await expect(s.yellowSwimmers).toHaveCount(0);
    assert.deepEqual((await s.read()).fishStock.filter(fish => fish.tankId === otherTank.id), before.fishStock.filter(fish => fish.tankId === otherTank.id));
    await s.openFish();
    await s.addYellow(otherTank.id, 1);
    const bothSaved = await s.read();
    assert.deepEqual(bothSaved.fishStock.filter(fish => fish.tankId === firstTank.id), firstSave.fishStock.filter(fish => fish.tankId === firstTank.id));
    await s.reload();
    await expect(s.yellowSwimmers).toHaveCount(1);
    await s.switchTank(firstTank.name);
    await expect(s.yellowSwimmers).toHaveCount(3);
    assert.deepEqual((await s.read()).fishStock, bothSaved.fishStock);
    for (const field of ['records', 'tasks', 'targets', 'maintenanceCycles']) assert.deepEqual((await s.read())[field], before[field]);
    assert.equal(await s.page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    await s.context.close();
    console.log('PASS: 20 named catalog options, all 11 new WebP resources decode with alpha, last-item selection, quantity/date/artwork persistence, refresh and two-tank stock isolation.');
  }

  {
    // A separate synthetic display fixture lets every new sprite be inspected.
    // Reduced motion freezes positions; this verifies actual CSS mirroring, while
    // aquarium-motion.test.ts covers live movement and turn decisions.
    const s = await scenario({ reducedMotion: 'reduce' });
    await s.page.evaluate(({ key, newFish }) => {
      const state = JSON.parse(localStorage.getItem(key));
      state.fishStock = [...state.fishStock.filter(fish => fish.tankId !== state.tankId),
        ...newFish.map(([id, species]) => ({ id: `catalog-${id}`, tankId: state.tankId, species,
          quantity: 1, introducedOn: '2026-09-01', artwork: { source: 'builtin', id } }))];
      localStorage.setItem(key, JSON.stringify(state));
    }, { key, newFish });
    await s.reload();
    const before = await s.read();
    const swimmers = s.page.locator('.aquarium-fish');
    await expect(swimmers).toHaveCount(11);
    await swimmers.locator('img').evaluateAll(images => Promise.all(images.map(image => image.decode())));
    for (const facing of ['right', 'left']) {
      const details = await swimmers.evaluateAll((elements, facing) => elements.map(element => {
        element.dataset.facing = facing;
        const artwork = element.querySelector('.fish-artwork');
        const transform = getComputedStyle(artwork).transform;
        const matrix = transform === 'none' ? new DOMMatrixReadOnly() : new DOMMatrixReadOnly(transform);
        const bounds = element.getBoundingClientRect();
        const water = element.closest('.aquarium-water').getBoundingClientRect();
        const image = element.querySelector('img');
        return { scaleX: matrix.a, scaleY: matrix.d, objectFit: getComputedStyle(image).objectFit,
          path: new URL(image.currentSrc).pathname, width: bounds.width, height: bounds.height,
          contained: bounds.left >= water.left - 1 && bounds.right <= water.right + 1 && bounds.top >= water.top - 1 && bounds.bottom <= water.bottom + 1 };
      }), facing);
      assert.deepEqual(details.map(detail => detail.path), newFish.map(([id]) => `/fish-species/${id}.webp`));
      for (const detail of details) {
        assert.equal(detail.scaleX, facing === 'left' ? -1 : 1, detail.path);
        assert.equal(detail.scaleY, 1, detail.path);
        assert.equal(detail.objectFit, 'contain', detail.path);
        assert.ok(detail.width > 0 && detail.height > 0 && detail.contained, `${detail.path} remains inside the aquarium`);
      }
      assert.equal(await s.page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
      await s.page.locator('.aquarium-card').screenshot({ path: `artifacts/fish-catalog-new-${facing}.png`, animations: 'disabled' });
    }
    assert.deepEqual((await s.read()).fishStock, before.fishStock, 'Display direction does not mutate saved fish stock.');
    await s.context.close();
    console.log('PASS: all 11 new sprites render within the 390px aquarium, preserve aspect ratio and mirror horizontally in both directions without changing stock.');
  }
  assert.deepEqual(failedAssets, []);
  assert.deepEqual(errors, []);
} finally {
  await browser.close();
}
