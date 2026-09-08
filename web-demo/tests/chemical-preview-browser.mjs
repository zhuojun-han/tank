import { launchBrowser, baseURL } from './browser-support.mjs';
import assert from 'node:assert/strict';
import { mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
const browser = await launchBrowser();
const output = new URL('../artifacts/chemical-preview/', import.meta.url);
await mkdir(output, { recursive: true });
try {
  for (const kind of ['lanthanum', 'alkalinity']) {
    const page = await browser.newPage({ viewport: { width: 375, height: 812 } });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    const source = `${kind}-plan`;
    const sheet = page.locator(`.${kind}-sheet`);
    const conflict = page.getByRole('dialog', { name: '覆盖原计划？' });
    const current = kind === 'lanthanum' ? 'currentPo4MgL' : 'currentDkh';
    const target = kind === 'lanthanum' ? 'targetPo4MgL' : 'targetDkh';
    const initial = kind === 'lanthanum' ? '0.43' : '6';
    const desired = kind === 'lanthanum' ? '0.03' : '8';
    const tasks = () => page.evaluate(() => JSON.parse(localStorage.getItem('reef-demo-state-v10')).tasks);
    async function open() {
      await page.getByRole('button', { name: '打开设置' }).click();
      await page.getByRole('button', { name: kind === 'lanthanum' ? /PO4 氯化镧理论计划/ : /碳酸氢钠补 KH 理论计划/ }).click();
      await sheet.locator(`[name="${current}"]`).fill(initial);
      await sheet.locator(`[name="${target}"]`).fill(desired);
    }
    async function submit() { await sheet.locator('button[type="submit"]').click(); }
    await page.goto(`${baseURL}`, { waitUntil: 'networkidle' });
    await open();
    await submit();
    await sheet.getByText('✓ 已加入任务日历', { exact: true }).waitFor();
    assert.equal((await tasks()).filter(t => t.source === source).length, 4);
    // Preserve real generated plan structure while supplying done/skipped history,
    // a previous-date task, another reagent and another tank as control records.
    await page.evaluate(source => {
      const state = JSON.parse(localStorage.getItem('reef-demo-state-v10'));
      const generated = state.tasks.filter(t => t.source === source);
      generated[0].state = 'done'; generated[0].handledAt = '09:15';
      generated[1].state = 'skipped'; generated[1].handledAt = '09:30';
      const past = new Date(`${generated[0].scheduledDate}T12:00:00`);
      past.setDate(past.getDate() - 1);
      const date = `${past.getFullYear()}-${String(past.getMonth()+1).padStart(2,'0')}-${String(past.getDate()).padStart(2,'0')}`;
      state.tasks.push({ ...generated[0], id: 900001, scheduledDate: date });
      state.tasks.push({ ...generated[0], id: 900002, tankId: 999, planId: 'other-tank' });
      state.tasks.push({ ...generated[0], id: 900003, source: source === 'lanthanum-plan' ? 'alkalinity-plan' : 'lanthanum-plan', planId: 'other-reagent' });
      localStorage.setItem('reef-demo-state-v10', JSON.stringify(state));
    }, source);
    await page.reload({ waitUntil: 'networkidle' });
    const baseline = await tasks();
    await open();
    await sheet.locator(`[name="${target}"]`).fill(initial);
    await submit();
    await sheet.getByRole('alert').waitFor();
    assert.equal(await conflict.count(), 0);
    assert.deepEqual(await tasks(), baseline, 'invalid input must not mutate tasks');
    await sheet.locator(`[name="${target}"]`).fill(desired);
    await submit();
    await conflict.getByRole('button', { name: '取消，保留原计划' }).click();
    assert.deepEqual(await tasks(), baseline, 'cancel must preserve all tasks');
    assert.equal(await sheet.locator(`[name="${current}"]`).inputValue(), initial);
    await submit();
    for (const width of [320, 375]) {
      await page.setViewportSize({ width, height: 812 });
      await page.screenshot({ animations: 'disabled', path: fileURLToPath(new URL(`${kind}-conflict-${width}.png`, output)) });
    }
    await conflict.getByRole('button', { name: '仅计算，不覆盖原计划' }).click();
    await sheet.getByText('仅计算预览 · 未加入日历，原计划和处理记录保持不变', { exact: true }).waitFor();
    assert.equal(await sheet.getByText('✓ 已加入任务日历', { exact: true }).count(), 0);
    assert.equal(await sheet.getByRole('button', { name: '查看已加入的任务日历' }).count(), 0);
    assert.deepEqual(await tasks(), baseline, 'preview must preserve every task field and history');
    const daily = sheet.locator('details').filter({ hasText: '本次计算的全部每日安排' });
    await daily.locator('summary').click();
    assert.equal(await daily.locator('article').count(), 4);
    for (const width of [320, 375]) {
      await page.setViewportSize({ width, height: 812 });
      await sheet.evaluate(node => { node.scrollTop = 0; });
      assert.ok(await sheet.evaluate(node => node.scrollWidth <= node.clientWidth + 1));
      await page.screenshot({ animations: 'disabled', path: fileURLToPath(new URL(`${kind}-preview-${width}.png`, output)) });
      await daily.scrollIntoViewIfNeeded();
      await page.screenshot({ animations: 'disabled', path: fileURLToPath(new URL(`${kind}-daily-${width}.png`, output)) });
    }
    await sheet.getByRole('button', { name: '关闭计算结果' }).click();
    await page.reload({ waitUntil: 'networkidle' });
    assert.deepEqual(await tasks(), baseline, 'preview and close/reload must not persist new tasks');
    await open();
    await sheet.locator(`[name="${current}"]`).fill(kind === 'lanthanum' ? '0.33' : '6.5');
    await submit();
    await conflict.getByRole('button', { name: '覆盖并创建新计划' }).click();
    await sheet.getByText('✓ 已加入任务日历', { exact: true }).waitFor();
    const replaced = await tasks();
    for (const id of [900001, 900002, 900003]) assert.deepEqual(replaced.find(t => t.id === id), baseline.find(t => t.id === id));
    const activeNew = replaced.filter(t => t.source === source && t.tankId !== 999 && t.id !== 900001);
    assert.equal(activeNew.length, 3);
    assert.ok(activeNew.every(t => !baseline.some(old => old.planId === t.planId)));
    assert.deepEqual(errors, []);
    console.log(`PASS ${kind}: fresh create, invalid input, cancel, preview deep task equality including done/skipped, full daily results, reload, scoped replacement, 320/375 screenshots; ${browser.version()}`);
    await page.close();
  }
} finally { await browser.close(); }
