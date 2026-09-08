import assert from 'node:assert/strict';
import { expect } from '@playwright/test';
import { launchBrowser, baseURL } from './browser-support.mjs';

const key = 'reef-demo-state-v10';
const browser = await launchBrowser();
const errors = [];

async function scenario(start = '2026-09-08T23:55:00') {
  const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
  const page = await context.newPage();
  page.setDefaultTimeout(8_000);
  page.on('pageerror', error => errors.push(error.message));
  // Interpret fixture dates in the browser's configured TEST_TIMEZONE.
  const at = localDate => page.evaluate(value => new Date(value).getTime(), localDate);
  await page.clock.install({ time: await at(start) });
  await page.goto(`${baseURL}/`);
  await page.locator('main[aria-busy=false]').waitFor();
  await page.waitForFunction(key => !!localStorage.getItem(key), key);
  await page.evaluate(key => {
    const state = JSON.parse(localStorage.getItem(key));
    state.tasks = []; state.maintenanceCycles = []; state.notificationEnabled = false;
    localStorage.setItem(key, JSON.stringify(state));
  }, key);
  await page.reload();
  await page.locator('main[aria-busy=false]').waitFor();
  const read = () => page.evaluate(key => JSON.parse(localStorage.getItem(key)), key);
  const nav = label => page.locator('.bottom-nav button').filter({ hasText: label }).click();
  const card = scope => page.locator(scope).getByTestId('maintenance-cycle-task');
  const date = day => page.locator('.calendar-grid button:not(.outside)').filter({
    has: page.locator('.calendar-day-number', { hasText: new RegExp(`^${day}$`) }),
  });
  const open = async () => {
    await page.getByRole('button', { name: '打开设置' }).click();
    await page.getByRole('button', { name: /稳定滴定配方/ }).click();
  };
  const close = () => page.getByRole('button', { name: '关闭滴定计算器', exact: true }).click();
  const submit = () => page.getByRole('button', { name: /^已配好/ }).click();
  const waitCycles = count => page.waitForFunction(({ key, count }) => JSON.parse(localStorage.getItem(key)).maintenanceCycles.length === count, { key, count });
  const create = async chemical => {
    const count = (await read()).maintenanceCycles.length;
    await open();
    await page.getByLabel('选择指标').selectOption(chemical);
    await page.getByLabel('泵流速', { exact: true }).fill('1.4');
    await page.getByLabel('每天运行时间（分钟）', { exact: true }).fill('1');
    await page.getByLabel('滴定溶液体积（mL）', { exact: true }).fill('500');
    await submit();
    await waitCycles(count + 1);
  };
  const setTime = async localDate => page.clock.setSystemTime(await at(localDate));
  const focus = () => page.evaluate(() => window.dispatchEvent(new Event('focus')));
  const visibility = state => page.evaluate(state => {
    // Simulate a suspended tab's lifecycle notification without claiming OS background coverage.
    Object.defineProperty(document, 'visibilityState', { configurable: true, value: state });
    Object.defineProperty(document, 'hidden', { configurable: true, value: state === 'hidden' });
    document.dispatchEvent(new Event('visibilitychange'));
    if (state === 'visible') { delete document.visibilityState; delete document.hidden; }
  }, state);
  return { context, page, read, nav, card, date, open, close, submit, waitCycles, create, setTime, focus, visibility };
}

try {
  // Six calendar days for 500 / 84 = 5.95238 days, with a separate overdue reminder.
  {
    const s = await scenario();
    const before = await s.read();
    await s.create('po4');
    await s.create('kh');
    const cycles = (await s.read()).maintenanceCycles;
    assert.equal(cycles.length, 2);
    assert.ok(cycles.every(cycle => cycle.dailyLiquidMl === 84 && cycle.refillDate === '2026-09-13'));
    await expect(s.card('.home-dosing-status')).toHaveCount(2);
    await expect(s.card('.home-dosing-status').filter({ hasText: '5.95 天' })).toHaveCount(2);
    await expect(s.card('.home-todos')).toHaveCount(0);
    await s.nav('任务');
    await s.page.getByRole('tab', { name: /^待处理/ }).click();
    await expect(s.card('.task-list')).toHaveCount(0);
    await s.page.getByRole('tab', { name: /^已完成/ }).click();
    await expect(s.card('.task-list').filter({ hasText: '5.95 天' })).toHaveCount(2);
    await expect(s.page.locator('.calendar-day-tasks small')).toHaveCount(12);
    await s.date(13).click();
    await expect(s.card('.daily-agenda').filter({ hasText: '添加滴定液' })).toHaveCount(2);
    await expect(s.card('.task-list')).toHaveCount(0);
    await s.date(14).click();
    await expect(s.card('.daily-agenda')).toHaveCount(0);
    await s.page.locator('.calendar-head').getByRole('button', { name: '今天', exact: true }).click();

    await s.page.clock.fastForward(310_000); // Live midnight: no reload, focus or visibility event.
    await expect(s.page.locator('.calendar-grid button.today .calendar-day-number')).toHaveText('9');
    await expect(s.page.locator('.calendar-grid button.selected .calendar-day-number')).toHaveText('9');
    await expect(s.card('.task-list').filter({ hasText: '4.95 天' })).toHaveCount(2);
    await expect(s.card('.daily-agenda').filter({ hasText: /416\s*m[lL]/ })).toHaveCount(2);
    await s.nav('首页');
    await expect(s.card('.home-dosing-status').filter({ hasText: '4.95 天' })).toHaveCount(2);
    await expect(s.card('.home-todos')).toHaveCount(0);

    await s.setTime('2026-09-13T12:00:00');
    await s.focus();
    await expect(s.card('.home-dosing-status')).toHaveCount(0);
    await expect(s.card('.home-todos').filter({ hasText: '待处理' })).toHaveCount(2);
    await expect(s.card('.home-todos').filter({ hasText: '0.952 天' })).toHaveCount(2);
    await s.setTime('2026-09-14T12:00:00');
    await s.focus();
    await expect(s.card('.home-todos').filter({ hasText: '0.00 天' })).toHaveCount(2);
    await s.nav('任务');
    await s.page.getByRole('tab', { name: /^待处理/ }).click();
    await expect(s.card('.task-list')).toHaveCount(2);
    await s.date(14).click();
    await expect(s.card('.daily-agenda')).toHaveCount(0);
    await s.date(15).click();
    await expect(s.card('.daily-agenda')).toHaveCount(0);
    await expect(s.page.locator('.calendar-day-tasks small')).toHaveCount(12);
    assert.deepEqual((await s.read()).maintenanceCycles, cycles);
    assert.deepEqual((await s.read()).records, before.records);
    assert.deepEqual((await s.read()).tasks, []);
    await s.context.close();
    console.log('PASS: PO4/KH day-one 5.95 and day-two 4.95, separate completed home cards, six finite calendar dates, last-day and overdue reminders without future repetition.');
  }

  // Existing liquid ages daily; the full replacement recipe's lifetime does not.
  {
    const s = await scenario();
    const before = await s.read();
    await s.create('po4');
    const previous = (await s.read()).maintenanceCycles[0];
    await s.open();
    await s.page.getByLabel('上次滴定液还有残留吗？').selectOption('yes');
    const remaining = s.page.getByLabel('保留残液体积（mL）');
    await expect(remaining).toHaveValue('500');
    await expect(s.page.getByTestId('maintenance-remaining-days')).toContainText('5.95 天');
    await expect(s.page.getByTestId('maintenance-days')).toContainText('5.95 天');
    await s.page.clock.fastForward(310_000);
    await expect(remaining).toHaveValue('416');
    await expect(s.page.getByTestId('maintenance-remaining-days')).toContainText('4.95 天');
    await expect(s.page.getByTestId('maintenance-days')).toContainText('5.95 天');
    await s.page.screenshot({ path: 'artifacts/maintenance-live-midnight.png', fullPage: true, animations: 'disabled' });
    await remaining.fill('450');
    await s.page.getByLabel('净水量（L）', { exact: true }).fill('201');
    await s.page.getByLabel('净水量（L）', { exact: true }).fill('200');
    await expect(remaining).toHaveValue('450');
    await s.page.clock.fastForward(86_400_000);
    await expect(remaining).toHaveValue('450');
    await expect(s.page.getByTestId('maintenance-remaining-days')).toContainText('3.95 天');
    await expect(remaining.locator('..').locator('small')).toContainText('332');
    await s.close();
    assert.deepEqual((await s.read()).maintenanceCycles, [previous]);
    await s.open();
    await s.page.getByLabel('上次滴定液还有残留吗？').selectOption('yes');
    await expect(remaining).toHaveValue('332');
    await remaining.fill('300');
    // Jump the wall clock without lifecycle events or timer execution: confirm must use the real day.
    await s.setTime('2026-09-11T00:00:01');
    await s.submit();
    await s.waitCycles(2);
    const [closed, replacement] = (await s.read()).maintenanceCycles;
    assert.equal(closed.closedOnDate, '2026-09-11');
    assert.equal(replacement.startDate, '2026-09-11');
    assert.equal(replacement.previousCycleId, previous.id);
    assert.equal(replacement.retainedMl, 300);
    assert.deepEqual((await s.read()).records, before.records);
    assert.deepEqual((await s.read()).tasks, []);
    await s.context.close();
    console.log('PASS: open-panel automatic residual ages across midnight; manual amount survives rerenders/days, reopening refreshes it, and confirmation dates the new cycle from the real wall clock.');
  }

  // Calendar navigation belongs to the user; foreground recovery updates only the current-day state.
  {
    const s = await scenario('2026-09-30T23:55:00');
    await s.create('po4');
    const cycles = (await s.read()).maintenanceCycles;
    await s.nav('任务');
    await s.page.clock.fastForward(310_000);
    await expect(s.page.locator('.calendar-head strong')).toContainText('10月');
    await expect(s.page.locator('.calendar-grid button.today .calendar-day-number')).toHaveText('1');
    await expect(s.page.locator('.calendar-grid button.selected .calendar-day-number')).toHaveText('1');
    await s.date(3).click();
    await s.visibility('hidden');
    await s.setTime('2026-10-02T12:00:00');
    await s.visibility('visible');
    await expect(s.page.locator('.calendar-grid button.today .calendar-day-number')).toHaveText('2');
    await expect(s.page.locator('.calendar-grid button.selected .calendar-day-number')).toHaveText('3');
    await s.setTime('2026-10-04T12:00:00');
    await s.focus();
    await expect(s.page.locator('.calendar-grid button.today .calendar-day-number')).toHaveText('4');
    await expect(s.page.locator('.calendar-grid button.selected .calendar-day-number')).toHaveText('3');
    await s.nav('首页');
    await expect(s.card('.home-dosing-status')).toContainText('1.95 天');
    await s.nav('任务');
    await s.page.getByRole('button', { name: '上个月', exact: true }).click();
    await expect(s.page.locator('.calendar-head strong')).toContainText('9月');
    await s.setTime('2026-11-01T12:00:00');
    await s.focus();
    await expect(s.page.locator('.calendar-head strong')).toContainText('9月');
    await expect(s.page.locator('.calendar-grid button.selected .calendar-day-number')).toHaveText('1');
    assert.deepEqual((await s.read()).maintenanceCycles, cycles);
    assert.deepEqual((await s.read()).tasks, []);
    await s.context.close();
    console.log('PASS: live month rollover follows today; visibility/focus recovery updates dates without overriding user-selected future/history days or month.');
  }
  assert.deepEqual(errors, []);
} finally {
  await browser.close();
}
