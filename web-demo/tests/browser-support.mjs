import { chromium } from '@playwright/test';
import { mkdir } from 'node:fs/promises';
export const baseURL = (process.env.BASE_URL || 'http://127.0.0.1:3100').replace(/\/$/, '');
export const timezone = process.env.TEST_TIMEZONE || 'Asia/Shanghai';
export async function launchBrowser() {
  await Promise.all(['artifacts/color-match', 'artifacts/po4-integration'].map(path => mkdir(path, { recursive: true })));
  const browser = await chromium.launch({ channel: process.env.BROWSER_CHANNEL || undefined, headless: true });
  const newPage = browser.newPage.bind(browser), newContext = browser.newContext.bind(browser);
  browser.newPage = options => newPage({ timezoneId: timezone, locale: 'zh-CN', ...options });
  browser.newContext = options => newContext({ timezoneId: timezone, locale: 'zh-CN', ...options });
  return browser;
}
