import assert from 'node:assert/strict';
import { launchBrowser, baseURL } from './browser-support.mjs';
const browser = await launchBrowser();
try {
  const page = await browser.newPage(), errors = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.goto(baseURL);
  await page.waitForFunction(() => localStorage.getItem('reef-demo-state-v10'));
  const original = await page.evaluate(() => localStorage.getItem('reef-demo-state-v10'));
  await page.evaluate(() => localStorage.setItem('reef-demo-state-v10', '{broken-original'));
  await page.reload();
  await page.getByTestId('storage-notice').waitFor();
  assert.match(await page.getByTestId('storage-notice').innerText(), /原存档已保留/);
  await page.getByRole('button', { name: '打开设置' }).click();
  await page.getByRole('button', { name: /稳定滴定配方/ }).click();
  await page.getByRole('button', { name: /^已配好/ }).click();
  assert.match(await page.getByRole('dialog').innerText(), /暂停保存/);
  assert.equal(await page.evaluate(() => localStorage.getItem('reef-demo-state-v10')), '{broken-original');
  await page.getByRole('button', { name: '关闭滴定计算器' }).click();
  const saveDetection = async () => {
    await page.locator('.bottom-nav button').filter({ hasText: '检测' }).click();
    await page.getByRole('button', { name: /手动录入 NO3/ }).click();
    await page.getByLabel('结果下限', { exact: true }).fill('12');
    await page.getByLabel('结果上限', { exact: true }).fill('12');
    await page.getByRole('button', { name: '确认并保存结果' }).click();
  };
  await saveDetection();
  await page.locator('.toast').filter({ hasText: '本次更改未保存' }).waitFor();
  assert.equal(await page.evaluate(() => localStorage.getItem('reef-demo-state-v10')), '{broken-original');
  await page.evaluate(raw => localStorage.setItem('reef-demo-state-v10', raw), original);
  await page.reload(); await page.locator('main[aria-busy=false]').waitFor();
  assert.equal(await page.getByTestId('storage-notice').count(), 0);
  const beforeQuota = await page.evaluate(() => localStorage.getItem('reef-demo-state-v10'));
  await page.evaluate(() => {
    window.savedStorageSetter = Storage.prototype.setItem;
    Storage.prototype.setItem = function(key, value) {
      if (key === 'reef-demo-state-v10') throw new DOMException('Test quota exhausted', 'QuotaExceededError');
      return window.savedStorageSetter.call(this, key, value);
    };
    window.observedToasts = [];
    new MutationObserver(() => {
      const text = document.querySelector('.toast')?.textContent;
      if (text) window.observedToasts.push(text);
    }).observe(document.body, { subtree: true, childList: true, characterData: true });
  });
  await saveDetection();
  await page.getByTestId('storage-notice').filter({ hasText: '更改尚未保存' }).waitFor();
  await page.locator('.toast').filter({ hasText: '更改未保存' }).waitFor();
  assert.equal(await page.evaluate(() => localStorage.getItem('reef-demo-state-v10')), beforeQuota);
  assert.ok(!(await page.evaluate(() => window.observedToasts)).some(text => text.includes('结果已保存')));
  await page.evaluate(() => { Storage.prototype.setItem = window.savedStorageSetter; });
  await page.getByRole('button', { name: '重试保存', exact: true }).click();
  await page.getByTestId('storage-notice').waitFor({ state: 'detached' });
  assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem('reef-demo-state-v10')).records[0].low), 12);

  // A fish save closes an asynchronous draft before publishing its result.
  // Exercise that path independently of the detection toast and observer.
  await page.reload(); await page.locator('main[aria-busy=false]').waitFor();
  const beforeFishQuota = await page.evaluate(() => localStorage.getItem('reef-demo-state-v10'));
  const beforeFishState = JSON.parse(beforeFishQuota);
  const changedFish = beforeFishState.fishStock.find(item => item.tankId === beforeFishState.tankId);
  assert.ok(changedFish, 'The isolated fixture needs an existing fish entry.');
  const nextQuantity = changedFish.quantity === 1 ? 2 : 1;
  await page.getByRole('button', { name: /^编辑 .* 的鱼类档案/ }).click();
  const manager = page.locator('.fish-manager-sheet');
  await manager.locator('.fish-stock-editor article').first().getByLabel('数量', { exact: true }).fill(String(nextQuantity));
  await page.evaluate(() => {
    window.savedStorageSetter = Storage.prototype.setItem;
    Storage.prototype.setItem = function(key, value) {
      if (key === 'reef-demo-state-v10') throw new DOMException('Test fish quota exhausted', 'QuotaExceededError');
      return window.savedStorageSetter.call(this, key, value);
    };
    window.observedToasts = [];
    new MutationObserver(() => {
      const text = document.querySelector('.toast')?.textContent;
      if (text) window.observedToasts.push(text);
    }).observe(document.body, { subtree: true, childList: true, characterData: true });
  });
  await manager.getByRole('button', { name: '保存鱼类档案', exact: true }).click();
  await manager.waitFor({ state: 'detached' });
  await page.getByTestId('storage-notice').filter({ hasText: '更改尚未保存' }).waitFor();
  await page.locator('.toast').filter({ hasText: '更改未保存' }).waitFor();
  assert.equal(await page.evaluate(() => localStorage.getItem('reef-demo-state-v10')), beforeFishQuota);
  assert.ok(!(await page.evaluate(() => window.observedToasts)).some(text => text.includes('档案已保存')));
  await page.evaluate(() => { Storage.prototype.setItem = window.savedStorageSetter; });
  await page.getByRole('button', { name: '重试保存', exact: true }).click();
  await page.getByTestId('storage-notice').waitFor({ state: 'detached' });
  const afterFishRetry = await page.evaluate(() => JSON.parse(localStorage.getItem('reef-demo-state-v10')));
  assert.equal(afterFishRetry.fishStock.length, beforeFishState.fishStock.length);
  for (const item of beforeFishState.fishStock) {
    assert.deepEqual(afterFishRetry.fishStock.find(saved => saved.id === item.id),
      item.id === changedFish.id ? { ...item, quantity: nextQuantity } : item);
  }
  assert.deepEqual(afterFishRetry.records, beforeFishState.records);
  await page.reload(); await page.locator('main[aria-busy=false]').waitFor();
  assert.equal(await page.getByTestId('storage-notice').count(), 0);
  await page.getByRole('button', { name: /^编辑 .* 的鱼类档案/ }).click();
  assert.equal(await manager.locator('.fish-stock-editor article').first().getByLabel('数量', { exact: true }).inputValue(), String(nextQuantity));
  assert.deepEqual(errors, []);
  console.log('PASS: malformed snapshot survives attempted refill/detection; detection and fish quota failures report unsaved, preserve the original and retry successfully without changing other data.');
} finally { await browser.close(); }
