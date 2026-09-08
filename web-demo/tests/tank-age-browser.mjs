import assert from 'node:assert/strict';
import { expect } from '@playwright/test';
import { launchBrowser, baseURL } from './browser-support.mjs';

const key = 'reef-demo-state-v10';
const browser = await launchBrowser();
const errors = [];

function unchangedData(actual, expected, { targets = true } = {}) {
  for (const field of ['records', 'tasks', 'fishStock', 'maintenanceCycles', 'parameters', 'timerDefaults', ...(targets ? ['targets'] : [])]) {
    assert.deepEqual(actual[field], expected[field], `${field} must survive tank metadata edits.`);
  }
}

async function scenario(start = '2026-09-08T12:00:00') {
  // New context per scenario: this script never reads the user's browser profile.
  const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
  const page = await context.newPage();
  page.setDefaultTimeout(8_000);
  page.on('pageerror', error => errors.push(error.message));
  const at = localDate => page.evaluate(value => new Date(value).getTime(), localDate);
  await page.clock.install({ time: await at(start) });
  const ready = () => page.locator('main[aria-busy=false]').waitFor();
  await page.goto(`${baseURL}/`);
  await ready();
  await page.waitForFunction(key => !!localStorage.getItem(key), key);
  await page.evaluate(key => {
    const state = JSON.parse(localStorage.getItem(key));
    for (const tank of state.tanks) delete tank.startedOn;
    state.notificationEnabled = false;
    // Preserve non-empty histories on both tanks while exercising metadata only.
    state.records.push({ id: 80001, tankId: 2, parameterId: 'po4', low: 0.08, high: 0.08,
      date: '2026-09-07T04:00:00.000Z', note: 'B缸原检测' });
    state.tasks.push({ id: 80002, tankId: 2, title: 'B缸原维护', cycle: '每 7 天', due: '2026-09-08 09:00',
      state: 'due', source: 'manual', scheduledDate: '2026-09-08', intervalDays: 7,
      rolling: { version: 1, nextDate: '2026-09-08', revision: 0, completed: [] } });
    localStorage.setItem(key, JSON.stringify(state));
  }, key);
  const reload = async () => { await page.reload(); await ready(); };
  await reload();
  const read = () => page.evaluate(key => JSON.parse(localStorage.getItem(key)), key);
  const age = page.getByTestId('tank-running-days').locator('strong');
  const manager = page.getByRole('dialog', { name: '海缸管理', exact: true });
  const form = page.getByRole('dialog', { name: /^(编辑|添加)海缸$/ });
  const dateInput = form.getByLabel(/^开缸日期/);
  const nav = label => page.locator('.bottom-nav button').filter({ hasText: label }).click();
  const openManager = async () => {
    await page.getByRole('button', { name: '打开设置' }).click();
    await page.getByRole('button', { name: /海缸管理/ }).click();
    await expect(manager).toBeVisible();
  };
  const edit = async id => {
    await openManager();
    await manager.getByTestId(`tank-manager-row-${id}`).getByRole('button', { name: '编辑', exact: true }).click();
    await expect(form).toBeVisible();
  };
  const closeManager = async () => {
    if (await manager.count()) await manager.getByRole('button', { name: '关闭海缸管理', exact: true }).click();
  };
  const cancel = async () => {
    await form.getByRole('button', { name: '取消', exact: true }).click();
    await expect(form).toHaveCount(0);
    await closeManager();
  };
  const save = async (id, date) => {
    await form.getByRole('button', { name: '保存海缸', exact: true }).click();
    await expect(form).toHaveCount(0);
    await page.waitForFunction(({ key, id, date }) => {
      const tank = JSON.parse(localStorage.getItem(key)).tanks.find(t => t.id === id);
      return (tank?.startedOn ?? '') === date;
    }, { key, id, date });
    await closeManager();
  };
  const switchTank = async name => {
    await page.locator('.tank-switcher').click();
    await page.locator('.tank-popover button').filter({ hasText: name }).click();
    await expect(page.locator('.tank-switcher strong')).toHaveText(name);
  };
  const add = async (name, date = '') => {
    await openManager();
    await manager.getByRole('button', { name: /添加海缸/ }).click();
    await form.getByLabel('海缸名称', { exact: true }).fill(name);
    await dateInput.fill(date);
    await form.getByRole('button', { name: '创建海缸', exact: true }).click();
    await expect(form).toHaveCount(0);
    await page.waitForFunction(({ key, name }) => {
      const state = JSON.parse(localStorage.getItem(key));
      return state.tanks.some(tank => tank.id === state.tankId && tank.name === name);
    }, { key, name });
    await closeManager();
    return (await read()).tanks.find(tank => tank.name === name);
  };
  return { context, page, at, ready, read, reload, age, manager, form, dateInput, nav,
    openManager, edit, closeManager, cancel, save, switchTank, add };
}

try {
  // Existing archives do not acquire an invented setup date. Cancel, edit and
  // clearing are explicit metadata operations, independent of fish introducedOn.
  {
    const s = await scenario();
    await s.page.evaluate(key => {
      const state = JSON.parse(localStorage.getItem(key));
      state.tanks.find(tank => tank.id === 1).volume = '约120 L';
      localStorage.setItem(key, JSON.stringify(state));
    }, key);
    await s.reload();
    const before = await s.read();
    assert.ok(before.tanks.every(tank => tank.startedOn === undefined));
    await expect(s.age).toHaveText('设置开缸日期');
    await s.age.click();
    await expect(s.form).toBeVisible();
    await expect(s.form.getByLabel('海缸名称', { exact: true })).toHaveValue('客厅主缸');
    await expect(s.dateInput).toHaveValue('');
    await s.dateInput.fill('2026-09-01');
    await s.cancel();
    assert.deepEqual((await s.read()).tanks, before.tanks);
    await expect(s.age).toHaveText('设置开缸日期');

    await s.edit(1);
    await s.dateInput.fill('2026-09-09');
    await s.form.getByRole('button', { name: '保存海缸', exact: true }).click();
    await expect(s.form).toBeVisible();
    assert.equal(await s.dateInput.evaluate(input => input.validity.rangeOverflow), true);
    assert.deepEqual((await s.read()).tanks, before.tanks);
    await s.dateInput.fill('2026-09-08');
    await s.save(1, '2026-09-08');
    assert.equal((await s.read()).tanks.find(tank => tank.id === 1).volume, '约120 L');
    await expect(s.age).toHaveText('已运行 0 天');
    await s.edit(1);
    await s.dateInput.fill('2026-09-01');
    await s.save(1, '2026-09-01');
    assert.equal((await s.read()).tanks.find(tank => tank.id === 1).volume, '约120 L');
    await expect(s.age).toHaveText('已运行 7 天');
    await s.reload();
    await expect(s.age).toHaveText('已运行 7 天');
    await s.edit(1);
    await s.dateInput.fill('');
    await s.save(1, '');
    assert.equal((await s.read()).tanks.find(tank => tank.id === 1).volume, '约120 L');
    await expect(s.age).toHaveText('设置开缸日期');
    await s.reload();
    await expect(s.age).toHaveText('设置开缸日期');
    assert.equal((await s.read()).tanks.find(tank => tank.id === 1).volume, '约120 L');
    unchangedData(await s.read(), before);
    assert.equal(await s.page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    await s.context.close();
    console.log('PASS: legacy blank date, explicit cancel/set/edit/clear, future rejection, day zero and reload preserve the original volume text 约120 L without fabricated tank age or collateral data changes.');
  }

  // Editing a non-current tank must not silently switch the destination or alter
  // another tank's date, fish archive, records, tasks or established targets.
  {
    const s = await scenario();
    const before = await s.read();
    await s.edit(1);
    await s.dateInput.fill('2026-09-01');
    await s.save(1, '2026-09-01');
    await s.edit(2);
    await s.dateInput.fill('2026-09-05');
    await s.save(2, '2026-09-05');
    assert.equal((await s.read()).tankId, 1);
    await expect(s.age).toHaveText('已运行 7 天');
    await s.switchTank('小丑鱼缸');
    await expect(s.age).toHaveText('已运行 3 天');
    await s.reload();
    await expect(s.age).toHaveText('已运行 3 天');
    await s.page.getByRole('button', { name: /^编辑 小丑鱼缸 的鱼类档案/ }).click();
    await expect(s.page.getByRole('heading', { name: /鱼类档案/ })).toBeVisible();
    await s.page.locator('.fish-manager-sheet .section-head button').click();
    await s.switchTank('客厅主缸');
    await expect(s.age).toHaveText('已运行 7 天');
    unchangedData(await s.read(), before);
    await s.context.close();
    console.log('PASS: two tanks retain independent setup dates through edits/switch/reload, while fish management and original task/record/target data remain intact.');
  }

  // This exercises the live midnight timer and a restored foreground clock,
  // without reloading, importing data, or claiming OS background coverage.
  {
    const s = await scenario('2026-09-08T23:59:00');
    await s.edit(1);
    await s.dateInput.fill('2026-09-08');
    await s.save(1, '2026-09-08');
    const before = await s.read();
    await expect(s.age).toHaveText('已运行 0 天');
    await s.page.clock.fastForward(61_000);
    await expect(s.age).toHaveText('已运行 1 天');
    await s.page.clock.setSystemTime(await s.at('2026-09-11T12:00:00'));
    await s.page.evaluate(() => window.dispatchEvent(new Event('focus')));
    await expect(s.age).toHaveText('已运行 3 天');
    assert.deepEqual((await s.read()).tanks, before.tanks);
    unchangedData(await s.read(), before);
    await s.context.close();
    console.log('PASS: tank age advances at live local midnight and refreshes after a foreground clock jump without rewriting the stored setup date.');
  }

  // Previously creating a tank bypassed the normal switch reset and could leave
  // the old tank's edited test result saveable under the new tank's identity.
  {
    const s = await scenario();
    const before = await s.read();
    await s.nav('检测');
    await s.page.getByRole('button', { name: /手动录入 NO3/ }).click();
    await s.page.getByLabel('结果下限', { exact: true }).fill('37');
    await s.page.getByLabel('结果上限', { exact: true }).fill('43');
    await s.page.getByLabel('插值 / 单值', { exact: true }).fill('39');
    await expect(s.page.getByRole('heading', { name: '修改并确认检测结果', exact: true })).toBeVisible();
    const added = await s.add('开缸日期回归缸', '2026-09-06');
    assert.equal(added.startedOn, '2026-09-06');
    await expect(s.page.getByRole('heading', { name: '修改并确认检测结果', exact: true })).toHaveCount(0);
    await s.nav('检测');
    await expect(s.page.getByRole('heading', { name: '准备检测', exact: true })).toBeVisible();
    await s.page.getByRole('button', { name: /手动录入 NO3/ }).click();
    await expect(s.page.getByLabel('结果下限', { exact: true })).toHaveValue('');
    await expect(s.page.getByLabel('结果上限', { exact: true })).toHaveValue('');
    await expect(s.page.getByLabel('插值 / 单值', { exact: true })).toHaveValue('');
    await s.page.getByRole('button', { name: '本次不记录', exact: true }).click();
    await s.nav('首页');
    await expect(s.age).toHaveText('已运行 2 天');
    await s.reload();
    await expect(s.age).toHaveText('已运行 2 天');
    const after = await s.read();
    unchangedData(after, before, { targets: false });
    assert.deepEqual(after.targets.filter(target => target.tankId !== added.id), before.targets);
    assert.deepEqual(after.tanks.filter(tank => tank.id !== added.id), before.tanks);
    await s.context.close();
    console.log('PASS: creating a dated tank clears an existing detection draft, preserves old tank data, selects the new tank and persists its age.');
  }

  {
    const s = await scenario();
    const before = await s.read();
    await s.openManager();
    await s.manager.getByRole('button', { name: /添加海缸/ }).click();
    await expect(s.dateInput).toHaveValue('');
    await s.form.getByLabel('海缸名称', { exact: true }).fill('取消创建的海缸');
    await s.dateInput.fill('2026-09-01');
    await s.cancel();
    assert.deepEqual((await s.read()).tanks, before.tanks);
    const added = await s.add('未填写开缸日期的缸');
    assert.equal(added.startedOn, undefined);
    await expect(s.age).toHaveText('设置开缸日期');
    await s.reload();
    await expect(s.age).toHaveText('设置开缸日期');
    const after = await s.read();
    unchangedData(after, before, { targets: false });
    assert.deepEqual(after.targets.filter(target => target.tankId !== added.id), before.targets);
    assert.deepEqual(after.tanks.filter(tank => tank.id !== added.id), before.tanks);
    await s.context.close();
    console.log('PASS: new tanks start with an optional empty setup date; cancel creates nothing and saving/reloading without a date does not fabricate one.');
  }
  assert.deepEqual(errors, []);
} finally {
  await browser.close();
}
