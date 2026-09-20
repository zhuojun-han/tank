import { launchBrowser, baseURL } from './browser-support.mjs';
import assert from 'node:assert/strict';
const browser=await launchBrowser();
try{
 // Freeze Date only: pausing before the first elapsed second must remain a
 // paused session even when displayed remaining time equals its full duration.
 const pausedPage=await browser.newPage({viewport:{width:375,height:812}});
 await pausedPage.clock.setFixedTime(Date.now());
 await pausedPage.goto(`${baseURL}/`);await pausedPage.locator('main[aria-busy=false]').waitFor();
 await pausedPage.locator('.bottom-nav button').filter({hasText:'检测'}).click();
 await pausedPage.locator('.parameter-tabs button').filter({hasText:'PO4'}).click();
 await pausedPage.locator('.custom-time-row input').nth(0).fill('0');await pausedPage.locator('.custom-time-row input').nth(1).fill('20');
 await pausedPage.getByRole('button',{name:'开始计时',exact:true}).click();
 await pausedPage.getByRole('button',{name:'暂停计时',exact:true}).click();
 assert.equal(await pausedPage.locator('.timer-ring strong').textContent(),'00:20');
 assert.equal(await pausedPage.locator('.timer-ring small').textContent(),'计时已暂停');
 assert.equal(await pausedPage.locator('.timer-customizer').count(),0);
 await pausedPage.getByRole('button',{name:'继续计时',exact:true}).click();
 await pausedPage.getByRole('button',{name:'暂停计时',exact:true}).click();
 await pausedPage.getByRole('button',{name:'重新开始默认计时',exact:true}).click();
 assert.equal(await pausedPage.locator('.timer-ring strong').textContent(),'00:20');
 await pausedPage.getByRole('button',{name:'开始计时',exact:true}).waitFor();
 assert.equal(await pausedPage.locator('.custom-time-row input').count(),2);
 await pausedPage.close();
 console.log('PASS: immediate pause at full remaining time stays paused/locked; resume and explicit restart restore the correct controls.');
 if(process.env.TIMER_PAUSE_ONLY!=='1'){
 const page=await browser.newPage({viewport:{width:375,height:812}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(`${baseURL}/`);await page.waitForFunction(()=>localStorage.getItem('reef-demo-state-v10'));
 const before=await page.evaluate(()=>JSON.parse(localStorage.getItem('reef-demo-state-v10')).records);
 await page.locator('.bottom-nav button').filter({hasText:'检测'}).click();
 for(const id of ['NO3','PO4']){
  await page.locator('.parameter-tabs button').filter({hasText:id}).click();
  await page.getByRole('button',{name:'开始计时',exact:true}).click();
  await page.getByRole('button',{name:'跳过计时，直接拍照',exact:true}).click();
  await page.getByRole('heading',{name:'拍照比色'}).waitFor();
  assert.match(await page.locator('.cm-pill').innerText(),id==='NO3'?/NO₃/:/PO₄/);
  assert.equal(await page.getByRole('button',{name:'打开拍照比色',exact:true}).count(),0);
  await page.getByRole('button',{name:'按模板自动取色',exact:true}).click();await page.getByRole('button',{name:'比较颜色并给出范围'}).click();await page.getByRole('button',{name:'修改结果并选择是否记录'}).click();
  await page.getByRole('heading',{name:'修改并确认检测结果'}).waitFor();assert.match(await page.locator('.result-card .eyebrow').innerText(),new RegExp(id));
  await page.getByRole('button',{name:'本次不记录',exact:true}).click();
  // Actual 10-second completion must open the same panel for both indicators.
  await page.locator('.custom-time-row input').nth(0).fill('0');await page.locator('.custom-time-row input').nth(1).fill('10');
  await page.getByRole('button',{name:'开始计时',exact:true}).click();
  await page.getByRole('heading',{name:'拍照比色'}).waitFor({timeout:16000});
  assert.match(await page.locator('.cm-pill').innerText(),id==='NO3'?/NO₃/:/PO₄/);
  await page.getByRole('button',{name:'不记录，返回检测',exact:true}).click();
  await page.getByRole('button',{name:'开始计时',exact:true}).waitFor();
 }
 assert.deepEqual(await page.evaluate(()=>JSON.parse(localStorage.getItem('reef-demo-state-v10')).records),before);
 assert.deepEqual(errors,[]);console.log('PASS: NO3/PO4 skip while running opens correct shared panel directly; compare/review/cancel; actual timer completion opens correct panel; return resets timer; no writes/errors.');
 }
}finally{await browser.close();}
