import assert from 'node:assert/strict';
import { expect } from '@playwright/test';
import { launchBrowser, baseURL } from './browser-support.mjs';

const no3Count = 4937, po4Count = 63;
const browser = await launchBrowser();
const context = await browser.newContext({ viewport: { width: 375, height: 812 } });
try {
  const page = await context.newPage(), errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(baseURL);
  await page.waitForFunction(() => localStorage.getItem('reef-demo-state-v10'));
  const originalRecords = await page.evaluate(({ no3Count, po4Count }) => {
    const state = JSON.parse(localStorage.getItem('reef-demo-state-v10'));
    const make = (count, parameterId, baseId) => Array.from({ length: count }, (_, i) => {
      const rangeOnly = parameterId === 'no3' && i >= 1200 && i <= 3700;
      const single = !rangeOnly && i % 4 === 0;
      const value = parameterId === 'no3' ? 12 + i % 10 : .05;
      return {
        id: baseId + i, tankId: state.tankId, parameterId,
        low: single ? value : parameterId === 'no3' ? 10 : .03,
        high: single ? value : parameterId === 'no3' ? 25 : .1,
        interpolation: rangeOnly ? null : value,
        date: new Date(Date.UTC(2000, 0, 1 + i, 4)).toISOString(),
        note: `独立长历史回归 ${parameterId} ${i}`,
      };
    });
    state.records = [...make(no3Count, 'no3', 10000), ...make(po4Count, 'po4', 20000)].reverse();
    localStorage.setItem('reef-demo-state-v10', JSON.stringify(state));
    return JSON.stringify(state.records);
  }, { no3Count, po4Count });
  await page.reload();
  await page.locator('main[aria-busy=false]').waitFor();
  assert.equal(await page.getByTestId('storage-notice').count(), 0);

  const homeCard = name => page.locator('.home-trend-card').filter({ hasText: `${name} 变化` });
  const metrics = scroll => scroll.evaluate(el => ({
    left: el.scrollLeft, width: el.clientWidth, max: el.scrollWidth - el.clientWidth,
    ratio: el.scrollWidth / el.clientWidth,
    ids: [...el.querySelectorAll('[data-record-id]')].map(node => Number(node.dataset.recordId)),
  }));
  const boundedWindow = async (scroll, count, baseId) => {
    await expect.poll(async () => {
      const value = await metrics(scroll);
      const middle = Math.min(count - 1, Math.floor(value.left / value.width * 5) + 2);
      return value.ids.length > 0 && value.ids.length <= 16 && value.ids.includes(baseId + middle);
    }).toBe(true);
    const value = await metrics(scroll);
    assert.ok(Math.abs(value.ratio - count / 5) < .05, `full history scroll range: ${JSON.stringify(value)}`);
    return value;
  };
  const jump = async (scroll, first, count, baseId) => {
    await scroll.evaluate((el, first) => { el.scrollLeft = first * el.clientWidth / 5; }, first);
    await expect.poll(async () => {
      const value = await metrics(scroll);
      return Math.abs(value.left / value.width * 5 - Math.min(first, count - 5));
    }).toBeLessThan(.15);
    return boundedWindow(scroll, count, baseId);
  };
  const move = async (scroll, action, direction, count, baseId) => {
    const before = await metrics(scroll);
    await action();
    await expect.poll(async () => Math.abs((await metrics(scroll)).left - Math.max(0, Math.min(before.max, before.left + direction * before.width)))).toBeLessThan(3);
    return boundedWindow(scroll, count, baseId);
  };
  const no3Home = homeCard('NO3'), homeScroll = no3Home.locator('.history-bar-scroll');
  await homeScroll.scrollIntoViewIfNeeded();
  await expect.poll(async () => { const value = await metrics(homeScroll); return Math.abs(value.left - value.max); }).toBeLessThan(3);
  assert.ok((await boundedWindow(homeScroll, no3Count, 10000)).ids.includes(10000 + no3Count - 1));
  assert.ok((await jump(homeScroll, 0, no3Count, 10000)).ids.includes(10000));
  await move(homeScroll, () => homeScroll.press('ArrowRight'), 1, no3Count, 10000);
  await move(homeScroll, () => no3Home.getByRole('button', { name: 'NO3 最近5次' }).click(), 1, no3Count, 10000);
  await move(homeScroll, () => no3Home.getByRole('button', { name: 'NO3 较早5次' }).click(), -1, no3Count, 10000);
  await jump(homeScroll, 2450, no3Count, 10000);
  assert.equal(await homeScroll.getByTestId('history-value-bar').count(), 0, 'range-only records keep slots without invented values');
  await jump(homeScroll, no3Count, no3Count, 10000);
  await boundedWindow(homeCard('PO4').locator('.history-bar-scroll'), po4Count, 20000);

  await page.getByRole('button', { name: '趋势详情', exact: true }).click();
  const trend = page.getByTestId('range-interpolation-trend');
  const scroll = page.getByTestId('line-history-scroll');
  await scroll.waitFor();
  await expect.poll(async () => { const value = await metrics(scroll); return Math.abs(value.left - value.max); }).toBeLessThan(3);
  await boundedWindow(scroll, no3Count, 10000);
  const boundedSvg = async () => {
    const size = await scroll.evaluate(el => {
      const svg = el.querySelector('svg');
      return { viewport: el.clientWidth, width: svg.getBoundingClientRect().width, viewBox: svg.viewBox.baseVal.width };
    });
    assert.equal(size.viewBox, 350);
    assert.ok(Math.abs(size.width - size.viewport) < 2, `SVG remains viewport sized: ${JSON.stringify(size)}`);
  };
  await boundedSvg();
  assert.ok((await jump(scroll, 0, no3Count, 10000)).ids.includes(10000));
  assert.equal(await scroll.locator('[data-record-id="10000"]').getByTestId('range-mark').count(), 0, 'single values have no range endpoint labels');
  const firstRange = scroll.locator('[data-record-id="10001"]');
  assert.equal(await firstRange.getByTestId('range-high-label').textContent(), '25');
  assert.equal(await firstRange.getByTestId('range-low-label').textContent(), '10');
  await move(scroll, () => scroll.press('ArrowRight'), 1, no3Count, 10000);
  await move(scroll, () => trend.getByRole('button', { name: '趋势最近5次' }).click(), 1, no3Count, 10000);
  await move(scroll, () => scroll.press('ArrowLeft'), -1, no3Count, 10000);
  await move(scroll, () => trend.getByRole('button', { name: '趋势较早5次' }).click(), -1, no3Count, 10000);

  await jump(scroll, 2450, no3Count, 10000);
  assert.equal(await scroll.getByTestId('interpolation-point').count(), 0);
  const gapRanges = await scroll.getByTestId('range-mark').count();
  assert.ok(gapRanges > 0 && gapRanges <= 16);
  assert.equal(await scroll.getByTestId('range-high-label').count(), gapRanges);
  assert.equal(await scroll.getByTestId('range-low-label').count(), gapRanges);
  assert.ok((await scroll.getByTestId('range-high-label').allTextContents()).every(value => value === '25'));
  assert.ok((await scroll.getByTestId('range-low-label').allTextContents()).every(value => value === '10'));
  const segments = await scroll.getByTestId('interpolation-segment').evaluateAll(nodes => nodes.map(node => ({
    x1: Number(node.getAttribute('x1')), x2: Number(node.getAttribute('x2')),
    y1: Number(node.getAttribute('y1')), y2: Number(node.getAttribute('y2')),
  })));
  assert.equal(segments.length, 1, 'a long range-only window retains one line between offscreen valid neighbors');
  assert.ok(segments[0].x1 < 0 && segments[0].x2 > 350);
  assert.ok(Math.abs(segments[0].x2 - segments[0].x1 - (3701 - 1199) * 70) < .01);
  assert.ok(segments.every(segment => Object.values(segment).every(Number.isFinite)));

  for (const width of [960, 320, 375]) {
    await page.setViewportSize({ width, height: 812 });
    await boundedWindow(scroll, no3Count, 10000);
    await boundedSvg();
    await jump(scroll, 2450, no3Count, 10000);
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
  }
  await jump(scroll, no3Count, no3Count, 10000);
  assert.ok((await boundedWindow(scroll, no3Count, 10000)).ids.includes(10000 + no3Count - 1));
  await page.locator('.parameter-tabs button').filter({ hasText: 'PO4' }).click();
  await expect.poll(async () => { const value = await metrics(scroll); return Math.abs(value.left - value.max); }).toBeLessThan(3);
  assert.ok((await boundedWindow(scroll, po4Count, 20000)).ids.every(id => id >= 20000));
  await boundedSvg();
  await jump(scroll, 0, po4Count, 20000);
  const po4Range = scroll.locator('[data-record-id="20001"]');
  assert.equal(await po4Range.getByTestId('range-high-label').textContent(), '0.1');
  assert.equal(await po4Range.getByTestId('range-low-label').textContent(), '0.03');
  await page.locator('.parameter-tabs button').filter({ hasText: 'NO3' }).click();
  await boundedWindow(scroll, no3Count, 10000);
  await expect.poll(async () => { const value = await metrics(scroll); return Math.abs(value.left - value.max); }).toBeLessThan(3);
  assert.match(await page.getByTestId('record-page-count').innerText(), /共 4937 条/);
  assert.equal(await page.evaluate(() => JSON.stringify(JSON.parse(localStorage.getItem('reef-demo-state-v10')).records)), originalRecords, 'windowing never removes or rewrites stored records');
  await page.reload();
  await page.locator('main[aria-busy=false]').waitFor();
  await boundedWindow(homeCard('NO3').locator('.history-bar-scroll'), no3Count, 10000);
  assert.equal(await page.evaluate(() => JSON.stringify(JSON.parse(localStorage.getItem('reef-demo-state-v10')).records)), originalRecords);
  assert.deepEqual(errors, []);
  console.log('PASS: isolated 5000-record history, <=16 mounted records, full first/middle/latest scrolling, keyboard/buttons, viewport-sized SVG, offscreen connections across 2501 range-only records, endpoint labels, parameter/viewport changes and unchanged persisted history after reload; no page errors.');
} finally {
  await context.close();
  await browser.close();
}
