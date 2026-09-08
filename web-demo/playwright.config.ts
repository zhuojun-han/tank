import { defineConfig } from '@playwright/test';
const baseURL = process.env.BASE_URL || 'http://127.0.0.1:3100';
export default defineConfig({
  testDir: './tests/e2e', fullyParallel: false, workers: 1, retries: 0,
  timeout: 120_000, reporter: [['list'], ['html', { open: 'never' }]],
  use: { baseURL, timezoneId: process.env.TEST_TIMEZONE || 'Asia/Shanghai' },
  webServer: process.env.BASE_URL ? undefined : {
    command: 'node tools/preview.mjs --port 3100',
    url: baseURL, reuseExistingServer: false, timeout: 60_000,
    stdout: 'pipe',
  },
});
