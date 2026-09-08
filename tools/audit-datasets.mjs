import { readFile, readdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const defaultRoot = fileURLToPath(new URL('../', import.meta.url));
const validRect = r => r && ['x', 'y', 'w', 'h'].every(k => Number.isFinite(r[k]))
  && r.x >= 0 && r.y >= 0 && r.w > 0 && r.h > 0 && r.x + r.w <= 1 && r.y + r.h <= 1;

/** Metadata and integrity checks only: no accuracy or confidence is inferred. */
export async function auditDatasets(root = defaultRoot) {
  const config = JSON.parse(await readFile(path.join(root, 'project-workspace.json'), 'utf8'));
  const failures = [], results = [];
  for (const relative of config.datasets) {
    const manifestPath = path.join(root, relative);
    const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
    const levels = manifest.supportedLevels ?? manifest.levels;
    if (!Array.isArray(levels) || levels.length < 2 || levels.some((n, i) => !Number.isFinite(n) || n < 0 || i > 0 && n <= levels[i - 1])) {
      failures.push(`${relative}: invalid color levels`); continue;
    }
    if (!Array.isArray(manifest.samples)) { failures.push(`${relative}: samples must be an array`); continue; }
    const ids = new Set(), hashes = new Set(), imagePaths = new Set(), batchSplits = new Map();
    let eligible = 0;
    for (const sample of manifest.samples) {
      const context = `${manifest.parameter}/${sample.id}`;
      if (!sample.id || ids.has(sample.id)) failures.push(`${context}: duplicate or missing ID`);
      ids.add(sample.id);
      if (!/^[a-f0-9]{64}$/.test(sample.sha256 ?? '') || hashes.has(sample.sha256)) failures.push(`${context}: invalid or duplicate hash`);
      hashes.add(sample.sha256);
      const absolute = path.resolve(path.dirname(manifestPath), sample.imagePath ?? '');
      const fromResource = path.relative(path.join(root, 'resource'), absolute);
      if (path.isAbsolute(sample.imagePath ?? '') || fromResource.startsWith('..') || path.isAbsolute(fromResource)) {
        failures.push(`${context}: image path is outside resource`); continue;
      }
      imagePaths.add(absolute);
      try {
        const actual = createHash('sha256').update(await readFile(absolute)).digest('hex');
        if (actual !== sample.sha256) failures.push(`${context}: image hash mismatch`);
      } catch { failures.push(`${context}: image is missing`); }
      const label = sample.label ?? sample.manualLabel;
      const low = levels.indexOf(label?.minimum), high = levels.indexOf(label?.maximum);
      if (low < 0 || high < low || high - low > 1) failures.push(`${context}: label must be a level or adjacent interval`);
      if (!['unassigned', 'tuning', 'validation'].includes(sample.split)) failures.push(`${context}: invalid split`);
      if (sample.split !== 'unassigned') {
        if (!sample.batchId || /^unknown/.test(sample.batchId)) failures.push(`${context}: assigned samples need a known batch`);
        const previous = batchSplits.get(sample.batchId);
        if (previous && previous !== sample.split) failures.push(`${context}: batch crosses splits`);
        batchSplits.set(sample.batchId, sample.split);
      }
      if (sample.regionsAnnotated && (!validRect(sample.regions?.card) || !validRect(sample.regions?.liquid))) failures.push(`${context}: missing or invalid regions`);
      if (sample.eligibleForFinalEvaluation) {
        eligible++;
        if (sample.split !== 'validation' || !sample.regionsAnnotated || ['reagentLot', 'cardVersion', 'device', 'lighting', 'capturedAt'].some(k => !sample[k]) || sample.exclusionReasons?.length) {
          failures.push(`${context}: final evaluation eligibility lacks evidence`);
        }
      } else if (!sample.exclusionReasons?.length) failures.push(`${context}: missing exclusion reasons`);
    }
    const resourceDir = path.join(root, 'resource', manifest.parameter);
    for (const file of await readdir(resourceDir)) {
      if ((/^\d+_.+\.jpg$/i.test(file) || file === '测试液与完整色卡同框示例.jpg') && !imagePaths.has(path.join(resourceDir, file))) {
        failures.push(`${manifest.parameter}/${file}: input image is absent from manifest`);
      }
    }
    results.push({ parameter: manifest.parameter, images: manifest.samples.length, eligibleValidationImages: eligible });
  }
  return { passed: failures.length === 0, results, failures };
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const result = await auditDatasets();
  console.log(JSON.stringify(result, null, 2));
  if (!result.passed) process.exitCode = 1;
}
