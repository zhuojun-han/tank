import { launchBrowser, baseURL } from './browser-support.mjs';
import assert from 'node:assert/strict';
const browser=await launchBrowser();
try{
const page=await browser.newPage({viewport:{width:375,height:812}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
await page.goto(`${baseURL}/?demoHistory=1`);await page.waitForFunction(()=>JSON.parse(localStorage.getItem('reef-demo-state-v10')||'{}').records?.some(r=>r.note==='历史演示数据 · 非真实检测'));
await page.getByRole('button',{name:'趋势详情',exact:true}).click();
const scroll=page.getByTestId('line-history-scroll');await scroll.waitFor();
const count=await page.evaluate(()=>{const s=JSON.parse(localStorage.getItem('reef-demo-state-v10'));return s.records.filter(r=>r.tankId===s.tankId&&r.parameterId==='no3').length;});
assert.ok(count>6);const rangeCount=await page.evaluate(()=>{const s=JSON.parse(localStorage.getItem('reef-demo-state-v10'));return s.records.filter(r=>r.tankId===s.tankId&&r.parameterId==='no3'&&r.low!==r.high).length;});
assert.equal(await page.getByTestId('range-mark').count(),rangeCount);
const dims=await scroll.evaluate(el=>({left:el.scrollLeft,max:el.scrollWidth-el.clientWidth,ratio:el.scrollWidth/el.clientWidth}));assert.ok(dims.max>0);assert.ok(Math.abs(dims.left-dims.max)<3);assert.ok(Math.abs(dims.ratio-count/5)<.05);
assert.ok(await page.getByTestId('missing-interpolation').count()>0);
// Missing records retain both endpoint labels and are skipped by connecting valid points.
const gaps=await page.getByTestId('missing-interpolation').locator('text').evaluateAll(nodes=>nodes.map(n=>Number(n.getAttribute('x'))));
const segments=await scroll.locator('line').evaluateAll(nodes=>nodes.map(n=>[Number(n.getAttribute('x1')),Number(n.getAttribute('x2'))]));
const pointXs=await page.getByTestId('interpolation-point').evaluateAll(nodes=>nodes.map(n=>Number(n.getAttribute('cx'))));
assert.deepEqual(segments,pointXs.slice(1).map((x,i)=>[pointXs[i],x]));
assert.ok(segments.some(([a,b])=>gaps.some(x=>a<x&&x<b)));
assert.equal(await page.getByTestId('range-high-label').count(),rangeCount);
assert.equal(await page.getByTestId('range-low-label').count(),rangeCount);
const legacy=page.getByTestId('range-mark').filter({hasText:'8月3日 19:42'});
assert.equal(await legacy.getByTestId('range-high-label').textContent(),'25');
assert.equal(await legacy.getByTestId('range-low-label').textContent(),'10');
await page.getByRole('button',{name:'趋势较早5次'}).click();await page.waitForFunction(()=>{const e=document.querySelector('[data-testid=line-history-scroll]');return e.scrollLeft<e.scrollWidth-e.clientWidth-50;});
await page.waitForTimeout(500);
assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
await page.screenshot({path:'artifacts/po4-integration/line-history.png',fullPage:true});
await page.locator('.parameter-tabs button').filter({hasText:'PO4'}).click();await scroll.waitFor();assert.ok(await page.getByTestId('interpolation-point').count()>6);
assert.equal(await page.getByTestId('range-high-label').count(),0);
assert.deepEqual(errors,[]);console.log('PASS: all NO3/PO4 history, five-point viewport, starts latest, older navigation, range endpoint labels and valid-point connections across missing values, mobile no overflow/errors.');
}finally{await browser.close();}
