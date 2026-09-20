import { launchBrowser, baseURL } from './browser-support.mjs';
// Run via npm run test:e2e, or set BASE_URL for an existing preview.
import assert from 'node:assert/strict';
import { mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
const browser = await launchBrowser();
const errors = [];
const page = await browser.newPage({ viewport: { width: 375, height: 812 } });
page.on('pageerror', error => errors.push(error.message));
const output = new URL(`../artifacts/maintenance-browser/current/`, import.meta.url);
const captureScreenshots = process.env.CAPTURE_SCREENSHOTS === '1';
if (captureScreenshots) await mkdir(output, { recursive: true });
try {
  await page.goto(process.env.BASE_URL || `${baseURL}`, { waitUntil: 'networkidle' });
  await page.getByRole('button', { name: '打开设置' }).click();
  await page.getByRole('button', { name: /稳定滴定配方/ }).click();
  const dialog = page.getByRole('dialog');
  const textIncludes = async text => assert.ok((await dialog.innerText()).includes(text), text);
  const field = name => dialog.getByLabel(name, { exact: false });
  await textIncludes('取母液 2.381 ml');
  assert.equal(await field('泵流速').inputValue(), '1.4');
  assert.equal(await field('每天运行时间（分钟）').inputValue(), '1');
  assert.equal(await dialog.locator('details').getAttribute('open'), null);
  assert.equal(await dialog.getByText('每瓶使用天数', { exact: false }).count(), 0);
  await field('每天运行时间（分钟）').fill('2');
  await textIncludes('取母液 1.19 ml');
  await textIncludes('每日泵出 168 ml');
  await field('泵流速').fill('');
  await textIncludes('请填写有效的非负数值');
  await field('选择指标').selectOption('kh');
  await textIncludes('取母液 357.143 ml');
  assert.equal(await field('泵流速').inputValue(), '1.4');
  assert.deepEqual(await field('KH 母液浓度').locator('option').evaluateAll(nodes => nodes.map(n => n.value)), ['4', '6', '8', '10']);
  await field('KH 母液浓度').selectOption('4');
  await textIncludes('KH 母液超过该温度');
  await dialog.locator('summary').click();
  await field('最低保存温度（°C）').fill('30');
  await textIncludes('取母液 238.095 ml');
  await textIncludes('每日母液 40 ml');
  await textIncludes('每 500 ml 称取 37.503 g');
  for (const value of ['-1', '41', '']) {
    await field('最低保存温度（°C）').fill(value);
    assert.equal(await dialog.getByRole('alert').count(), 1);
  }
  await field('选择指标').selectOption('po4');
  assert.equal(await field('泵流速').inputValue(), '');
  assert.equal(await field('每天运行时间（分钟）').inputValue(), '2');
  await field('泵流速').fill('1.4');
  await textIncludes('取母液 1.19 ml');
  assert.equal(await dialog.getByRole('alert').count(), 0);
  for (const name of ['净水量（L）', '泵流速', '每天运行时间（分钟）']) {
    const old = await field(name).inputValue();
    for (const value of ['0', '-1', '']) {
      await field(name).fill(value);
      assert.equal(await dialog.getByRole('alert').count(), 1, `${name}: ${value}`);
    }
    await field(name).fill(old);
  }
  await field('每日 PO₄ 上升（mg/L）').fill('0');
  await textIncludes('无需添加此药剂');
  await field('每日 PO₄ 上升（mg/L）').fill('10');
  await textIncludes('所需母液超过容量');
  await field('每日 PO₄ 上升（mg/L）').fill('0.02');
  await field('单位').selectOption('ml/min');
  await textIncludes('每日泵出 2.8 ml');
  await textIncludes('取母液 71.429 ml');
  await field('单位').selectOption('ml/s');
  await field('每天运行时间（分钟）').fill('1');
  for (const width of [320, 375, 768, 1280]) {
    await page.setViewportSize({ width, height: 812 });
    for (const chemical of ['po4', 'kh']) {
      await field('选择指标').selectOption(chemical);
      if (chemical === 'kh') await field('最低保存温度（°C）').fill('30');
      const bounds = await dialog.evaluate(node => ({ left: node.getBoundingClientRect().left, right: node.getBoundingClientRect().right, scroll: node.scrollWidth, client: node.clientWidth }));
      assert.ok(bounds.left >= 0 && bounds.right <= width && bounds.scroll <= bounds.client + 1, JSON.stringify({ width, chemical, bounds }));
      if (captureScreenshots) await page.screenshot({ path: fileURLToPath(new URL(`${chemical}-${width}.png`, output)), fullPage: true });
      if (captureScreenshots && chemical === 'kh') {
        await dialog.evaluate(node => { node.scrollTop = node.scrollHeight; });
        await page.screenshot({ path: fileURLToPath(new URL(`${chemical}-${width}-instructions.png`, output)), fullPage: true });
        await dialog.evaluate(node => { node.scrollTop = 0; });
      }
    }
  }
  await page.getByRole('button', { name: '关闭滴定计算器' }).click();
  for (const name of ['检测', '趋势', '任务', '首页']) {
    await page.locator('.bottom-nav button').filter({ has: page.getByText(name, { exact: true }) }).click();
    assert.equal(await page.locator('main').count(), 1);
  }
  for (const name of ['PO4 氯化镧理论计划', '碳酸氢钠补 KH 理论计划', '海盐配制计算器']) {
    await page.getByRole('button', { name: '打开设置' }).click();
    await page.getByRole('button', { name: new RegExp(name) }).click();
    assert.equal(await page.locator('.sheet').count(), 1);
    await page.locator('.sheet .section-head .icon-button').click();
  }
  assert.deepEqual(errors, []);
  console.log(`PASS ${process.env.BASE_URL || `${baseURL}`}: browser interaction, channel isolation, input boundaries, recipes, temperature, four viewport checks, navigation, no page errors; screenshots=${captureScreenshots}`);
} finally {
  await browser.close();
}
