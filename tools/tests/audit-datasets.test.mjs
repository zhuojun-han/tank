import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { auditDatasets } from '../audit-datasets.mjs';

async function fixture(t, mutate = () => {}) {
  const tempBase = path.resolve(tmpdir());
  const root = await mkdtemp(path.join(tempBase, 'lanjiao-dataset-test-'));
  t.after(async () => {
    // Delete only this test's freshly allocated direct child of the temp folder.
    if (path.dirname(path.resolve(root)) !== tempBase || !path.basename(root).startsWith('lanjiao-dataset-test-')) throw new Error('Unexpected test cleanup path');
    await rm(root, { recursive: true, force: true });
  });
  await mkdir(path.join(root, 'datasets/NO3'), { recursive: true });
  await mkdir(path.join(root, 'resource/NO3'), { recursive: true });
  const bytes = Buffer.from('synthetic bytes for an integrity test; not a photo');
  await writeFile(path.join(root, 'resource/NO3/1_0-1.jpg'), bytes);
  const manifest = { parameter: 'NO3', levels: [0, 1, 5], samples: [{
    id: 'a', imagePath: '../../resource/NO3/1_0-1.jpg',
    sha256: createHash('sha256').update(bytes).digest('hex'), label: { minimum: 0, maximum: 1 },
    batchId: 'unknown-batch', split: 'unassigned', eligibleForFinalEvaluation: false,
    regionsAnnotated: true, regions: { card: { x: 0, y: .5, w: 1, h: .5 }, liquid: { x: .1, y: .1, w: .1, h: .1 } },
    exclusionReasons: ['unknown provenance'],
  }] };
  await mutate(manifest, root);
  await writeFile(path.join(root, 'datasets/NO3/manifest.json'), JSON.stringify(manifest));
  await writeFile(path.join(root, 'project-workspace.json'), JSON.stringify({ datasets: ['datasets/NO3/manifest.json'] }));
  return root;
}

test('current manifests cover resource inputs and pass integrity checks', async () => {
  const report = await auditDatasets();
  assert.equal(report.passed, true, report.failures.join('\n'));
  assert.deepEqual(report.results.map(r => r.parameter).sort(), ['NO3', 'PO4']);
  assert.ok(report.results.every(r => r.images > 0));
});

test('integrity audit accepts metadata but never grants accuracy from a matching file hash', async t => {
  const report = await auditDatasets(await fixture(t));
  assert.equal(report.passed, true);
  assert.equal(report.results[0].eligibleValidationImages, 0);
});

test('modified file and newly added unlisted photo are both detected', async t => {
  const root = await fixture(t, async (_, dir) => {
    await writeFile(path.join(dir, 'resource/NO3/1_0-1.jpg'), 'changed');
    await writeFile(path.join(dir, 'resource/NO3/2_0-1.jpg'), 'new');
  });
  const report = await auditDatasets(root);
  assert.equal(report.passed, false);
  assert.ok(report.failures.some(f => f.includes('hash mismatch')));
  assert.ok(report.failures.some(f => f.includes('absent from manifest')));
});

test('path escapes, invalid regions and unsupported label intervals fail independently', async t => {
  const root = await fixture(t, m => {
    m.samples.push({ ...m.samples[0], id: 'outside', imagePath: '../../../outside.jpg' });
    m.samples[0].regions.card.w = 2;
    m.samples[0].label.maximum = 5;
  });
  const report = await auditDatasets(root);
  for (const text of ['outside resource', 'invalid regions', 'adjacent interval']) assert.ok(report.failures.some(f => f.includes(text)), text);
});

test('same batch cannot cross tuning and validation and unknown samples cannot claim eligibility', async t => {
  const root = await fixture(t, m => {
    m.samples[0].split = 'tuning'; m.samples[0].batchId = 'known-batch';
    m.samples.push({ ...m.samples[0], id: 'b', split: 'validation', eligibleForFinalEvaluation: true });
  });
  const report = await auditDatasets(root);
  assert.ok(report.failures.some(f => f.includes('batch crosses splits')));
  assert.ok(report.failures.some(f => f.includes('eligibility lacks evidence')));
});
