import assert from 'node:assert/strict';
import { launchBrowser, baseURL } from './browser-support.mjs';

const browser = await launchBrowser();
try {
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.clock.install({ time: new Date('2026-09-08T04:00:00Z') });
  await page.addInitScript(() => {
    window.storageWrites = 0;
    const save = Storage.prototype.setItem;
    Storage.prototype.setItem = function (key, value) {
      if (key === 'reef-demo-state-v10') window.storageWrites++;
      return save.call(this, key, value);
    };
  });
  await page.goto(baseURL);
  await page.waitForFunction(() => localStorage.getItem('reef-demo-state-v10'));
  await page.evaluate(() => {
    const state = JSON.parse(localStorage.getItem('reef-demo-state-v10'));
    state.maintenanceCycles = [];
    state.tasks = [{ id: 9001, tankId: state.tankId, title: '长期稍后提醒', cycle: '单次', due: '稍后', oneOff: true, state: 'snoozed', snoozedUntil: '2026-10-18T04:00:00Z' },
      { id: 9002, tankId: state.tankId, title: '旧档无效提醒日期', cycle: '单次', due: '稍后', oneOff: true, state: 'snoozed', snoozedUntil: 'invalid-old-date' }];
    localStorage.setItem('reef-demo-state-v10', JSON.stringify(state));
  });
  await page.reload();
  await page.locator('main[aria-busy=false]').waitFor();
  await page.clock.fastForward(1000);
  const writes = await page.evaluate(() => window.storageWrites);
  await page.clock.fastForward(10_000);
  assert.equal(await page.evaluate(() => window.storageWrites), writes, 'An unchanged future/invalid deadline must not spin and rewrite storage.');
  const state = () => page.evaluate(() => JSON.parse(localStorage.getItem('reef-demo-state-v10')));
  assert.equal((await state()).tasks[0].state, 'snoozed');
  await page.clock.fastForward(20 * 86_400_000);
  await page.clock.fastForward(5 * 86_400_000);
  assert.equal((await state()).tasks[0].state, 'snoozed', 'The native timeout limit is a wakeup checkpoint, not the task deadline.');
  await page.clock.fastForward(15 * 86_400_000);
  await page.waitForFunction(() => JSON.parse(localStorage.getItem('reef-demo-state-v10')).tasks[0].state === 'due');
  const after = await state();
  assert.equal(after.tasks[1].state, 'snoozed');
  const settledWrites = await page.evaluate(() => window.storageWrites);
  await page.clock.fastForward(1000);
  assert.equal(await page.evaluate(() => window.storageWrites), settledWrites);
  assert.deepEqual(errors, []);
  console.log('PASS: 40-day legacy reminder waits in bounded steps, wakes once when due, and invalid dates never trigger a storage-write loop.');
} finally { await browser.close(); }
