import assert from 'node:assert/strict';
import { expect } from '@playwright/test';
import { launchBrowser, baseURL } from './browser-support.mjs';

const key = 'reef-demo-state-v10';
const browser = await launchBrowser();
const errors = [];

async function scenario() {
  // A fresh context owns its localStorage; never seed the user's browser profile.
  const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
  const page = await context.newPage();
  page.setDefaultTimeout(8_000);
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(`${baseURL}/`);
  await page.locator('main[aria-busy=false]').waitFor();
  await page.waitForFunction(key => !!localStorage.getItem(key), key);
  const read = () => page.evaluate(key => JSON.parse(localStorage.getItem(key)), key);
  const parameter = name => page.locator('.parameter-tabs button').filter({
    has: page.locator('strong', { hasText: new RegExp(`^${name}$`) }),
  });
  const nav = label => page.locator('.bottom-nav button').filter({ hasText: label }).click();
  const enableKh = async () => {
    await page.getByRole('button', { name: '打开设置' }).click();
    await page.getByRole('button', { name: /关注指标管理/ }).click();
    const option = page.locator('.parameter-manager button').filter({ hasText: 'KH · 碳酸盐硬度' });
    if (!(await option.getAttribute('class'))?.includes('enabled')) await option.click();
    await page.locator('.modal-backdrop .section-head button').click();
  };
  const openKh = async () => { await nav('检测'); await parameter('KH').click(); };
  const panel = page.getByTestId('kh-titration');
  const result = page.getByTestId('kh-result');
  const initial = page.getByLabel('初始容积（mL）', { exact: true });
  const remaining = page.getByLabel('剩余溶剂（mL）', { exact: true });
  const calculate = async (start, end, expected) => {
    await initial.fill(start);
    await remaining.fill(end);
    await expect(result).toHaveCount(0);
    await panel.getByRole('button', { name: '计算 KH', exact: true }).click();
    await expect(result).toHaveText(`${expected} dKH`);
  };
  const noTimer = async () => {
    await expect(panel).toBeVisible();
    await expect(page.locator('.timer-card')).toHaveCount(0);
    await expect(page.getByRole('button', { name: '开始计时', exact: true })).toHaveCount(0);
  };
  await enableKh();
  await openKh();
  return { context, page, read, nav, parameter, enableKh, openKh, panel, result, initial, remaining, calculate, noTimer };
}

try {
  // Calculation is a draft. Edits and invalid inputs must never leave a stale saveable value.
  {
    const s = await scenario();
    const before = await s.read();
    await s.noTimer();
    await expect(s.panel.getByRole('heading', { name: 'KH 滴定检测', exact: true })).toBeVisible();
    await expect(s.initial).toHaveValue('1');
    await expect(s.remaining).toHaveValue('');
    await expect(s.page.getByRole('button', { name: /手动录入 KH/ })).toBeVisible();
    await s.calculate('1', '0.5', '7.7');
    await s.remaining.fill('0.51');
    await expect(s.result).toHaveCount(0);
    await s.calculate('0.8', '0.29', '7.9');
    await s.initial.fill('0.9');
    await expect(s.result).toHaveCount(0);
    await s.calculate('1', '0.98', '0.0');
    for (const [initial, remaining] of [['1', '1.01'], ['1', ''], ['1', '1'], ['', '0.5'], ['0', '0']]) {
      await s.initial.fill(initial);
      await s.remaining.fill(remaining);
      const calculate = s.panel.getByRole('button', { name: '计算 KH', exact: true });
      if (await calculate.isEnabled()) await calculate.click();
      await expect(s.result).toHaveCount(0);
      const save = s.panel.getByRole('button', { name: '确认并录入', exact: true });
      assert.equal(await save.count() > 0 && await save.isEnabled(), false);
    }
    assert.deepEqual((await s.read()).records, before.records);
    assert.deepEqual((await s.read()).tasks, before.tasks);
    assert.equal(await s.page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    await s.context.close();
    console.log('PASS: KH defaults, table/interpolated/zero results, stale-result invalidation, invalid input rejection and 390px layout.');
  }

  // Cancel and destination changes discard drafts; a previous NO3 timer cannot open a photo over KH.
  {
    const s = await scenario();
    const before = await s.read();
    await s.calculate('1', '0.5', '7.7');
    await s.panel.getByRole('button', { name: '本次不记录', exact: true }).click();
    await expect(s.result).toHaveCount(0);
    await s.calculate('1', '0.5', '7.7');
    await s.parameter('PO4').click();
    await s.parameter('KH').click();
    await expect(s.result).toHaveCount(0);
    await s.calculate('1', '0.5', '7.7');
    const otherTank = before.tanks.find(tank => tank.id !== before.tankId);
    assert.ok(otherTank, 'The fixture needs a second tank for draft isolation.');
    await s.page.locator('.tank-switcher').click();
    await s.page.locator('.tank-popover button').filter({ hasText: otherTank.name }).click();
    await s.enableKh();
    await s.openKh();
    await s.noTimer();
    await expect(s.result).toHaveCount(0);
    assert.equal((await s.read()).tankId, otherTank.id);
    assert.deepEqual((await s.read()).records, before.records);

    await s.parameter('NO3').click();
    await expect(s.page.locator('.timer-card')).toBeVisible();
    await s.page.locator('.custom-time-row input').nth(0).fill('0');
    await s.page.locator('.custom-time-row input').nth(1).fill('10');
    await s.page.clock.install();
    await s.page.getByRole('button', { name: '开始计时', exact: true }).click();
    await s.parameter('KH').click();
    await s.page.clock.fastForward(11_000);
    await s.noTimer();
    await expect(s.page.getByRole('heading', { name: '拍照比色', exact: true })).toHaveCount(0);
    await s.parameter('NO3').click();
    await s.page.getByRole('button', { name: '开始计时', exact: true }).click();
    await expect(s.page.getByRole('button', { name: '暂停计时', exact: true })).toBeVisible();
    await s.page.clock.fastForward(11_000);
    await expect(s.page.getByRole('heading', { name: '拍照比色', exact: true })).toBeVisible();
    assert.deepEqual((await s.read()).records, before.records);
    assert.deepEqual((await s.read()).tasks, before.tasks);
    await s.context.close();
    console.log('PASS: KH cancel/indicator/tank switches do not record; previous NO3 timer stops and a fresh NO3 timer still opens photography.');
  }

  // Only confirmation writes one single-value record, and both raw inputs survive reload.
  {
    const s = await scenario();
    const before = await s.read();
    await s.calculate('0.8', '0.29', '7.9');
    await s.page.screenshot({ path: 'artifacts/kh-titration-result.png', fullPage: true, animations: 'disabled' });
    assert.deepEqual((await s.read()).records, before.records);
    await s.panel.getByRole('button', { name: '确认并录入', exact: true }).click();
    await s.page.waitForFunction(({ key, count }) => JSON.parse(localStorage.getItem(key)).records.length === count, { key, count: before.records.length + 1 });
    const saved = (await s.read()).records.find(record => !before.records.some(old => old.id === record.id));
    assert.ok(saved);
    assert.equal(saved.tankId, before.tankId);
    assert.equal(saved.parameterId, 'kh');
    assert.equal(saved.low, 7.9);
    assert.equal(saved.high, 7.9);
    assert.ok(saved.khTitration);
    assert.equal(saved.khTitration.initialMl, 0.8);
    assert.equal(saved.khTitration.remainingMl, 0.29);
    assert.ok(Math.abs(saved.khTitration.usedMl - 0.51) < 1e-12);
    assert.ok(Math.abs(saved.khTitration.tableReadingMl - 0.49) < 1e-12);
    assert.ok(Math.abs(saved.khTitration.dkh - 7.85) < 1e-12);
    assert.equal(saved.khTitration.displayDkh, '7.9');
    assert.equal(saved.khTitration.interpolated, true);
    assert.equal(saved.khTitration.tableId, 'kh-titration-from-syringe-v1');
    assert.deepEqual((await s.read()).tasks, before.tasks);
    await s.page.reload();
    await s.page.locator('main[aria-busy=false]').waitFor();
    assert.deepEqual((await s.read()).records.find(record => record.id === saved.id), saved);
    await s.nav('趋势');
    await s.parameter('KH').click();
    await expect(s.page.locator('.record-row').filter({ hasText: '7.9 dKH' })).toHaveCount(1);
    await expect(s.page.locator('.plot-point').filter({ hasText: '7.9' })).toBeVisible();
    await s.page.getByRole('button', { name: '＋ 添加', exact: true }).click();
    await s.noTimer();
    await expect(s.result).toHaveCount(0);
    await s.page.getByRole('button', { name: /手动录入 KH/ }).click();
    await expect(s.page.getByRole('heading', { name: '修改并确认检测结果', exact: true })).toBeVisible();
    await s.page.getByRole('button', { name: '本次不记录', exact: true }).click();
    assert.equal((await s.read()).records.length, before.records.length + 1);
    await s.context.close();
    console.log('PASS: KH confirmation writes one current-tank single value with titration provenance; reload, trend, add-from-trend and manual-entry cancellation.');
  }

  // Numeric integer/zero records retain one display decimal, while edits use the current value.
  {
    const s = await scenario();
    const before = await s.read();
    const savedRecords = [];
    for (const [remaining, display, value] of [['0.48', '8.0', 8], ['0.98', '0.0', 0]]) {
      await s.openKh();
      await s.calculate('1', remaining, display);
      await s.panel.getByRole('button', { name: '确认并录入', exact: true }).click();
      await s.page.waitForFunction(({ key, count }) => JSON.parse(localStorage.getItem(key)).records.length === count,
        { key, count: before.records.length + savedRecords.length + 1 });
      const saved = (await s.read()).records.find(record => !before.records.some(old => old.id === record.id)
        && !savedRecords.some(old => old.id === record.id));
      assert.ok(saved);
      assert.equal(saved.low, value);
      assert.equal(saved.high, value);
      assert.equal(saved.khTitration.displayDkh, display);
      savedRecords.push(saved);
      await s.nav('首页');
      await expect(s.page.locator('.metric-card').filter({ hasText: 'KH' }).locator('strong')).toHaveText(display);
      await expect(s.page.locator(`.history-bar-slot[data-record-id="${saved.id}"] strong`)).toHaveText(display);
    }
    await s.nav('趋势');
    await s.parameter('KH').click();
    const row = display => s.page.locator('.record-row').filter({
      has: s.page.locator('strong', { hasText: new RegExp(`^${display.replace('.', '\\.')} dKH$`) }),
    });
    await expect(row('8.0')).toHaveCount(1);
    await expect(row('0.0')).toHaveCount(1);
    await row('8.0').click();
    await s.page.locator('input[name=low]').fill('8.1');
    await s.page.locator('input[name=high]').fill('8.1');
    await s.page.getByRole('button', { name: '保存修改', exact: true }).click();
    await s.page.waitForFunction(({ key, id }) => JSON.parse(localStorage.getItem(key)).records.find(record => record.id === id)?.low === 8.1,
      { key, id: savedRecords[0].id });
    const edited = (await s.read()).records.find(record => record.id === savedRecords[0].id);
    assert.equal(edited.high, 8.1);
    assert.deepEqual(edited.khTitration, savedRecords[0].khTitration);
    await expect(row('8.1')).toHaveCount(1);
    await expect(row('8.0')).toHaveCount(0);
    await expect(row('0.0')).toHaveCount(1);
    await s.nav('首页');
    await expect(s.page.locator(`.history-bar-slot[data-record-id="${edited.id}"] strong`)).toHaveText('8.1');
    assert.equal((await s.read()).records.length, before.records.length + 2);
    assert.deepEqual((await s.read()).tasks, before.tasks);
    await s.context.close();
    console.log('PASS: stored KH integers/zero keep .0 on home and trend; manual edit displays 8.1 and preserves original 8.0 titration metadata.');
  }
  assert.deepEqual(errors, []);
} finally {
  await browser.close();
}
