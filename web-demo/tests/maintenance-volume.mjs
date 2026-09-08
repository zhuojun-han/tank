import { launchBrowser, baseURL } from './browser-support.mjs';
import assert from 'node:assert/strict';
const browser=await launchBrowser();
try{
const page=await browser.newPage({viewport:{width:375,height:812}});const errors=[];page.on('pageerror',e=>errors.push(e.message));await page.goto(`${baseURL}/`);await page.waitForFunction(()=>localStorage.getItem('reef-demo-state-v10'));await page.getByRole('button',{name:'打开设置'}).click();await page.getByRole('button',{name:/稳定滴定配方/}).click();
const volume=page.getByLabel('滴定溶液体积（mL）',{exact:true});assert.equal(await volume.inputValue(),'500');assert.match(await page.getByTestId('maintenance-days').innerText(),/6 天/);
await volume.fill('1000');assert.match(await page.getByTestId('maintenance-days').innerText(),/12 天/);
await page.getByLabel('每天运行时间（分钟）',{exact:true}).fill('2');assert.match(await page.getByTestId('maintenance-days').innerText(),/6 天/);
await page.getByLabel('选择指标',{exact:false}).selectOption('kh');assert.match(await page.getByTestId('maintenance-days').innerText(),/12 天/);
await volume.fill('0');assert.equal(await page.getByTestId('maintenance-days').count(),0);assert.ok(await page.getByRole('alert').count()>0);
await volume.fill('500');assert.match(await page.getByTestId('maintenance-days').innerText(),/6 天/);
assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);assert.deepEqual(errors,[]);console.log('PASS: default500→6days,1000→12days,time→6days,KH independent time,zero blocked,mobile no overflow/errors.');
}finally{await browser.close();}
