// Run the deployed Worker + assets locally. vinext 0.0.50's Node static-file
// cache uses Windows backslashes as URL keys, so nested JS/CSS otherwise 404.
import { resolve } from 'node:path';
import { spawn } from 'node:child_process';
process.env.WRANGLER_SEND_METRICS ??= 'false';
process.env.WRANGLER_LOG_PATH ??= resolve('.wrangler/logs');
process.env.XDG_CONFIG_HOME ??= resolve('.cache/config');
process.env.MINIFLARE_REGISTRY_PATH ??= resolve('.wrangler/registry');
const portIndex = process.argv.indexOf('--port');
const port = portIndex >= 0 ? process.argv[portIndex + 1] : process.env.PORT || '3000';
const args = [resolve('node_modules/wrangler/bin/wrangler.js'), 'dev',
  '--config', 'dist/server/wrangler.json', '--port', port, '--ip', '127.0.0.1', '--local', '--show-interactive-dev-session', 'false'];
const child = spawn(process.execPath, args, { stdio: 'inherit', env: process.env });
process.on('SIGINT', () => child.kill('SIGINT'));
process.on('SIGTERM', () => child.kill('SIGTERM'));
child.on('error', error => { console.error(error); process.exitCode = 1; });
child.on('exit', (code, signal) => {
  if (code !== 0) console.error(`[preview] Wrangler exited: code=${code ?? 'none'}, signal=${signal ?? 'none'}`);
  process.exitCode = code ?? 1;
});
