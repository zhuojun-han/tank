import test from 'node:test';
import assert from 'node:assert/strict';
import { calculateKhTitration, KH_TITRATION_TABLE_ID } from '../app/kh-titration.ts';
import { defaultTanks, defaultParameters, defaultTargets, defaultRecords, defaultTasks } from '../app/demo-state.ts';
import { loadDemoState, saveDemoState, STORAGE_KEY, type DemoState } from '../app/demo-storage.ts';
import { prepareMaintenanceCycle } from '../app/maintenance-cycle.ts';
import { completeRollingTask, projectRollingTasks, taskDisplayDate } from '../app/rolling-task.ts';
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

test('KH defaults fill only old enabled empty ranges; custom bounds and disabled tanks stay untouched', () => {
  const oldTargets = [...defaultTargets,
    { tankId: 1, parameterId: 'kh', min: null, max: null },
    { tankId: 2, parameterId: 'kh', min: 7.8, max: 8.6 },
    { tankId: 3, parameterId: 'kh', min: null, max: 9.5 },
  ];
  const original = JSON.stringify({ ...defaults, targets: oldTargets });
  const storage = store({ [STORAGE_KEY]: original });
  const result = loadDemoState(() => storage, defaults, now);
  assert.equal(result.blocked, false);
  assert.equal(result.state.khTargetDefaultsApplied, true);
  assert.deepEqual(result.state.targets, oldTargets.map(t => t.tankId === 1 && t.parameterId === 'kh' ? { ...t, min: 7, max: 9 } : t));
  assert.equal(storage.getItem(STORAGE_KEY), original, 'loading does not directly overwrite the snapshot');
  assert.deepEqual(result.state.records, defaults.records);
  const withoutKh = loadDemoState(() => store({ [STORAGE_KEY]: JSON.stringify(defaults) }), defaults, now);
  assert.deepEqual(withoutKh.state.targets, defaultTargets, 'disabled KH is not enabled by migration');
});

test('intentional empty KH range stays empty after initialization, save and refresh', () => {
  const storage = store({ [STORAGE_KEY]: JSON.stringify({ ...defaults, targets: [...defaultTargets, { tankId: 1, parameterId: 'kh', min: null, max: null }] }) });
  const loaded = loadDemoState(() => storage, defaults, now).state;
  const cleared = { ...loaded, targets: loaded.targets.map(t => t.parameterId === 'kh' ? { ...t, min: null, max: null } : t) };
  assert.equal(saveDemoState(() => storage, cleared).ok, true);
  const restored = loadDemoState(() => storage, defaults, now);
  assert.equal(restored.blocked, false);
  assert.equal(restored.state.khTargetDefaultsApplied, true);
  assert.deepEqual(restored.state.targets, cleared.targets);
});

test('malformed KH initialization markers block loading without touching the original', () => {
  const original = JSON.stringify({ ...defaults, khTargetDefaultsApplied: 'true' });
  const storage = store({ [STORAGE_KEY]: original });
  assert.equal(loadDemoState(() => storage, defaults, now).blocked, true);
  assert.equal(storage.getItem(STORAGE_KEY), original);
});

test('empty storage initializes rolling defaults without persisting render dates', () => {
  const storage = store();
  const loaded = loadDemoState(() => storage, defaults, now);
  assert.equal(loaded.blocked, false);
  assert.ok(loaded.state.tasks.every(task => task.rolling?.version === 1));
  assert.ok(loaded.state.tasks.every(task => task.rolling!.completed.length === 0));
  assert.ok(loaded.state.tasks.every(task => !Object.hasOwn(task, 'projection')));
  assert.equal(storage.values.size, 0);
});

test('v4-v10 task migration keeps legacy history and does not drift across later reads and saves', () => {
  const oldTask: DemoState['tasks'][number] = { ...defaultTasks[0], scheduledDate: '2026-09-01', intervalDays: 3,
    defaultCompletedBeforeDate: '2026-09-08', completedDates: ['2026-09-01'], skippedDates: ['2026-09-04'],
    reopenedDates: ['2026-09-07'], snoozedDates: ['2026-09-07'], snoozedUntilByDate: { '2026-09-07': '2026-09-07T03:00:00Z' } };
  for (const version of [4, 5, 6, 7, 8, 9, 10]) {
    const oldKey = `reef-demo-state-v${version}`;
    const original = JSON.stringify({ ...defaults, tasks: [oldTask] });
    const storage = store({ [oldKey]: original });
    const loaded = loadDemoState(() => storage, defaults, now);
    assert.equal(loaded.blocked, false, oldKey);
    const migrated = loaded.state.tasks[0];
    assert.equal(migrated.rolling!.nextDate, '2026-09-07');
    assert.deepEqual(migrated.rolling!.completed, []);
    assert.deepEqual(migrated.rolling!.legacySchedule, { scheduledDate: '2026-09-01', intervalDays: 3, defaultCompletedBeforeDate: '2026-09-08' });
    for (const field of ['completedDates', 'skippedDates', 'reopenedDates', 'snoozedDates', 'snoozedUntilByDate'] as const) {
      assert.deepEqual(migrated[field], oldTask[field], field);
    }
    assert.equal(storage.getItem(oldKey), original, 'read migration is not a write');
    assert.equal(saveDemoState(() => storage, loaded.state).ok, true);
    const firstSave = storage.getItem(STORAGE_KEY);
    const restored = loadDemoState(() => storage, defaults, new Date('2026-10-11T12:00:00+08:00'));
    assert.equal(restored.blocked, false);
    assert.deepEqual(restored.state.tasks, loaded.state.tasks);
    assert.equal(saveDemoState(() => storage, restored.state).ok, true);
    assert.equal(storage.getItem(STORAGE_KEY), firstSave, 'loading on a later day must not move the saved baseline');
    if (version !== 10) assert.equal(storage.getItem(oldKey), original);
  }
});

test('actual completion history survives storage without becoming legacy or projected dates', () => {
  const storage = store({ [STORAGE_KEY]: JSON.stringify({ ...defaults, tasks: [{ ...defaultTasks[0], scheduledDate: '2026-09-01', intervalDays: 3 }] }) });
  const state = loadDemoState(() => storage, defaults, now).state;
  const completed = completeRollingTask(state.tasks, state.tasks[0].id, '2026-09-07', '2026-09-08');
  assert.equal(saveDemoState(() => storage, { ...state, tasks: completed }).ok, true);
  const restored = loadDemoState(() => storage, defaults, new Date('2026-09-15T12:00:00+08:00'));
  assert.equal(restored.blocked, false);
  assert.deepEqual(restored.state.tasks[0].rolling, completed[0].rolling);
  assert.deepEqual(restored.state.tasks[0].rolling!.completed, [{ dueDate: '2026-09-08', completedDate: '2026-09-07' }]);
  assert.equal(restored.state.tasks[0].rolling!.nextDate, '2026-09-10');
  assert.equal(taskDisplayDate(projectRollingTasks(restored.state.tasks, '2026-09-15')[0], '2026-09-15'), '2026-09-15');
});

test('malformed rolling data blocks load and save while preserving the original snapshot', () => {
  const valid = { version: 1, nextDate: '2026-09-09', revision: 2, completed: [{ dueDate: '2026-09-08', completedDate: '2026-09-07' }] };
  const invalidValues: unknown[] = [null, [], true, {}, { ...valid, version: 2 }, { ...valid, nextDate: '2026-02-30' },
    { ...valid, nextDate: '2026-9-9' }, { ...valid, revision: -1 }, { ...valid, revision: 0.5 },
    { ...valid, revision: Number.MAX_SAFE_INTEGER + 1 }, { ...valid, completed: {} },
    { ...valid, completed: [null] }, { ...valid, completed: [{ dueDate: '2026-09-08' }] },
    { ...valid, completed: [{ dueDate: 'bad', completedDate: '2026-09-07' }] },
    { ...valid, completed: [{ dueDate: '2026-09-08', completedDate: '2026-02-30' }] },
    { ...valid, completed: [...valid.completed, ...valid.completed] },
    { ...valid, completed: [...valid.completed, { dueDate: '2026-09-09', completedDate: '2026-09-06' }] },
    { ...valid, legacySchedule: {} },
    { ...valid, legacySchedule: { scheduledDate: '2026-09-01', defaultCompletedBeforeDate: 'bad' } },
    { ...valid, legacySchedule: { scheduledDate: '2026-09-01', defaultCompletedBeforeDate: '2026-09-08', intervalDays: 0 } },
  ];
  for (const rolling of invalidValues) {
    const invalid = { ...defaults, tasks: [{ ...defaultTasks[0], scheduledDate: '2026-09-01', rolling }] } as unknown as DemoState;
    const raw = JSON.stringify(invalid);
    const storage = store({ [STORAGE_KEY]: raw, 'reef-demo-state-v9': JSON.stringify(defaults) });
    const before = [...storage.values];
    assert.equal(loadDemoState(() => storage, defaults, now).blocked, true, raw);
    assert.equal(saveDemoState(() => storage, invalid).ok, false, raw);
    assert.deepEqual([...storage.values], before);
  }
});

test('ordered real completion dates allow earlier actual dates and nonmonotonic historical due dates', () => {
  const rolling = { version: 1 as const, nextDate: '2026-09-08', revision: 3,
    completed: [{ dueDate: '2026-09-08', completedDate: '2026-09-03' }, { dueDate: '2026-09-06', completedDate: '2026-09-05' }],
    legacySchedule: { scheduledDate: '2026-08-01', defaultCompletedBeforeDate: '2026-09-01', intervalDays: 1.5 } };
  const state = { ...defaults, tasks: [{ ...defaultTasks[0], scheduledDate: '2026-08-01', rolling }] };
  const storage = store();
  assert.equal(saveDemoState(() => storage, state).ok, true);
  const loaded = loadDemoState(() => storage, defaults, now);
  assert.equal(loaded.blocked, false);
  assert.deepEqual(loaded.state.tasks[0].rolling, rolling);
});

test('projection is stripped on load and save without mutating in-memory tasks', () => {
  const state = loadDemoState(() => store(), defaults, now).state;
  const tasks = projectRollingTasks(state.tasks, '2026-09-20');
  const projection = tasks[0].projection;
  assert.ok(projection);
  const storage = store();
  assert.equal(saveDemoState(() => storage, { ...state, tasks }).ok, true);
  const parsed = JSON.parse(storage.getItem(STORAGE_KEY)!);
  assert.ok(parsed.tasks.every((task: object) => !Object.hasOwn(task, 'projection')));
  assert.deepEqual(tasks[0].projection, projection);
  const stale = store({ [STORAGE_KEY]: JSON.stringify({ ...state, tasks }) });
  const restored = loadDemoState(() => stale, defaults, now);
  assert.equal(restored.blocked, false);
  assert.ok(restored.state.tasks.every(task => !Object.hasOwn(task, 'projection')));
  assert.deepEqual(restored.state.tasks[0].rolling, state.tasks[0].rolling);
});

test('deferred refill dates round-trip without changing the reservoir and invalid dates block writes', () => {
  const input = { solutionMl: 500, waterL: 200, po4Rise: .02, khDrop: .5, khStrength: 6, khPurity: 100, temperature: 20, po4Flow: 1.4, khFlow: 1.4, po4Minutes: 1, khMinutes: 1, po4Unit: 'ml/s' as const, khUnit: 'ml/s' as const };
  const cycle = { ...prepareMaintenanceCycle(input, 'po4', 1, '2026-09-08'), refillDeferredUntil: '2026-09-16' };
  const state = { ...defaults, maintenanceCycles: [cycle] };
  const storage = store();
  assert.equal(saveDemoState(() => storage, state).ok, true);
  const saved = storage.getItem(STORAGE_KEY);
  const restored = loadDemoState(() => storage, defaults, now);
  assert.equal(restored.blocked, false);
  assert.deepEqual(restored.state.maintenanceCycles, JSON.parse(JSON.stringify([cycle])));
  for (const refillDeferredUntil of [null, '', '2026-02-30', 20260916]) {
    const invalid = { ...state, maintenanceCycles: [{ ...cycle, refillDeferredUntil }] } as unknown as DemoState;
    assert.equal(saveDemoState(() => storage, invalid).ok, false);
    assert.equal(storage.getItem(STORAGE_KEY), saved);
    const raw = JSON.stringify(invalid);
    const bad = store({ [STORAGE_KEY]: raw });
    assert.equal(loadDemoState(() => bad, defaults, now).blocked, true);
    assert.equal(bad.getItem(STORAGE_KEY), raw);
  }
});

test('loading reads only through the first existing snapshot, including a damaged newest one', () => {
  for (const [key, raw, blocked, expectedReads] of [
    [STORAGE_KEY, JSON.stringify(defaults), false, [STORAGE_KEY]],
    [STORAGE_KEY, '{broken', true, [STORAGE_KEY]],
    ['reef-demo-state-v8', JSON.stringify(defaults), false, [STORAGE_KEY, 'reef-demo-state-v9', 'reef-demo-state-v8']],
  ] as const) {
    const storage = store({ [key]: raw, 'reef-demo-state-v4': JSON.stringify(defaults) });
    const reads: string[] = [];
    const before = [...storage.values];
    const loaded = loadDemoState(() => ({ ...storage, getItem(candidate) {
      reads.push(candidate);
      return storage.getItem(candidate);
    } }), defaults, now);
    assert.equal(loaded.blocked, blocked);
    assert.deepEqual(reads, expectedReads);
    assert.deepEqual([...storage.values], before);
  }
});
