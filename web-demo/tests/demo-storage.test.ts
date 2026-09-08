import test from 'node:test';
import assert from 'node:assert/strict';
import { calculateKhTitration, KH_TITRATION_TABLE_ID } from '../app/kh-titration.ts';
import { defaultTanks, defaultParameters, defaultTargets, defaultRecords, defaultTasks } from '../app/demo-state.ts';
import { loadDemoState, saveDemoState, STORAGE_KEY, type DemoState } from '../app/demo-storage.ts';
import { prepareMaintenanceCycle } from '../app/maintenance-cycle.ts';
const defaults: DemoState = { tanks: defaultTanks, tankId: 1, parameters: defaultParameters, targets: defaultTargets, records: defaultRecords, tasks: defaultTasks, maintenanceCycles: [], fishStock: [], timerDefaults: {}, notificationEnabled: false, reminderDismissedDate: '' };
const now = new Date('2026-09-08T12:00:00+08:00');
function store(initial: Record<string, string> = {}) {
  const values = new Map(Object.entries(initial));
  return { getItem: (key: string) => values.get(key) ?? null, setItem: (key: string, value: string) => { values.set(key, value); }, values };
}
test('old snapshots migrate as one valid state and preserve occurrence history, range-only values and cycle inputs', () => {
  const input = { solutionMl: 500, waterL: 200, po4Rise: .02, khDrop: .5, days: 6, khStrength: 6, khPurity: 100, temperature: 20, po4Flow: 1.4, khFlow: 1.4, po4Minutes: 1, khMinutes: 1, po4Unit: 'ml/s' as const, khUnit: 'ml/s' as const };
  const cycle = prepareMaintenanceCycle(input, 'po4', 1, '2026-09-08');
  const state = { ...defaults, maintenanceCycles: [cycle], tasks: [{ ...defaultTasks[0], scheduledDate: '2026-09-01', completedDates: ['2026-09-01'], skippedDates: ['2026-09-04'], reopenedDates: ['2026-09-07'] }] };
  const raw = JSON.stringify(state), storage = store({ 'reef-demo-state-v9': raw });
  const loaded = loadDemoState(() => storage, defaults, now);
  assert.equal(loaded.blocked, false);
  assert.deepEqual(loaded.state.maintenanceCycles, JSON.parse(JSON.stringify([cycle])));
  assert.deepEqual(loaded.state.records, defaultRecords);
  assert.deepEqual(loaded.state.tasks[0].completedDates, ['2026-09-01']);
  assert.equal(saveDemoState(() => storage, loaded.state).ok, true);
  assert.equal(storage.getItem('reef-demo-state-v9'), raw);
  assert.deepEqual(JSON.parse(storage.getItem(STORAGE_KEY)!).maintenanceCycles, JSON.parse(JSON.stringify([cycle])));
});
test('malformed JSON and invalid nested fields block restoration without changing either original or older backups', () => {
  for (const raw of ['{broken', 'null', '{}', JSON.stringify({ ...defaults, records: undefined }), JSON.stringify({ ...defaults, schemaVersion: 1, fishStock: undefined }), JSON.stringify({ ...defaults, records: {} }), JSON.stringify({ ...defaults, tanks: [] }), JSON.stringify({ ...defaults, schemaVersion: 99 }), JSON.stringify({ ...defaults, maintenanceCycles: [{ id: 1 }] }), JSON.stringify({ ...defaults, timerDefaults: { '1:no3': 'bad' } })]) {
    const storage = store({ [STORAGE_KEY]: raw, 'reef-demo-state-v9': JSON.stringify(defaults) });
    const before = [...storage.values];
    const result = loadDemoState(() => storage, defaults, now);
    assert.equal(result.blocked, true, raw);
    assert.match(result.message!, /原存档未修改/);
    assert.deepEqual([...storage.values], before);
    assert.deepEqual(result.state.records, defaults.records);
  }
});
test('storage access and quota errors are explicit; failed saves retain the last good snapshot', () => {
  assert.equal(loadDemoState(() => { throw new Error('Storage denied'); }, defaults).blocked, true);
  const original = JSON.stringify(defaults), storage = store({ [STORAGE_KEY]: original });
  const result = saveDemoState(() => ({ ...storage, setItem() { throw new Error('Quota exceeded'); } }), defaults);
  assert.equal(result.ok, false);
  if (!result.ok) assert.match(result.message, /未能保存本次更改/);
  assert.equal(storage.getItem(STORAGE_KEY), original);
});
test('no existing snapshot initializes a valid state and nullable interpolation remains nullable', () => {
  const storage = store();
  const result = loadDemoState(() => storage, { ...defaults, records: [{ ...defaultRecords[0], interpolation: null }] }, now);
  assert.equal(result.blocked, false);
  assert.equal(saveDemoState(() => storage, result.state).ok, true);
  assert.equal(JSON.parse(storage.getItem(STORAGE_KEY)!).records[0].interpolation, null);
});
test('accepted legacy recipes with blank unused channel inputs restore without changing their chemical effect', () => {
  const input = { solutionMl: 500, waterL: 200, po4Rise: .02, khDrop: .5, khStrength: 6, khPurity: 100, temperature: 20, po4Flow: 1.4, khFlow: 1.4, po4Minutes: 1, khMinutes: 1, po4Unit: 'ml/s' as const, khUnit: 'ml/s' as const };
  for (const chemical of ['po4', 'kh'] as const) {
    const cycle = prepareMaintenanceCycle(input, chemical, 1, '2026-09-08');
    const invalidUnused = chemical === 'po4' ? { khDrop: null, khFlow: null, khMinutes: null, khStrength: null, khPurity: null, temperature: null } : { po4Rise: null, po4Flow: null, po4Minutes: null };
    const storage = store({ [STORAGE_KEY]: JSON.stringify({ ...defaults, maintenanceCycles: [{ ...cycle, input: { ...input, ...invalidUnused } }] }) });
    const restored = loadDemoState(() => storage, defaults, now);
    assert.equal(restored.blocked, false);
    const savedCycle = restored.state.maintenanceCycles[0];
    assert.equal(savedCycle.effectPerMl, cycle.effectPerMl);
    assert.equal(savedCycle.addedStockMl, cycle.addedStockMl);
    assert.equal(savedCycle.refillDate, cycle.refillDate);
    assert.equal(saveDemoState(() => storage, restored.state).ok, true);
    const activeBroken = { ...savedCycle, input: { ...savedCycle.input, waterL: null } };
    const bad = store({ [STORAGE_KEY]: JSON.stringify({ ...defaults, maintenanceCycles: [activeBroken] }) });
    assert.equal(loadDemoState(() => bad, defaults, now).blocked, true);
  }
});


test('KH titration rounded records and original inputs round-trip without changing older records', () => {
  const result = calculateKhTitration(0.8, 0.29);
  const khTitration = { ...result, tableId: KH_TITRATION_TABLE_ID };
  const record = { id: 20, tankId: 1, parameterId: 'kh', low: 7.9, high: 7.9, date: now.toISOString(), note: 'KH 滴定记录', khTitration };
  const state = { ...defaults, records: [record, ...defaultRecords] };
  const storage = store();
  assert.equal(saveDemoState(() => storage, state).ok, true);
  const loaded = loadDemoState(() => storage, defaults, now);
  assert.equal(loaded.blocked, false);
  assert.deepEqual(loaded.state.records, state.records);
  assert.ok(Math.abs(loaded.state.records[0].khTitration!.dkh - 7.85) < 1e-12);

  const edited = { ...loaded.state, records: loaded.state.records.map(r => r.id === 20 ? { ...r, low: 8.1, high: 8.1, edited: true } : r) };
  assert.equal(saveDemoState(() => storage, edited).ok, true);
  assert.deepEqual(loadDemoState(() => storage, defaults, now).state.records[0].khTitration, khTitration);
  for (const invalid of [null, { ...khTitration, initialMl: '0.8' }, { ...khTitration, dkh: null }]) {
    const raw = JSON.stringify({ ...state, records: [{ ...record, khTitration: invalid }] });
    const badStorage = store({ [STORAGE_KEY]: raw });
    assert.equal(loadDemoState(() => badStorage, defaults, now).blocked, true);
    assert.equal(badStorage.getItem(STORAGE_KEY), raw);
  }
});
