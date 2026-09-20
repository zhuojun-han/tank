import { launchBrowser, baseURL } from './browser-support.mjs';
import assert from 'node:assert/strict';
import { expect } from '@playwright/test';
import { mkdir } from 'node:fs/promises';

const browser = await launchBrowser();
const key = 'reef-demo-state-v10';
const capture = process.env.CAPTURE_SCREENSHOTS === '1';
if (capture) await mkdir('artifacts/chemical-preview', { recursive: true });
try {
  for (const kind of ['lanthanum', 'alkalinity']) {
    const context = await browser.newContext({ viewport: { width: 375, height: 812 } });
    const page = await context.newPage();
    page.setDefaultTimeout(8_000);
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.clock.setFixedTime(new Date('2026-09-08T04:00:00Z'));
    const source = `${kind}-plan`;
    const chemical = kind === 'lanthanum' ? 'po4' : 'kh';
    const sheet = page.locator(`.${kind}-sheet`);
    const current = kind === 'lanthanum' ? 'currentPo4MgL' : 'currentDkh';
    const target = kind === 'lanthanum' ? 'targetPo4MgL' : 'targetDkh';
    const initial = kind === 'lanthanum' ? '0.38' : '6.3';
    const desired = kind === 'lanthanum' ? '0.03' : '8';
    const read = () => page.evaluate(key => JSON.parse(localStorage.getItem(key)), key);
    const ready = () => page.locator('main[aria-busy=false]').waitFor();
    const reload = async () => { await page.reload(); await ready(); };
    const submit = () => sheet.locator('button[type=submit]').click();
    const navTasks = () => page.locator('.bottom-nav').getByRole('button', { name: '✓ 任务' }).click();
    const listCycle = page.locator('.task-list [data-testid=maintenance-cycle-task]');
    const agendaCycle = page.locator('.daily-agenda [data-testid=maintenance-cycle-task]');
    const pending = () => page.getByRole('tab', { name: /^待处理/ }).click();
    const completed = () => page.getByRole('tab', { name: /^已完成/ }).click();
    const date = day => page.locator('.calendar-grid button:not(.outside)').filter({ has: page.locator('.calendar-day-number', { hasText: new RegExp(`^${day}$`) }) }).click();
    const waitCycles = count => page.waitForFunction(({ key, count }) => JSON.parse(localStorage.getItem(key)).maintenanceCycles.length === count, { key, count });
    async function open() {
      await page.getByRole('button', { name: '打开设置' }).click();
      await page.getByRole('button', { name: kind === 'lanthanum' ? /PO4 氯化镧理论计划/ : /碳酸氢钠补 KH 理论计划/ }).click();
      await sheet.locator(`[name=${current}]`).fill(initial);
      await sheet.locator(`[name=${target}]`).fill(desired);
    }
    async function configure() {
      await sheet.getByRole('button', { name: '配置滴定液', exact: true }).click();
      await expect(page.getByLabel('选择指标')).toHaveValue(chemical);
      await expect(page.getByLabel('选择指标')).toBeDisabled();
      await page.getByLabel('单位').selectOption('ml/min');
      await page.getByLabel('泵流速', { exact: true }).fill('100');
      await page.getByLabel('每天运行时间（分钟）').fill('2');
      await page.getByLabel('滴定溶液体积（mL）').fill('250');
    }
    await page.goto(baseURL); await ready();
    await page.waitForFunction(key => !!localStorage.getItem(key), key);
    // A pre-existing finite plan represents real legacy data, not the new workflow.
    await page.evaluate(({ key, source }) => {
      const state = JSON.parse(localStorage.getItem(key));
      const old = (id, date, extra = {}) => ({ id, tankId: state.tankId, title: `旧理论计划 ${id}`, cycle: '计划第 1/4 日',
        due: `${date} 09:00`, scheduledDate: date, state: 'due', source, planId: 'legacy-plan', oneOff: true, dayIndex: 1, totalDays: 4, ...extra });
      state.tasks = [old(900001, '2026-09-08'), old(900002, '2026-09-07', { state: 'done', handledAt: '09:15' }),
        old(900003, '2026-09-07', { state: 'skipped', handledAt: '09:30' }),
        old(900004, '2026-09-08', { tankId: 2 }),
        old(900005, '2026-09-08', { source: source === 'lanthanum-plan' ? 'alkalinity-plan' : 'lanthanum-plan' })];
      state.maintenanceCycles = []; state.notificationEnabled = false;
      localStorage.setItem(key, JSON.stringify(state));
    }, { key, source });
    await reload();
    const baseline = await read();
    await open();
    await sheet.locator(`[name=${target}]`).fill(initial);
    await submit();
    await expect(sheet.getByRole('alert')).toBeVisible();
    assert.deepEqual((await read()).tasks, baseline.tasks, 'invalid calculation keeps legacy tasks');
    await sheet.locator(`[name=${target}]`).fill(desired);
    await submit();
    await expect(sheet.getByText('计算预览 · 配好确认后保存', { exact: true })).toBeVisible();
    assert.deepEqual((await read()).tasks, baseline.tasks, 'calculation never creates or replaces tasks');
    assert.deepEqual((await read()).maintenanceCycles, []);
    const daily = sheet.locator('details').filter({ hasText: '本次计算的全部每日安排' });
    await daily.locator('summary').click();
    assert.equal(await daily.locator('article').count(), 4);
    for (const width of [320, 375]) {
      await page.setViewportSize({ width, height: 812 });
      assert.ok(await sheet.evaluate(node => node.scrollWidth <= node.clientWidth + 1));
    }
    await sheet.getByRole('button', { name: '仅计算，关闭', exact: true }).click();
    await reload();
    assert.deepEqual((await read()).tasks, baseline.tasks, 'preview close/reload preserves the old plan');
    await open(); await submit(); await configure();
    await page.getByRole('button', { name: '关闭滴定计算器' }).click();
    assert.deepEqual((await read()).tasks, baseline.tasks, 'unconfirmed recipe never replaces the old plan');
    assert.deepEqual((await read()).maintenanceCycles, []);
    await open(); await submit(); await configure();
    if (capture) await page.screenshot({ path: `artifacts/chemical-preview/${kind}-recipe.png`, animations: 'disabled' });
    await page.getByRole('button', { name: /^已配好/ }).click(); await waitCycles(1);
    const created = await read();
    const first = created.maintenanceCycles[0];
    assert.equal(first.theory.source, source);
    assert.equal(first.theory.target, Number(desired));
    assert.equal(first.theory.endDate, '2026-09-11');
    assert.ok(first.theory.lastDayRatio > 0 && first.theory.lastDayRatio < 1);
    assert.equal(first.solutionMl, 250); assert.equal(first.dailyLiquidMl, 200);
    assert.equal(first.refillDate, '2026-09-09');
    assert.deepEqual(created.tasks, baseline.tasks.filter(task => task.id !== 900001), 'confirmation replaces only the matching legacy pending plan, preserving history and other tanks/reagents');
    await navTasks(); await pending(); await expect(listCycle).toHaveCount(0);
    await completed(); await expect(listCycle).toHaveCount(1);
    await listCycle.getByRole('button', { name: '提前续配' }).click();
    await expect(page.getByRole('button', { name: /^已配好/ })).toBeDisabled();
    await page.getByRole('radio', { name: '保留残液', exact: true }).check();
    await expect(page.getByLabel('保留残液体积（mL）')).toHaveValue('250');
    await page.getByRole('button', { name: '关闭滴定计算器' }).click();
    assert.deepEqual((await read()).maintenanceCycles, created.maintenanceCycles, 'early-refill cancellation leaves the active cycle unchanged');

    await page.clock.setFixedTime(new Date('2026-09-09T04:00:00Z'));
    await reload(); await navTasks(); await pending(); await expect(listCycle).toHaveCount(1);
    await listCycle.getByRole('button', { name: '添加滴定液' }).click();
    await page.getByRole('radio', { name: '保留残液', exact: true }).check();
    await expect(page.getByLabel('保留残液体积（mL）')).toHaveValue('50');
    await page.getByLabel('滴定溶液体积（mL）').fill('1000');
    await expect(page.getByText('本瓶足够完成计划，无需再次配液', { exact: true })).toBeVisible();
    await page.getByRole('button', { name: /^已配好/ }).click(); await waitCycles(2);
    const refilled = await read();
    const next = refilled.maintenanceCycles[1];
    assert.equal(refilled.maintenanceCycles[0].closedOnDate, '2026-09-09');
    assert.equal(next.retainedMl, 50);
    assert.deepEqual(next.theory, first.theory, 'refilling must not restart or extend the target plan');
    assert.deepEqual(refilled.tasks, created.tasks, 'refilling never produces daily to-do rows');
    await pending(); await expect(listCycle).toHaveCount(0);
    await completed(); await expect(listCycle).toHaveCount(1);
    await date(11); await expect(agendaCycle).toHaveCount(1);
    const shortenedRun = Number((2 * first.theory.lastDayRatio).toFixed(3));
    const finalDayText = await agendaCycle.innerText();
    assert.ok(finalDayText.includes(`运行 ${shortenedRun} min 后停止`), `the final day displays the shorter pump run: ${finalDayText}`);
    await date(12); await expect(agendaCycle).toHaveCount(0);
    await date(9); await completed();
    await listCycle.getByRole('button', { name: '已达目标 / 停止计划' }).click();
    const stop = page.getByRole('alertdialog', { name: '停止理论滴定' });
    await stop.getByRole('button', { name: '取消', exact: true }).click();
    assert.deepEqual((await read()).maintenanceCycles, refilled.maintenanceCycles);
    await listCycle.getByRole('button', { name: '已达目标 / 停止计划' }).click();
    await stop.getByRole('button', { name: '确认停止', exact: true }).click();
    await page.waitForFunction(({ key, id }) => JSON.parse(localStorage.getItem(key)).maintenanceCycles.find(cycle => cycle.id === id).closedOnDate === '2026-09-09', { key, id: next.id });
    await reload(); await navTasks(); await pending(); await expect(listCycle).toHaveCount(0);
    await date(10); await expect(agendaCycle).toHaveCount(0);
    assert.deepEqual((await read()).tasks, created.tasks);
    assert.deepEqual((await read()).records, baseline.records);
    assert.deepEqual(errors, []);
    console.log(`PASS ${kind}: preview/cancel preserves data; confirmed pump recipe scopes legacy replacement; no daily todos; residual refill keeps plan end; partial final run; target-stop persists; narrow layout.`);
    await context.close();
  }
} finally { await browser.close(); }
