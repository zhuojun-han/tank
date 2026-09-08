import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import {fileURLToPath} from 'node:url';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
const require=createRequire(import.meta.url);const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const out=new URL('../artifacts/po4/',import.meta.url);await mkdir(out,{recursive:true});
const browser=await chromium.launch({channel:'msedge',headless:true});
try{
 const page=await browser.newPage({viewport:{width:1100,height:950}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto('http://localhost:3000/po4-color-match');const summaries=[];
 for(const id of ['1','2','3','4','5']){
  await page.getByLabel('测试素材',{exact:true}).selectOption(id);
  assert.equal(await page.getByTestId('po4-result').count(),0);
  await page.getByRole('button',{name:'按 PO4 模板自动取色'}).click();
  assert.equal(await page.locator('.cm-swatches button').count(),8);
  assert.equal(await page.getByRole('button',{name:'比较 PO4 颜色'}).isDisabled(),true);
  await page.getByRole('checkbox').check();await page.getByRole('button',{name:'比较 PO4 颜色'}).click();await page.getByTestId('po4-result').waitFor();
  const downloading=page.waitForEvent('download');await page.getByRole('button',{name:'下载本次比较记录'}).click();const download=await downloading;const file=new URL(`${id}-comparison.json`,out);await download.saveAs(fileURLToPath(file));
  const result=JSON.parse(await readFile(file,'utf8'));assert.deepEqual(result.result.ranked.map(s=>s.level).sort((a,b)=>a-b),[0,.03,.1,.25,.5,1,3]);
  summaries.push({id,label:result.manualLabel,range:result.result.range,interpolation:result.result.interpolatedValue,nearest:result.result.ranked[0].level,warnings:result.result.warnings});
  await page.screenshot({path:fileURLToPath(new URL(`${id}-desktop.png`,out)),fullPage:true});
 }
 await page.setViewportSize({width:375,height:812});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);await page.screenshot({path:fileURLToPath(new URL('mobile.png',out)),fullPage:true});
 await page.getByLabel('色卡方向',{exact:true}).selectOption('4');assert.equal(await page.getByTestId('po4-result').count(),0);assert.equal(await page.locator('.cm-swatches button').count(),0);
 await page.locator('input[type=file]').setInputFiles(fileURLToPath(new URL('../public/po4/1.jpg',import.meta.url)));assert.equal(await page.locator('.cm-box').count(),0);assert.equal(await page.getByRole('button',{name:'按 PO4 模板自动取色'}).isDisabled(),true);
 assert.deepEqual(errors,[]);await writeFile(new URL('results.json',out),JSON.stringify(summaries,null,2));console.log('PASS: 5 original images, eight swatches, label-independent result/export, gates, orientation reset, upload reset, mobile layout, no page errors.');console.log(JSON.stringify(summaries,null,2));
}finally{await browser.close();}
