import assert from 'node:assert/strict';
import { expect } from '@playwright/test';
import { launchBrowser, baseURL } from './browser-support.mjs';

const key = 'reef-demo-state-v10';
const browser = await launchBrowser();
const errors = [];

async function scenario() {
  const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
  const page = await context.newPage();
  page.setDefaultTimeout(8_000);
  page.on('pageerror', error => errors.push(error.message));
  const ready = () => page.locator('main[aria-busy=false]').waitFor();
  await page.goto(`${baseURL}/`);
  await ready();
  await page.waitForFunction(key => !!localStorage.getItem(key), key);
  const read = () => page.evaluate(key => JSON.parse(localStorage.getItem(key)), key);
  const reload = async () => { await page.reload(); await ready(); };
  const settings = async name => {
    await page.getByRole('button', { name: '打开设置' }).click();
    await page.locator('.settings-row').filter({ hasText: name }).click();
  };
  const close = () => page.locator('.modal-backdrop .section-head button').click();
  const calculator = async chemical => {
    await settings(chemical === 'kh' ? '碳酸氢钠补 KH 理论计划' : 'PO4 氯化镧理论计划');
    const sheet = page.locator(chemical === 'kh' ? '.alkalinity-sheet' : '.lanthanum-sheet');
    const target = sheet.locator(`input[name=${chemical === 'kh' ? 'targetDkh' : 'targetPo4MgL'}]`);
    const current = sheet.locator(`input[name=${chemical === 'kh' ? 'currentDkh' : 'currentPo4MgL'}]`);
    return { sheet, target, current, submit: () => sheet.locator('button[type=submit]').click() };
  };
  const switchTank = async name => {
    await page.locator('.tank-switcher').click();
    await page.locator('.tank-popover button').filter({ hasText: name }).click();
    await expect(page.locator('.tank-switcher strong')).toHaveText(name);
  };
  const enableKh = async () => {
    await settings('关注指标管理');
    const option = page.locator('.parameter-manager button').filter({ hasText: 'KH · 碳酸盐硬度' });
    assert.ok(!(await option.getAttribute('class'))?.includes('enabled'), 'First-enable scenario needs an untracked KH parameter.');
    await option.click();
    await close();
    await page.waitForFunction(key => {
      const state = JSON.parse(localStorage.getItem(key));
      return state.targets.some(target => target.tankId === state.tankId && target.parameterId === 'kh');
    }, key);
  };
  const setTargets = async values => {
    await settings('水质目标范围');
    for (const [parameter, [min, max]] of Object.entries(values)) {
      await page.locator(`input[name=min-${parameter}]`).fill(min);
      await page.locator(`input[name=max-${parameter}]`).fill(max);
    }
    await page.getByRole('button', { name: '保存当前海缸目标', exact: true }).click();
    await expect(page.locator('.target-sheet')).toHaveCount(0);
    await page.waitForFunction(({ key, values }) => {
      const state = JSON.parse(localStorage.getItem(key));
      return Object.entries(values).every(([parameterId, [min, max]]) => {
        const target = state.targets.find(target => target.tankId === state.tankId && target.parameterId === parameterId);
        return target?.min === (min === '' ? null : Number(min)) && target?.max === (max === '' ? null : Number(max));
      });
    }, { key, values });
  };
  return { context, page, read, reload, close, calculator, switchTank, enableKh, setTargets };
}

try {
  // Model an actual pre-marker snapshot: only an already-enabled, fully empty KH range is filled.
  {
    const s = await scenario();
    const before = await s.read();
    await s.page.evaluate(key => {
      const state = JSON.parse(localStorage.getItem(key));
      delete state.khTargetDefaultsApplied;
      state.tanks.push({ id: 31, name: '仅有上限缸', volume: '80 L' }, { id: 32, name: '仅有下限缸', volume: '90 L' });
      state.targets = state.targets.filter(target => target.parameterId !== 'kh');
      state.targets.push(
        { tankId: 1, parameterId: 'kh', min: null, max: null },
        { tankId: 2, parameterId: 'kh', min: 7.4, max: 8.6 },
        { tankId: 31, parameterId: 'kh', min: null, max: 9.2 },
        { tankId: 32, parameterId: 'kh', min: 7.1, max: null },
        { tankId: 31, parameterId: 'po4', min: null, max: 0.12 },
        { tankId: 32, parameterId: 'po4', min: 0.05, max: null },
      );
      localStorage.setItem(key, JSON.stringify(state));
    }, key);
    await s.reload();
    await s.page.waitForFunction(key => JSON.parse(localStorage.getItem(key)).khTargetDefaultsApplied === true, key);
    const migrated = await s.read();
    assert.deepEqual(migrated.targets.filter(target => target.parameterId === 'kh'), [
      { tankId: 1, parameterId: 'kh', min: 7, max: 9 },
      { tankId: 2, parameterId: 'kh', min: 7.4, max: 8.6 },
      { tankId: 31, parameterId: 'kh', min: null, max: 9.2 },
      { tankId: 32, parameterId: 'kh', min: 7.1, max: null },
    ]);
    assert.deepEqual(migrated.records, before.records);
    assert.deepEqual(migrated.tasks, before.tasks);
    for (const name of ['仅有上限缸', '仅有下限缸']) {
      await s.switchTank(name);
      for (const chemical of ['kh', 'po4']) {
        const form = await s.calculator(chemical);
        await expect(form.target).toHaveValue('');
        await form.current.fill(chemical === 'kh' ? '6' : '0.08');
        await form.submit();
        assert.equal(await form.target.evaluate(input => input.validity.valueMissing), true);
        await s.close();
      }
    }
    await s.switchTank('客厅主缸');
    await s.setTargets({ kh: ['', ''], po4: ['', ''] });
    await s.reload();
    const cleared = await s.read();
    assert.equal(cleared.khTargetDefaultsApplied, true);
    assert.deepEqual(cleared.targets.find(target => target.tankId === 1 && target.parameterId === 'kh'),
      { tankId: 1, parameterId: 'kh', min: null, max: null });
    for (const [chemical, fallback] of [['kh', '8'], ['po4', '0.03']]) {
      const form = await s.calculator(chemical);
      await expect(form.target).toHaveValue(fallback);
      await s.close();
    }
    assert.deepEqual((await s.read()).records, before.records);
    assert.deepEqual((await s.read()).tasks, before.tasks);
    await s.context.close();
    console.log('PASS: old empty KH range receives 7–9 once; custom and one-sided ranges survive; later clearing stays empty after reload with calculator fallbacks.');
  }

  // User edits control the midpoint on every reopen, and manual form values survive error rerenders.
  {
    const s = await scenario();
    const before = await s.read();
    await s.enableKh();
    assert.deepEqual((await s.read()).targets.find(target => target.tankId === 1 && target.parameterId === 'kh'),
      { tankId: 1, parameterId: 'kh', min: 7, max: 9 });
    await s.setTargets({ kh: ['7.8', '7.81'], po4: ['0.04', '0.09'] });
    let form = await s.calculator('kh');
    await expect(form.target).toHaveValue('7.805');
    assert.equal(await form.target.evaluate(input => input.validity.stepMismatch), false);
    assert.ok(await form.sheet.evaluate(node => node.scrollWidth <= node.clientWidth + 1), 'KH calculator fits the narrow screen');
    await s.page.screenshot({ path: 'artifacts/target-linkage-kh.png', animations: 'disabled' });
    await form.target.fill('7.806');
    await form.current.fill('8');
    await form.submit();
    await expect(form.sheet.getByRole('alert')).toBeVisible();
    await expect(form.target).toHaveValue('7.806');
    await form.current.fill('6');
    for (const [value, message] of [['7.79', /下限/], ['7.82', /上限/]]) {
      await form.target.fill(value);
      await form.submit();
      await expect(form.sheet.getByRole('alert')).toHaveText(message);
      await expect(form.target).toHaveValue(value);
    }
    await s.close();
    form = await s.calculator('kh');
    await expect(form.target).toHaveValue('7.805');
    await s.close();
    form = await s.calculator('po4');
    await expect(form.target).toHaveValue('0.065');
    assert.ok(await form.sheet.evaluate(node => node.scrollWidth <= node.clientWidth + 1), 'PO4 calculator fits the narrow screen');
    await s.page.screenshot({ path: 'artifacts/target-linkage-po4.png', animations: 'disabled' });
    await form.target.fill('0.055');
    await form.current.fill('0.055');
    await form.submit();
    await expect(form.sheet.getByRole('alert')).toBeVisible();
    await expect(form.target).toHaveValue('0.055');
    await s.close();

    await s.switchTank('小丑鱼缸');
    form = await s.calculator('kh');
    await expect(form.target).toHaveValue('8'); // KH not enabled in this tank yet.
    await s.close();
    await s.enableKh();
    await s.setTargets({ kh: ['9', '11'], po4: ['0.08', '0.12'] });
    for (const [chemical, midpoint] of [['kh', '10'], ['po4', '0.1']]) {
      form = await s.calculator(chemical);
      await expect(form.target).toHaveValue(midpoint);
      await s.close();
    }
    await s.switchTank('客厅主缸');
    await s.reload();
    for (const [chemical, midpoint] of [['kh', '7.805'], ['po4', '0.065']]) {
      form = await s.calculator(chemical);
      await expect(form.target).toHaveValue(midpoint);
      await s.close();
    }
    assert.deepEqual((await s.read()).targets.filter(target => target.tankId === 2 && ['kh', 'po4'].includes(target.parameterId))
      .map(({ parameterId, min, max }) => ({ parameterId, min, max })).sort((a, b) => a.parameterId.localeCompare(b.parameterId)), [
      { parameterId: 'kh', min: 9, max: 11 }, { parameterId: 'po4', min: 0.08, max: 0.12 },
    ]);
    await s.setTargets({ po4: ['0.01', '0.03'] });
    form = await s.calculator('po4');
    await expect(form.target).toHaveValue('0.02');
    await form.current.fill('0.08');
    await form.submit();
    assert.equal(await form.target.evaluate(input => input.validity.rangeUnderflow), true);
    await expect(form.sheet.getByRole('button', { name: '配置滴定液', exact: true })).toHaveCount(0);
    await s.close();
    assert.deepEqual((await s.read()).records, before.records);
    assert.deepEqual((await s.read()).tasks, before.tasks);
    await s.context.close();
    console.log('PASS: first KH enable, exact midpoint, manual-value persistence, per-tank/reload isolation and unchanged PO4/KH submission guards; opening/cancelling creates no tasks or records.');
  }
  assert.deepEqual(errors, []);
} finally {
  await browser.close();
}
