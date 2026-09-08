import { test } from '@playwright/test';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
const run = promisify(execFile);
// Explicit maintained suite. Dataset audits require the parent project's images
// and have their own command; retired UI scripts are indexed under archive/.
for (const script of [
  'storage-browser.mjs', 'chemical-preview-browser.mjs', 'color-match-browser.mjs',
  'photo-record-browser.mjs', 'unified-photo-rotation.mjs', 'image-input-browser.mjs', 'photo-timer-routing.mjs',
  'po4-integration-history.mjs', 'line-history.mjs', 'history-window-browser.mjs', 'paged-record-list.mjs',
  'maintenance-volume.mjs', 'maintenance-browser.mjs', 'maintenance-cycle-browser.mjs',
  'maintenance-countdown-browser.mjs', 'task-postponement-browser.mjs', 'snooze-timer-browser.mjs',
  'kh-titration-browser.mjs', 'target-linkage-browser.mjs',
]) {
  test(script, async ({}, info) => {
    const { stdout, stderr } = await run(process.execPath, [`tests/${script}`], {
      cwd: process.cwd(), timeout: 110_000, maxBuffer: 4 * 1024 * 1024,
      env: { ...process.env, BASE_URL: String(info.project.use.baseURL) },
    });
    console.log(stdout); if (stderr) console.error(stderr);
  });
}
