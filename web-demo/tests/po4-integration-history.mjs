import { launchBrowser, baseURL } from './browser-support.mjs';
import assert from 'node:assert/strict';
import {mkdir} from 'node:fs/promises';
const browser=await launchBrowser();
try{
const page=await browser.newPage({viewport:{width:375,height:812}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
await page.goto(`${baseURL}/?demoHistory=1`);
await page.waitForFunction(()=>JSON.parse(localStorage.getItem('reef-demo-state-v10')||'{}').records?.filter(r=>r.note==='历史演示数据 · 非真实检测').length===30);
const before=await page.evaluate(()=>JSON.parse(localStorage.getItem('reef-demo-state-v10')));
await page.reload();await page.waitForFunction(()=>document.querySelector('.history-bar-scroll')?.scrollWidth>0);
assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('reef-demo-state-v10')).records.filter(r=>r.note==='历史演示数据 · 非真实检测').length),30);
const card=page.locator('.home-trend-card').filter({hasText:'NO3 变化'});const scroll=card.locator('.history-bar-scroll');
await scroll.scrollIntoViewIfNeeded();
const metrics=await scroll.evaluate(el=>({width:el.clientWidth,slot:el.children[0].getBoundingClientRect().width,left:el.scrollLeft,max:el.scrollWidth-el.clientWidth}));
assert.ok(Math.abs(metrics.width/metrics.slot-5)<.05);assert.ok(Math.abs(metrics.left-metrics.max)<3);
await card.getByRole('button',{name:'NO3 较早5次'}).click();await page.waitForFunction(()=>{const el=[...document.querySelectorAll('.home-trend-card')].find(e=>e.textContent.includes('NO3 变化')).querySelector('.history-bar-scroll');return el.scrollLeft<el.scrollWidth-el.clientWidth-100;});
assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
await page.waitForTimeout(500); // Wait for smooth horizontal scroll before screenshot.
await mkdir('artifacts/po4-integration',{recursive:true});await page.screenshot({path:'artifacts/po4-integration/history-mobile.png',fullPage:true});
await page.goto(`${baseURL}/po4-color-match`);await page.getByRole('button',{name:'按模板自动取色'}).click();await page.getByRole('button',{name:'比较颜色并给出范围'}).click();await page.getByRole('button',{name:'修改结果并选择是否记录'}).click();
await page.getByRole('heading',{name:'修改并确认检测结果'}).waitFor();await page.getByRole('button',{name:'本次不记录',exact:true}).click();
assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('reef-demo-state-v10')).records.length),before.records.length);
await page.getByRole('button',{name:/PO4 照片辅助比色/}).click();await page.getByRole('button',{name:'按模板自动取色'}).click();await page.getByRole('button',{name:'比较颜色并给出范围'}).click();await page.getByRole('button',{name:'修改结果并选择是否记录'}).click();
await page.getByLabel('结果下限',{exact:true}).fill('.25');await page.getByLabel('结果上限',{exact:true}).fill('.5');await page.getByLabel('插值 / 单值',{exact:true}).fill('.38');await page.getByRole('button',{name:'确认并保存结果'}).click();
await page.waitForFunction(()=>JSON.parse(localStorage.getItem('reef-demo-state-v10')).records[0].parameterId==='po4' && JSON.parse(localStorage.getItem('reef-demo-state-v10')).records[0].interpolation===.38);
const saved=await page.evaluate(()=>JSON.parse(localStorage.getItem('reef-demo-state-v10')));assert.equal(saved.records[0].photoEstimate.parameterId,'po4');assert.deepEqual(saved.tasks,before.tasks);
await page.reload();await page.waitForFunction(()=>document.querySelector('.history-bar-scroll'));
await page.locator('.home-trend-card').filter({hasText:'PO4 变化'}).getByText('0.38',{exact:true}).waitFor();
await page.getByRole('button',{name:'清除当前缸演示数据'}).click();
await page.waitForFunction(()=>!JSON.parse(localStorage.getItem('reef-demo-state-v10')).records.some(r=>r.note==='历史演示数据 · 非真实检测'));
assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('reef-demo-state-v10')).records[0].interpolation),.38);
assert.deepEqual(errors,[]);console.log('PASS: 30 historical demo records, idempotent reload, five slots, older navigation, mobile no overflow, PO4 standalone cancel/embedded edited save, correct parameter, provenance and reload; no page errors.');
}finally{await browser.close();}
