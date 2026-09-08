import { readFile, readdir, access } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { auditDatasets } from './audit-datasets.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const config = JSON.parse(await readFile(path.join(root, 'project-workspace.json'), 'utf8'));
const failures = [], notes = [];
const actualNode = process.versions.node.split('.').map(Number);
const minimumNode = config.runtime.minimumNode.split('.').map(Number);
const difference = actualNode.findIndex((part, index) => part !== minimumNode[index]);
if (difference >= 0 && actualNode[difference] < minimumNode[difference]) failures.push(`Node ${config.runtime.minimumNode} or later is required`);
const exists = async p => { try { await access(p); return true; } catch { return false; } };
const slash = p => p.split(path.sep).join('/');
async function markdown(dir) {
  const out = [];
  for (const e of await readdir(path.join(root, dir), { withFileTypes: true })) {
    const name = path.join(dir, e.name);
    if (e.isDirectory()) out.push(...await markdown(name));
    else if (e.name.endsWith('.md')) out.push(name);
  }
  return out;
}
const docs = ['README.md', 'AGENTS.md', 'app/README.md', 'web-demo/README.md', ...await markdown('docs')];
for (const relative of docs) {
  const filename = path.join(root, relative);
  const source = await readFile(filename, 'utf8');
  if (source.includes('\uFFFD')) failures.push(`${relative}: invalid UTF-8 replacement character`);
  const limit = config.entryDocumentLimits[slash(relative)];
  if (limit && source.trimEnd().split(/\r?\n/).length > limit) failures.push(`${relative}: exceeds ${limit}-line entry-document limit; archive history`);
  for (const match of source.replace(/```[\s\S]*?```/g, '').matchAll(/\]\(([^)]+)\)/g)) {
    const target = match[1].replace(/^<|>$/g, '').split('#')[0];
    if (!target || /^[a-z][a-z\d+.-]*:/i.test(target)) continue;
    const absolute = path.resolve(path.dirname(filename), decodeURIComponent(target));
    if (await exists(absolute)) continue;
    const projectPath = slash(path.relative(root, absolute));
    if (config.localEvidenceDirectories.some(d => projectPath === d || projectPath.startsWith(`${d}/`)) || (config.localEvidenceExtensions ?? []).includes(path.extname(projectPath))) {
      notes.push(`${relative}: local evidence not present: ${projectPath}`); continue;
    }
    failures.push(`${relative}: broken link ${target}`);
  }
}
for (const repo of config.repositories) {
  if (!await exists(path.join(root, repo.path, '.git'))) notes.push(`${repo.path}: no Git metadata (source archive or checkout setup required)`);
}
for (const module of config.modules) {
  if (!await exists(path.join(root, module))) failures.push(`${module}: required source module is missing`);
  if (await exists(path.join(root, module, '.git'))) failures.push(`${module}: nested Git metadata must not replace source files with a gitlink`);
}
const datasets = await auditDatasets(root);
failures.push(...datasets.failures);
for (const contract of config.sharedContracts ?? []) {
  try {
    const source = JSON.parse(await readFile(path.join(root, contract.source), 'utf8'));
    if (!source.defaults || !Array.isArray(source.cases) || source.cases.length === 0) failures.push(`${contract.source}: shared contract must contain defaults and cases`);
  } catch { failures.push(`${contract.source}: missing or invalid shared contract`); }
}
const ci = await readFile(path.join(root, '.github/workflows/flutter.yml'), 'utf8');
if (!ci.includes('project-workspace.json')) failures.push('Flutter CI must use the pinned workspace runtime configuration');
console.log(JSON.stringify({ passed: failures.length === 0, documents: docs.length, datasets: datasets.results, failures, notes }, null, 2));
if (failures.length) process.exitCode = 1;
