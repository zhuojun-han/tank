import { launchBrowser, baseURL } from './browser-support.mjs';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
const browser=await launchBrowser();
try{
 const page=await browser.newPage({viewport:{width:375,height:812}});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const state=()=>page.evaluate(()=>JSON.parse(localStorage.getItem('reef-demo-state-v10')));
 await page.goto(`${baseURL}/`);
 await page.waitForFunction(()=>localStorage.getItem('reef-demo-state-v10'));
 const before=await state();
 // Standalone photo route also returns a draft, never silently persists it.
 await page.goto(`${baseURL}/color-match`);
 await page.getByRole('button',{name:'按模板自动取色'}).click();

 await page.getByRole('button',{name:'比较颜色并给出范围'}).click();
 await page.getByRole('button',{name:'修改结果并选择是否记录'}).click();
 await page.getByRole('heading',{name:'修改并确认检测结果'}).waitFor();
 assert.equal((await state()).records.length,before.records.length);
 await page.getByRole('button',{name:'本次不记录',exact:true}).click();
 assert.deepEqual((await state()).records,before.records);
 // Embedded path, edit and save.
 await page.getByRole('button',{name:'NO3 照片辅助比色',exact:false}).click();
 await page.getByRole('button',{name:'按模板自动取色'}).click();
 await page.getByRole('button',{name:'比较颜色并给出范围'}).click();
 await page.getByRole('button',{name:'修改结果并选择是否记录'}).click();
 await page.getByLabel('结果下限',{exact:true}).fill('12');await page.getByLabel('结果上限',{exact:true}).fill('22');
 await page.getByLabel('插值 / 单值',{exact:true}).fill('30');await page.getByRole('button',{name:'确认并保存结果'}).click();
 assert.match(await page.getByRole('alert').innerText(),/插值/);assert.equal((await state()).records.length,before.records.length);
 await page.getByLabel('插值 / 单值',{exact:true}).fill('18.5');await page.getByRole('button',{name:'确认并保存结果'}).click();
 await page.waitForFunction(n=>JSON.parse(localStorage.getItem('reef-demo-state-v10')).records.length===n,before.records.length+1);
 let saved=(await state()).records[0];assert.equal(saved.interpolation,18.5);assert.equal(saved.low,12);assert.equal(saved.high,22);assert.equal(saved.photoEstimate.low,10);
 assert.equal(await page.locator('[data-testid=interpolation-trend] [data-testid=range-mark]').count(),0);
 await page.getByRole('button',{name:'趋势详情',exact:true}).click();
 assert.ok(await page.locator('[data-testid=range-interpolation-trend] [data-testid=range-mark]').count()>0);
 await page.locator('.record-row').first().click();await page.locator('input[name=interpolation]').fill('19');await page.getByRole('button',{name:'保存修改',exact:true}).click();
 await page.reload();await page.waitForFunction(()=>JSON.parse(localStorage.getItem('reef-demo-state-v10')).records[0].interpolation===19);
 assert.equal((await state()).records[0].photoEstimate.low,10);
 // Select PO4 through its home metric and use manual range + interpolation.
 await page.locator('.metric-card').filter({hasText:'PO4'}).click();
 await page.getByRole('button',{name:'＋ 添加',exact:true}).click();
 await page.getByRole('button',{name:/手动录入 PO4/}).click();
 await page.getByLabel('结果下限',{exact:true}).fill('.05');await page.getByLabel('结果上限',{exact:true}).fill('.1');await page.getByLabel('插值 / 单值',{exact:true}).fill('.072');
 await page.getByRole('button',{name:'确认并保存结果'}).click();
 await page.waitForFunction(()=>JSON.parse(localStorage.getItem('reef-demo-state-v10')).records[0].parameterId==='po4');
 saved=(await state()).records[0];assert.equal(saved.interpolation,.072);assert.equal(saved.photoEstimate,undefined);
 assert.deepEqual((await state()).tasks,before.tasks);
 await page.locator('.metric-card').filter({hasText:'PO4'}).click();
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
 await page.waitForTimeout(700); // Wait for the existing tab transition before visual capture.
 await page.screenshot({path:fileURLToPath(new URL('../artifacts/color-match/po4-record-trend.png',import.meta.url)),fullPage:true});
 // A trusted range remains saveable when interpolation alone is rejected.
 await page.evaluate(()=>{const state=JSON.parse(localStorage.getItem('reef-demo-state-v10'));sessionStorage.setItem('reef-photo-review',JSON.stringify({tankId:state.tankId,review:{parameterId:'no3',low:10,high:25,interpolation:null,source:'range-only-regression',algorithmVersion:'eal-no3-mvp-4'}}));});
 await page.reload();await page.getByRole('heading',{name:'修改并确认检测结果'}).waitFor();
 assert.equal(await page.getByLabel('插值 / 单值',{exact:true}).inputValue(),'');
 await page.getByRole('button',{name:'确认并保存结果'}).click();
 await page.waitForFunction(()=>JSON.parse(localStorage.getItem('reef-demo-state-v10')).records[0].photoEstimate?.source==='range-only-regression');
 assert.equal((await state()).records[0].interpolation,null);
 assert.deepEqual((await state()).tasks,before.tasks);
 assert.deepEqual(errors,[]);
 console.log('PASS: standalone/embedded review; cancel no write; invalid range blocked; edited photo provenance; NO3/PO4 interpolation; range-only legacy; home hides ranges; trend shows both; edit/reload; unchanged tasks; 375px no overflow/errors.');
}finally{await browser.close();}
