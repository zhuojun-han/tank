import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { launchBrowser, baseURL } from './browser-support.mjs';
const browser = await launchBrowser();
try {
  const page = await browser.newPage({viewport:{width:375,height:812}}), errors=[];
  page.on('pageerror', e => errors.push(e.message));
  await page.goto(`${baseURL}/color-match`);
  const extract=page.getByRole('button',{name:'按模板自动取色',exact:true});
  const compare=page.getByRole('button',{name:'比较颜色并给出范围',exact:true});
  await extract.click(); assert.equal(await page.locator('.cm-swatches button').count(),8);
  assert.equal(await page.getByRole('checkbox').count(),0);
  await compare.click(); await page.getByTestId('comparison-result').waitFor();
  assert.match(await page.getByTestId('judgment-range').innerText(),/10–25/);
  assert.match(await page.getByTestId('comparison-result').innerText(),/仅供参考/);
  assert.equal(await page.getByRole('button',{name:/下载.*记录/}).count(),0);
  await page.getByLabel('拖动照片时调整',{exact:false}).selectOption('liquid');
  const photo=page.locator('.cm-photo');await photo.scrollIntoViewIfNeeded();const b=await photo.boundingBox();
  await page.mouse.move(b.x+b.width*.1,b.y+b.height*.1);await page.mouse.down();await page.mouse.move(b.x+b.width*.15,b.y+b.height*.15);await page.mouse.up();
  await page.getByTestId('comparison-result').waitFor({state:'detached'});
  await page.locator('input[type=file]').setInputFiles(fileURLToPath(new URL('../public/no3-card.jpg',import.meta.url)));
  assert.equal(await extract.isDisabled(),true);assert.equal(await page.locator('.cm-box').count(),0);
  await page.getByRole('button',{name:'使用你的示例照片'}).click();await extract.click();await compare.click();
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
  assert.deepEqual(errors,[]);console.log('PASS: current simplified photo UI, example comparison, ROI invalidation, upload reset and mobile layout.');
} finally {await browser.close();}
