import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFile, writeFile } from 'node:fs/promises';
import { compareColors } from '../app/color-match/color-analysis.ts';
const saved = JSON.parse(await readFile(new URL('../artifacts/no3-audit/results.json', import.meta.url), 'utf8'));
const results = saved.map(row => ({ name: row.name, result: compareColors(row.liquidSample, row.swatches) }));
for (const i of [0,1,5]) {
  assert.equal(results[i].result.nearestLevel, 25);
  assert.notEqual(results[i].result.range, null);
  assert.equal(results[i].result.interpolatedValue, null);
}
await writeFile(new URL('../artifacts/no3-audit/independent-judgments.json',import.meta.url), JSON.stringify(results,null,2));
const require = createRequire(import.meta.url);
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const browser = await chromium.launch({channel:'msedge',headless:true});
try {
 const page = await browser.newPage({viewport:{width:375,height:812}});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto('http://localhost:3000/po4-color-match');
 await page.getByRole('button',{name:'按 PO4 模板自动取色'}).click();
 await page.getByLabel('测试素材',{exact:true}).selectOption('5');
 await page.waitForFunction(()=>document.querySelector('select[aria-label="测试素材"]').value==='5');
 await page.getByRole('button',{name:'按 PO4 模板自动取色'}).click();
 await page.getByRole('checkbox').check();await page.getByRole('button',{name:'比较 PO4 颜色'}).click();
 assert.match(await page.getByTestId('judgment-nearest').innerText(),/可供参考/);
 assert.match(await page.getByTestId('judgment-range').innerText(),/可供参考/);
 assert.match(await page.getByTestId('judgment-interpolation').innerText(),/拒绝给出/);
 await page.goto('http://localhost:3000/');
 await page.waitForFunction(()=>localStorage.getItem('reef-demo-state-v10'));
 await page.evaluate(()=>{const state=JSON.parse(localStorage.getItem('reef-demo-state-v10'));sessionStorage.setItem('reef-photo-review',JSON.stringify({tankId:state.tankId,review:{low:10,high:25,interpolation:null,source:'partial-test',algorithmVersion:'eal-no3-mvp-3'}}));});
 await page.reload();await page.getByRole('heading',{name:'修改并确认检测结果'}).waitFor();
 assert.equal(await page.getByLabel('插值 / 单值',{exact:true}).inputValue(),'');
 await page.getByRole('button',{name:'确认并保存结果'}).click();
 await page.waitForFunction(()=>JSON.parse(localStorage.getItem('reef-demo-state-v10')).records.some(r=>r.photoEstimate?.source==='partial-test'));
 const record=await page.evaluate(()=>JSON.parse(localStorage.getItem('reef-demo-state-v10')).records.find(r=>r.photoEstimate?.source==='partial-test'));
 assert.equal(record.interpolation,null);assert.equal(record.photoEstimate.interpolation,null);
 assert.deepEqual(errors,[]);
 console.log('PASS: NO3 cached samples; PO4 partial rejection; null interpolation review and range-only save without page errors.');
} finally {await browser.close();}
