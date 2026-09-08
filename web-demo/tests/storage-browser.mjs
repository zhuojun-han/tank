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
  assert.deepEqual(errors, []);
  console.log('PASS: malformed snapshot survives attempted refill/detection; quota failure never reports saved, preserves original and retries the unsaved result successfully.');
} finally { await browser.close(); }
