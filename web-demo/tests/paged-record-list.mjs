import { launchBrowser, baseURL } from './browser-support.mjs';
import assert from 'node:assert/strict';
const browser=await launchBrowser();
try{
const page=await browser.newPage({viewport:{width:375,height:812}});const errors=[];page.on('pageerror',e=>errors.push(e.message));await page.goto(`${baseURL}/`);await page.waitForFunction(()=>localStorage.getItem('reef-demo-state-v10'));
await page.evaluate(()=>{const s=JSON.parse(localStorage.getItem('reef-demo-state-v10'));s.records=Array.from({length:25},(_,i)=>({id:1000+i,tankId:s.tankId,parameterId:'no3',low:5,high:10,interpolation:7,date:new Date(2026,8,1,12,i).toISOString(),note:'拍照辅助估值 · 人工确认（插值未经校准）'}));localStorage.setItem('reef-demo-state-v10',JSON.stringify(s));});await page.reload();await page.getByRole('button',{name:'趋势详情',exact:true}).click();
await page.waitForTimeout(500);await page.waitForFunction(()=>document.querySelectorAll('.record-row').length===10);
assert.match(await page.getByTestId('record-page-count').innerText(),/已加载 10 \/ 共 25/);
assert.equal(await page.locator('.record-row small').first().textContent(),'2026-09-01');assert.ok(!(await page.locator('.record-list').innerText()).includes('校准'));
await page.getByTestId('record-scroll').evaluate(el=>el.scrollTop=el.scrollHeight);await page.waitForFunction(()=>document.querySelectorAll('.record-row').length===20);
await page.getByTestId('record-scroll').evaluate(el=>el.scrollTop=el.scrollHeight);await page.waitForFunction(()=>document.querySelectorAll('.record-row').length===25);
await page.getByRole('button',{name:'收起检测记录'}).click();assert.equal(await page.locator('.record-row').count(),0);
await page.getByRole('button',{name:'展开检测记录'}).click();assert.equal(await page.locator('.record-row').count(),10);
await page.locator('.record-row').first().click();await page.getByRole('heading',{name:'编辑检测结果'}).waitFor();assert.match(await page.locator('textarea[name=note]').inputValue(),/校准/);
assert.deepEqual(errors,[]);console.log('PASS: 10/20/25 progressive scroll loading, collapse/expand reset, date-only rows, original notes retained and editing works, no page errors.');
}finally{await browser.close();}
