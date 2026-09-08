import assert from 'node:assert/strict';
import { mkdir } from 'node:fs/promises';
import { expect } from '@playwright/test';
import { launchBrowser, baseURL } from './browser-support.mjs';

const key = 'reef-demo-state-v10';
const browser = await launchBrowser();
const errors = [];
const duplicateKeys = [];
await mkdir('tests/artifacts', { recursive: true });

const task = (id, title, date, overrides = {}) => ({
  id, tankId: 1, title, cycle: '每 7 天', due: `${date} 09:00`, state: 'due',
  source: 'manual', scheduledDate: date, intervalDays: 7,
  rolling: { version: 1, nextDate: date, revision: 0, completed: [] },
  ...overrides,
});

async function scenario(tasks = [], start = '2026-09-08T23:55:00') {
  const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
  const page = await context.newPage();
  page.setDefaultTimeout(8_000);
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (['error', 'warning'].includes(message.type()) && /same key|unique ["']?key|duplicate key/i.test(message.text())) {
      duplicateKeys.push(message.text());
    }
  });
  const at = value => page.evaluate(value => new Date(value).getTime(), value);
  await page.clock.install({ time: await at(start) });
  await page.goto(`${baseURL}/`);
  await page.locator('main[aria-busy=false]').waitFor();
  await page.waitForFunction(key => !!localStorage.getItem(key), key);
  await page.evaluate(({ key, tasks }) => {
    const state = JSON.parse(localStorage.getItem(key));
    state.tasks = tasks; state.maintenanceCycles = []; state.notificationEnabled = false;
    localStorage.setItem(key, JSON.stringify(state));
  }, { key, tasks });
  const reload = async () => { await page.reload(); await page.locator('main[aria-busy=false]').waitFor(); };
  await reload();
  const read = () => page.evaluate(key => JSON.parse(localStorage.getItem(key)), key);
  const raw = () => page.evaluate(key => localStorage.getItem(key), key);
  const nav = label => page.locator('.bottom-nav button').filter({ hasText: label }).click();
  const day = date => page.locator('.calendar-grid button:not(.outside)').filter({
    has: page.locator('.calendar-day-number', { hasText: new RegExp(`^${date}$`) }),
  });
  const onDay = (date, title) => day(date).locator('.calendar-day-tasks small').filter({ hasText: title });
  const agenda = title => page.locator('.daily-agenda article').filter({ hasText: title });
  const history = title => page.locator('.task-list article').filter({ hasText: title });
  const dialog = page.getByTestId('task-action-dialog');
  const switchTank = async name => {
    await page.locator('.tank-switcher').click();
    await page.locator('.tank-popover button').filter({ hasText: name }).click();
    await expect(page.locator('.tank-switcher strong')).toHaveText(name);
  };
  const nextDate = (id, date) => page.waitForFunction(({ key, id, date }) => JSON.parse(localStorage.getItem(key)).tasks.find(task => task.id === id)?.rolling?.nextDate === date, { key, id, date });
  const openDosing = async () => {
    await page.getByRole('button', { name: '打开设置' }).click();
    await page.getByRole('button', { name: /稳定滴定配方/ }).click();
  };
  const submitDosing = () => page.getByRole('button', { name: /^已配好/ }).click();
  const waitCycles = count => page.waitForFunction(({ key, count }) => JSON.parse(localStorage.getItem(key)).maintenanceCycles.length === count, { key, count });
  const jump = async date => {
    await page.clock.setSystemTime(await at(date));
    await page.evaluate(() => window.dispatchEvent(new Event('focus')));
  };
  return { context, page, read, raw, reload, nav, day, onDay, agenda, history, dialog, switchTank, nextDate, openDosing, submitDosing, waitCycles, jump };
}

try {
  // A single unresolved occurrence rolls forward; actual completion determines its next reminder.
  {
    let title = '刷藻顺延回归';
    const s = await scenario([task(101, title, '2026-09-07'), task(202, '另一缸刷藻', '2026-09-07', { tankId: 2 })]);
    const before = await s.read();
    await s.nav('任务');
    await expect(s.onDay(8, title)).toHaveCount(1);
    await expect(s.onDay(15, title)).toHaveCount(1);
    await expect(s.onDay(7, title)).toHaveCount(0);
    await s.page.clock.fastForward(310_000);
    await expect(s.page.locator('.calendar-grid button.today .calendar-day-number')).toHaveText('9');
    await expect(s.onDay(9, title)).toHaveCount(1);
    await expect(s.onDay(16, title)).toHaveCount(1);
    await expect(s.onDay(8, title)).toHaveCount(0);
    assert.deepEqual((await s.read()).tasks, before.tasks, 'Midnight projections must not rewrite task history.');
    const beforeCancel = await s.raw();
    await s.agenda(title).getByRole('button', { name: /延迟/ }).click();
    await expect(s.dialog.getByLabel('延迟天数', { exact: true })).toHaveValue('1');
    await s.dialog.getByRole('button', { name: '取消', exact: true }).click();
    assert.equal(await s.raw(), beforeCancel);
    await s.agenda(title).getByRole('button', { name: /延迟/ }).click();
    for (const value of ['', '0', '-1', '1.5', '9007199254740992']) {
      await s.dialog.getByLabel('延迟天数', { exact: true }).fill(value);
      await s.dialog.getByRole('button', { name: '确认延迟', exact: true }).click();
      await expect(s.dialog.getByRole('alert')).toBeVisible();
      assert.equal(await s.raw(), beforeCancel);
    }
    await s.dialog.getByLabel('延迟天数', { exact: true }).fill('3');
    await s.page.screenshot({ path: 'tests/artifacts/task-delay-dialog-390.png', fullPage: true, animations: 'disabled' });
    await s.dialog.getByRole('button', { name: '确认延迟', exact: true }).click();
    await s.nextDate(101, '2026-09-12');
    await expect(s.onDay(12, title)).toHaveCount(1);
    await expect(s.onDay(19, title)).toHaveCount(1);
    await expect(s.onDay(16, title)).toHaveCount(0);
    await s.day(12).click();
    await s.agenda(title).getByRole('button', { name: /完成/ }).click();
    await expect(s.dialog.getByLabel('实际完成日期', { exact: true })).toHaveValue('2026-09-09');
    const delayed = await s.raw();
    await s.dialog.getByLabel('实际完成日期', { exact: true }).fill('2026-09-10');
    await s.dialog.getByRole('button', { name: '确认完成', exact: true }).click();
    await expect(s.dialog.getByRole('alert')).toContainText('不能晚于今天');
    assert.equal(await s.raw(), delayed);
    await s.dialog.getByRole('button', { name: '取消', exact: true }).click();
    assert.equal(await s.raw(), delayed);
    await s.agenda(title).getByRole('button', { name: /完成/ }).click();
    await s.dialog.getByLabel('实际完成日期', { exact: true }).fill('2026-09-08');
    await s.dialog.getByRole('button', { name: '确认完成', exact: true }).click();
    await s.nextDate(101, '2026-09-15');
    let saved = (await s.read()).tasks.find(task => task.id === 101);
    assert.deepEqual(saved.rolling.completed, [{ dueDate: '2026-09-12', completedDate: '2026-09-08' }]);
    await s.day(8).click();
    await s.page.getByRole('tab', { name: /^已完成/ }).click();
    await s.history(title).getByRole('button', { name: '修改完成日期', exact: true }).click();
    await expect(s.dialog.getByLabel('实际完成日期', { exact: true })).toHaveValue('2026-09-08');
    await s.dialog.getByLabel('实际完成日期', { exact: true }).fill('2026-09-07');
    await s.dialog.getByRole('button', { name: '确认完成', exact: true }).click();
    await s.nextDate(101, '2026-09-14');
    saved = (await s.read()).tasks.find(task => task.id === 101);
    assert.deepEqual(saved.rolling.completed, [{ dueDate: '2026-09-12', completedDate: '2026-09-07' }]);
    assert.deepEqual((await s.read()).tasks.find(task => task.id === 202), before.tasks.find(task => task.id === 202));
    await s.reload();
    await s.nav('任务');
    await expect(s.onDay(14, title)).toHaveCount(1);
    await s.day(7).click();
    await s.page.getByRole('tab', { name: /^已完成/ }).click();
    await expect(s.history(title)).toHaveCount(1);
    const historyBeforeRename = (await s.read()).tasks.find(task => task.id === 101).rolling.completed;
    await s.history(title).getByRole('button', { name: `编辑${title}`, exact: true }).click();
    await expect(s.page.getByLabel('开始日期', { exact: true })).toHaveValue('2026-09-14');
    const renamed = `${title}（改名）`;
    await s.page.getByLabel('任务名称', { exact: true }).fill(renamed);
    await s.page.getByRole('button', { name: '保存修改', exact: true }).click();
    await s.page.waitForFunction(({ key, title }) => JSON.parse(localStorage.getItem(key)).tasks.find(task => task.id === 101)?.title === title, { key, title: renamed });
    title = renamed;
    assert.equal((await s.read()).tasks.find(task => task.id === 101).rolling.nextDate, '2026-09-14');
    assert.deepEqual((await s.read()).tasks.find(task => task.id === 101).rolling.completed, historyBeforeRename);
    await expect(s.onDay(14, title)).toHaveCount(1);
    await s.history(title).getByRole('button', { name: '重新标记为未完成', exact: true }).click();
    await s.nextDate(101, '2026-09-12');
    assert.deepEqual((await s.read()).tasks.find(task => task.id === 101).rolling.completed, []);
    await expect(s.onDay(12, title)).toHaveCount(1);
    await expect(s.onDay(14, title)).toHaveCount(0);
    await s.switchTank('小丑鱼缸');
    await expect(s.onDay(9, '另一缸刷藻')).toHaveCount(1);
    assert.deepEqual((await s.read()).records, before.records);
    await s.context.close();
    console.log('PASS: midnight rollover, integer-only/cancellable delay, actual completion/correction/reopen, reload and other-tank isolation.');
  }

  // Defer a finite chemical plan's unresolved head without merging, multiplying or changing doses.
  {
    const chemical = (id, dayIndex, tankId = 1, source = 'lanthanum-plan', planId = 'finite-po4') => task(id, `${source === 'lanthanum-plan' ? 'PO4 顺延' : 'KH 对照'}第${dayIndex}日`, `2026-09-0${6 + dayIndex}`, {
      tankId, source, planId, intervalDays: undefined, oneOff: true, dayIndex, totalDays: 3,
      cycle: `计划第 ${dayIndex}/3 日`, detail: `原始母液 ${dayIndex}.25 mL；先复测后决定。`,
    });
    const s = await scenario([chemical(301, 1), chemical(302, 2), chemical(303, 3),
      chemical(401, 1, 2), chemical(501, 1, 1, 'alkalinity-plan', 'finite-kh')], '2026-09-08T12:00:00');
    const before = await s.read();
    await s.nav('任务');
    await expect(s.onDay(8, 'PO4 顺延第1日')).toHaveCount(1);
    await s.day(8).click();
    const head = s.agenda('PO4 顺延第1日');
    await head.getByRole('button', { name: /延迟/ }).click();
    await s.dialog.getByLabel('延迟天数', { exact: true }).fill('2');
    await s.dialog.getByRole('button', { name: '确认延迟', exact: true }).click();
    await s.nextDate(301, '2026-09-10');
    const saved = (await s.read()).tasks;
    assert.equal(saved.length, before.tasks.length);
    for (const [index, id] of [301, 302, 303].entries()) {
      const old = before.tasks.find(task => task.id === id);
      const current = saved.find(task => task.id === id);
      assert.equal(current.rolling.nextDate, `2026-09-${10 + index}`);
      for (const field of ['id', 'tankId', 'title', 'source', 'planId', 'dayIndex', 'totalDays', 'detail', 'scheduledDate', 'due']) {
        assert.deepEqual(current[field], old[field], `Delay must preserve chemical ${field}.`);
      }
      assert.deepEqual(current.rolling.completed, []);
      await expect(s.onDay(10 + index, current.title)).toHaveCount(1);
    }
    for (const id of [401, 501]) assert.deepEqual(saved.find(task => task.id === id), before.tasks.find(task => task.id === id));
    await s.reload();
    assert.deepEqual((await s.read()).tasks, saved);
    await s.jump('2026-09-13T12:00:00');
    await s.nav('任务');
    await s.day(13).click();
    await expect(s.onDay(13, 'PO4 顺延第1日')).toHaveCount(1);
    await s.agenda('PO4 顺延第1日').getByRole('button', { name: '停止后续计划', exact: true }).click();
    await s.page.waitForFunction(key => JSON.parse(localStorage.getItem(key)).tasks.find(task => task.id === 301)?.state === 'skipped', key);
    const stopped = (await s.read()).tasks;
    assert.deepEqual(stopped.find(task => task.id === 301).skippedDates, ['2026-09-13']);
    assert.ok([301, 302, 303].every(id => stopped.find(task => task.id === id).state === 'skipped'));
    await expect(s.onDay(14, 'PO4 顺延第2日')).toHaveCount(0);
    await expect(s.onDay(15, 'PO4 顺延第3日')).toHaveCount(0);
    for (const id of [401, 501]) assert.deepEqual(stopped.find(task => task.id === id), before.tasks.find(task => task.id === id));
    assert.deepEqual((await s.read()).records, before.records);
    await s.context.close();
    console.log('PASS: finite chemical delay preserves three ordered doses, metadata, other reagent/tank and refreshed storage.');
  }

  // Refill postponement belongs to one bottle. Actual replacement clears only its reminder.
  {
    const s = await scenario([], '2026-09-08T12:00:00');
    const before = await s.read();
    const create = async chemical => {
      const count = (await s.read()).maintenanceCycles.length;
      await s.openDosing();
      await s.page.getByLabel('选择指标', { exact: false }).selectOption(chemical);
      await s.page.getByLabel('实际配液日期', { exact: true }).fill('2026-09-03');
      await s.submitDosing();
      await s.waitCycles(count + 1);
    };
    await create('po4');
    await create('kh');
    await s.switchTank('小丑鱼缸');
    await create('po4');
    await s.switchTank('客厅主缸');
    const cycles = (await s.read()).maintenanceCycles;
    const oldPo4 = cycles.find(cycle => cycle.tankId === 1 && cycle.chemical === 'po4');
    assert.ok(cycles.every(cycle => cycle.startDate === '2026-09-03' && cycle.refillDate === '2026-09-08'));
    const home = chemical => s.page.locator('.home-todos').getByTestId('maintenance-cycle-task').filter({ hasText: chemical });
    await expect(home('PO₄')).toHaveCount(1);
    await expect(home('KH')).toHaveCount(1);
    await home('PO₄').getByRole('button', { name: /延迟/ }).click();
    await expect(s.dialog.getByLabel('延迟天数', { exact: true })).toHaveValue('1');
    await s.dialog.getByLabel('延迟天数', { exact: true }).fill('2');
    await s.dialog.getByRole('button', { name: '确认延迟', exact: true }).click();
    await s.page.waitForFunction(({ key, id }) => JSON.parse(localStorage.getItem(key)).maintenanceCycles.find(cycle => cycle.id === id)?.refillDeferredUntil === '2026-09-10', { key, id: oldPo4.id });
    await expect(home('PO₄')).toHaveCount(0);
    await expect(home('KH')).toHaveCount(1);
    const delayed = await s.raw();
    await s.openDosing();
    await s.page.getByLabel('实际配液日期', { exact: true }).fill('2026-09-07');
    await s.page.getByRole('button', { name: '关闭滴定计算器', exact: true }).click();
    assert.equal(await s.raw(), delayed);
    await s.openDosing();
    await s.page.getByLabel('上次滴定液还有残留吗？').selectOption('no');
    await s.page.getByLabel('每日 PO₄ 上升（mg/L）', { exact: true }).fill('0.03');
    await s.page.getByLabel('实际配液日期', { exact: true }).fill('2026-09-09');
    if (await s.page.getByRole('button', { name: /^已配好/ }).isEnabled()) {
      await s.submitDosing();
      await expect(s.page.getByRole('dialog').getByRole('alert')).toBeVisible();
    }
    assert.equal(await s.raw(), delayed);
    await s.page.getByLabel('实际配液日期', { exact: true }).fill('2026-09-07');
    await s.submitDosing();
    await s.waitCycles(4);
    const after = (await s.read()).maintenanceCycles;
    const replacement = after.find(cycle => !cycles.some(old => old.id === cycle.id));
    assert.ok(replacement);
    assert.equal(replacement.tankId, 1);
    assert.equal(replacement.chemical, 'po4');
    assert.equal(replacement.startDate, '2026-09-07');
    assert.equal(replacement.refillDate, '2026-09-12');
    assert.equal(replacement.input.po4Rise, 0.03);
    assert.equal(replacement.previousCycleId, oldPo4.id);
    assert.equal(replacement.refillDeferredUntil, undefined);
    assert.equal(after.find(cycle => cycle.id === oldPo4.id).closedOnDate, '2026-09-07');
    for (const control of cycles.filter(cycle => cycle.id !== oldPo4.id)) assert.deepEqual(after.find(cycle => cycle.id === control.id), control);
    await s.jump('2026-09-10T12:00:00');
    await expect(home('PO₄')).toHaveCount(0);
    await expect(home('KH')).toHaveCount(1);
    await s.reload();
    await expect(home('PO₄')).toHaveCount(0);
    await expect(home('KH')).toHaveCount(1);
    await s.switchTank('小丑鱼缸');
    await expect(home('PO₄')).toHaveCount(1);
    assert.deepEqual((await s.read()).records, before.records);
    assert.deepEqual((await s.read()).tasks, []);
    await s.context.close();
    console.log('PASS: backdated preparation, two-day refill delay, future-date/cancel rejection and changed-dose replacement clear only the same tank/reagent reminder.');
  }

  // One bottle can appear in today's status and a future reminder, but its catalog card is unique.
  {
    const s = await scenario([], '2026-09-08T12:00:00');
    await s.openDosing();
    await expect(s.page.getByLabel('实际配液日期', { exact: true })).toHaveValue('2026-09-08');
    await s.submitDosing();
    await s.waitCycles(1);
    const cycle = (await s.read()).maintenanceCycles[0];
    assert.equal(cycle.refillDate, '2026-09-13');
    await s.nav('任务');
    await s.day(13).click();
    await s.page.locator('.daily-agenda').getByTestId('maintenance-cycle-task').getByRole('button', { name: '延迟', exact: true }).click();
    await expect(s.dialog.getByLabel('延迟天数', { exact: true })).toHaveValue('1');
    await s.dialog.getByRole('button', { name: '确认延迟', exact: true }).click();
    await s.page.waitForFunction(key => JSON.parse(localStorage.getItem(key)).maintenanceCycles[0]?.refillDeferredUntil === '2026-09-14', key);
    await s.page.getByRole('tab', { name: /^全部/ }).click();
    await expect(s.page.locator('.task-list').getByTestId('maintenance-cycle-task')).toHaveCount(1);
    await s.day(14).click();
    await expect(s.page.locator('.daily-agenda').getByTestId('maintenance-cycle-task')).toHaveCount(1);
    await expect(s.page.locator('.task-list').getByTestId('maintenance-cycle-task')).toHaveCount(1);
    await s.page.locator('.task-calendar').screenshot({ path: 'tests/artifacts/deferred-refill-calendar-390.png', animations: 'disabled' });
    assert.equal((await s.read()).maintenanceCycles.length, 1);
    await s.context.close();
    console.log('PASS: postponing a new bottle\'s future refill leaves one all-tasks catalog card without duplicate React keys.');
  }
  assert.deepEqual(errors, []);
  assert.deepEqual(duplicateKeys, []);
} finally {
  await browser.close();
}
