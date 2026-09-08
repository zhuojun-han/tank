import { launchBrowser, baseURL } from './browser-support.mjs';
import assert from 'node:assert/strict';
import {mkdir} from 'node:fs/promises';
const browser=await launchBrowser();
try {
 const page=await browser.newPage({viewport:{width:375,height:812}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const imageState=()=>page.locator('.cm-photo img').evaluate(async img=>{await img.decode();const canvas=document.createElement('canvas');canvas.width=img.naturalWidth;canvas.height=img.naturalHeight;const ctx=canvas.getContext('2d');ctx.drawImage(img,0,0);const hash=await crypto.subtle.digest('SHA-256',ctx.getImageData(0,0,canvas.width,canvas.height).data);canvas.width=0;canvas.height=0;return{width:img.naturalWidth,height:img.naturalHeight,pixels:Array.from(new Uint8Array(hash)).join(',')};});
 await page.goto(`${baseURL}/`);await page.waitForFunction(()=>localStorage.getItem('reef-demo-state-v10'));
 await page.locator('.history-bar-scroll').first().waitFor();
 const dates=await page.locator('.history-bar-slot time').allTextContents();assert.ok(dates.includes('08-03'));assert.ok(!dates.some(d=>d.includes(':')));
 for(const parameter of ['no3','po4']) {
  await page.goto(`${baseURL}/${parameter==='no3'?'color-match':'po4-color-match'}`);
  await page.getByRole('button',{name:'按模板自动取色',exact:true}).click();
  const original=await imageState();
  await page.getByRole('button',{name:'比较颜色并给出范围'}).click();await page.getByTestId('comparison-result').waitFor();
  await page.getByRole('button',{name:'↷ 顺时针90°',exact:true}).click();
  await page.waitForFunction(()=>document.querySelector('.cm-photo img').dataset.rotation==='90' && ![...document.querySelectorAll('button')].find(b=>b.textContent==='↶ 逆时针90°').disabled);
  const rotated=await imageState();assert.equal(rotated.width,original.height);assert.equal(rotated.height,original.width);assert.notEqual(rotated.pixels,original.pixels);
  assert.equal(await page.locator('.cm-box').count(),0);assert.equal(await page.getByTestId('comparison-result').count(),0);assert.ok(await page.getByRole('button',{name:'按模板自动取色',exact:true}).isDisabled());
  await page.getByRole('button',{name:'↶ 逆时针90°',exact:true}).click();
  await page.waitForFunction(()=>document.querySelector('.cm-photo img').dataset.rotation==='0' && ![...document.querySelectorAll('button')].find(b=>b.textContent==='↶ 逆时针90°').disabled);
  assert.deepEqual(await imageState(),original);
  await page.getByRole('button',{name:'使用你的示例照片'}).click();await page.getByRole('button',{name:'按模板自动取色',exact:true}).click();await page.getByRole('button',{name:'比较颜色并给出范围'}).click();
  assert.match(await page.getByTestId('judgment-interpolation').innerText(), /约 \d+ mg\/L/);
  assert.doesNotMatch(await page.getByTestId('judgment-interpolation').innerText(), /\d+\.\d+/);
  assert.equal(await page.getByRole('button',{name:'下载本次取色与比较记录'}).count(),0);
  assert.equal(await page.locator('.cm-diagnostics').getAttribute('open'),null);
  assert.equal(await page.locator('.cm-swatches button').count(),8);
  assert.ok((await page.getByTestId('judgment-range').innerText()).includes(parameter==='po4'?'1–3':'10–25'));
  await mkdir('artifacts/unified-photo',{recursive:true});await page.screenshot({path:`artifacts/unified-photo/${parameter}.png`,fullPage:true});
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
  await page.getByRole('button',{name:'修改结果并选择是否记录'}).click();await page.getByRole('heading',{name:'修改并确认检测结果'}).waitFor();await page.getByRole('button',{name:'确认并保存结果'}).click();
  await page.waitForFunction(p=>JSON.parse(localStorage.getItem('reef-demo-state-v10')).records[0].photoEstimate?.parameterId===p,parameter);
 }
 assert.deepEqual(errors,[]);console.log('PASS: legacy chart dates, both shared panels, actual pixel rotation and inverse restoration, stale region/result clearing, upright results and simplified UI, correct NO3/PO4 save, 375px layout and no page errors.');
}finally{await browser.close();}
