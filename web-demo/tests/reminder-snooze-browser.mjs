import assert from 'node:assert/strict';
import {expect} from '@playwright/test';
import {launchBrowser,baseURL} from './browser-support.mjs';
const browser=await launchBrowser();
try {
 const page=await browser.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.clock.install({time:new Date('2026-09-09T10:00:00+08:00')});
 await page.goto(baseURL);await page.locator('main[aria-busy=false]').waitFor();
 const key='reef-demo-state-v10';
 await page.evaluate(key=>{const s=JSON.parse(localStorage.getItem(key));s.notificationEnabled=true;s.reminderDismissedDate='';s.reminderSnoozedUntil={};s.maintenanceCycles=[];s.tasks=[{id:555,tankId:s.tankId,title:'稍后回归',cycle:'每 7 天',due:'2026-09-09 09:00',state:'due',source:'manual',scheduledDate:'2026-09-09',intervalDays:7,rolling:{version:1,nextDate:'2026-09-09',revision:0,completed:[]}}];localStorage.setItem(key,JSON.stringify(s));},key);
 await page.reload();const dialog=page.getByRole('dialog',{name:/今天有/});await expect(dialog).toBeVisible();
 const tasks=await page.evaluate(key=>JSON.parse(localStorage.getItem(key)).tasks,key);
 await dialog.getByRole('button',{name:'稍后提醒',exact:true}).click();
 await dialog.getByRole('button',{name:'30 分钟后',exact:true}).click();await expect(dialog).toHaveCount(0);
 await page.reload();await page.locator('main[aria-busy=false]').waitFor();await expect(dialog).toHaveCount(0);
 await page.clock.fastForward(29*60000);await expect(dialog).toHaveCount(0);
 await page.clock.fastForward(60001);await expect(dialog).toBeVisible();
 assert.deepEqual(await page.evaluate(key=>JSON.parse(localStorage.getItem(key)).tasks,key),tasks);
 await dialog.getByRole('button',{name:'稍后提醒',exact:true}).click();
 await dialog.getByLabel('自定义提醒时间').fill('0');await dialog.getByRole('button',{name:'确认稍后提醒'}).click();await expect(dialog.getByRole('alert')).toBeVisible();
 await dialog.getByLabel('自定义提醒时间').fill('1.5');await dialog.getByRole('button',{name:'确认稍后提醒'}).click();await expect(dialog).toHaveCount(0);
 await page.clock.fastForward(90*60000+1);await expect(dialog).toBeVisible();
 await dialog.getByRole('button',{name:'稍后提醒',exact:true}).click();await dialog.getByRole('button',{name:'1 小时后',exact:true}).click();
 await page.evaluate(key=>{const s=JSON.parse(localStorage.getItem(key));s.tasks[0].rolling.completed=[{dueDate:'2026-09-09',completedDate:'2026-09-09'}];s.tasks[0].rolling.nextDate='2026-09-16';localStorage.setItem(key,JSON.stringify(s));},key);
 await page.reload();await page.locator('main[aria-busy=false]').waitFor();await page.clock.fastForward(3600001);await expect(dialog).toHaveCount(0);
 assert.deepEqual(errors,[]);console.log('PASS: preset, refresh, deadline, custom hours, invalid input, unchanged schedule, completed-task suppression.');
} finally {await browser.close();}
