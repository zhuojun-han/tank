import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/maintenance/data/maintenance_repository.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';
import 'package:lanjiao_water_quality/webview/native_state_store.dart';
import 'package:lanjiao_water_quality/webview/native_task_actions.dart';
import 'package:lanjiao_water_quality/features/maintenance/domain/rolling_schedule.dart';
import 'package:lanjiao_water_quality/features/calculators/data/maintenance_cycle_repository.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_cycle.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_dosing.dart';

Map<String, dynamic> copyState(Map<String, dynamic> envelope) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(envelope['state'])) as Map);

void addTank(Map<String, dynamic> state, String id) {
  (state['tanks'] as List).add({
    'id': id,
    'name': '新海缸',
    'volume': '100 L',
    'startedOn': '2026-09-01',
  });
  state['tankId'] = id;
  (state['targets'] as List).add({
    'tankId': id,
    'parameterId': 'no3',
    'min': 2,
    'max': 10,
  });
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'early refill accepts the web input projection but keeps old recipes immutable',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      try {
        final store = NativeStateStore(db);
        final input = <String, dynamic>{
          'solutionMl': 500,
          'waterL': 200,
          'po4Rise': .02,
          'khDrop': .5,
          'khStrength': 6,
          'khPurity': 100,
          'temperature': 20,
          'po4Flow': 1.4,
          'khFlow': 1.4,
          'po4Minutes': 1,
          'khMinutes': 1,
          'po4Unit': 'ml/s',
          'khUnit': 'ml/s',
        };
        // Captured from the shared web calculator: the hidden KH input remains
        // in React state after saving a PO4 cycle; native storage only keeps PO4.
        final first = <String, dynamic>{
          'id': 'first',
          'tankId': AppDatabase.defaultTankId,
          'chemical': 'po4',
          'input': input,
          'startDate': '2026-09-12',
          'refillDate': '2026-09-17',
          'solutionMl': 500,
          'dailyLiquidMl': 84,
          'effectPerMl': .04761904761904762,
          'retainedMl': 0,
          'addedStockMl': 2.380952380952381,
          'addedWaterMl': 497.6190476190476,
        };
        var before = await store.readState();
        final initial = copyState(before)..['maintenanceCycles'] = [first];
        before = await store.saveState(
          initial,
          expectedRevision: before['revision'] as int,
        );
        final original = await db.select(db.maintenanceCycles).getSingle();
        final second = <String, dynamic>{
          ...first,
          'id': 'second',
          'previousCycleId': 'first',
          'input': {...input, 'po4Rise': .03},
          'effectPerMl': .07142857142857142,
          'retainedMl': 200,
          'addedStockMl': 2.619047619047619,
          'addedWaterMl': 297.3809523809524,
        };
        final refill = copyState(before)
          ..['maintenanceCycles'] = [
            {...first, 'closedOnDate': '2026-09-12'},
            second,
          ];
        final tampered = copyState({'state': refill});
        ((tampered['maintenanceCycles'] as List).first['input']
                as Map)['po4Rise'] =
            .04;
        await expectLater(
          store.saveState(
            tampered,
            expectedRevision: before['revision'] as int,
          ),
          throwsFormatException,
        );
        expect(await db.select(db.maintenanceCycles).getSingle(), original);
        final saved = await store.saveState(
          refill,
          expectedRevision: before['revision'] as int,
        );
        final cycles = await MaintenanceCycleRepository(db).getCycles();
        expect(cycles.length, 2);
        final old = cycles.singleWhere((c) => c.id == 'first');
        final next = cycles.singleWhere((c) => c.id == 'second');
        expect(old.closedOnDate, '2026-09-12');
        expect(old.input.dailyChange, .02);
        expect(next.input.dailyChange, .03);
        expect(next.retainedMl, 200);
        expect(next.dailyLiquidMl, 84);
        expect(next.refillDate, '2026-09-17');
        expect(
          (await (db.select(
            db.maintenanceCycles,
          )..where((c) => c.id.equals('first'))).getSingle()).inputJson,
          original.inputJson,
        );
        expect(
          await store.saveState(
            copyState(saved),
            expectedRevision: saved['revision'] as int,
          ),
          saved,
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'native task commands preserve completion timing, monthly units and replace plan suffixes atomically',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      try {
        var clock = DateTime(2026, 9, 12, 12);
        final store = NativeStateStore(db), tank = AppDatabase.defaultTankId;
        final actions = NativeTaskActions(db, store, now: () => clock);
        Future<Map<String, dynamic>> act(
          String action,
          Map<String, dynamic> fields,
        ) async {
          await actions.apply({
            'action': action,
            'tankId': tank,
            'expectedRevision': (await store.readState())['revision'],
            ...fields,
          });
          return store.readState();
        }

        await act('create', {
          'title': '每周维护',
          'scheduledDate': '2026-09-10',
          'intervalDays': 7,
          'reminderTime': '19:01',
        });
        final first = await db.select(db.maintenanceTasks).getSingle();
        expect(first.dueAt.toLocal().hour, 19);
        expect(first.dueAt.toLocal().minute, 1);
        final beforeRejectedReopen = await store.readState();
        await expectLater(
          act('reopen', {'taskId': first.id, 'occurrenceDate': '2026-09-10'}),
          throwsFormatException,
        );
        expect(await store.readState(), beforeRejectedReopen);
        await act('complete', {
          'taskId': first.id,
          'occurrenceDate': '2026-09-12',
          'value': '2026-09-11',
        });
        expect(
          rollingSchedule(
            await db.select(db.maintenanceTasks).getSingle(),
          ).nextDate,
          '2026-09-18',
        );
        await act('correct', {
          'taskId': first.id,
          'occurrenceDate': '2026-09-11',
          'value': '2026-09-10',
        });
        expect(
          rollingSchedule(
            await db.select(db.maintenanceTasks).getSingle(),
          ).nextDate,
          '2026-09-17',
        );
        await expectLater(
          act('complete', {'taskId': first.id, 'value': '2026-09-12'}),
          throwsFormatException,
        );
        clock = DateTime(2026, 9, 17, 12);
        for (final tag in ['webview-reminder-only', 'legacy']) {
          await db
              .into(db.taskEvents)
              .insert(
                TaskEventsCompanion.insert(
                  id: tag,
                  taskId: first.id,
                  type: 'snoozed',
                  occurredAt: clock.toUtc(),
                  snoozedUntil: Value(
                    clock.toUtc().add(const Duration(hours: 18)),
                  ),
                  note: Value(tag),
                ),
              );
        }
        await act('delay', {
          'taskId': first.id,
          'occurrenceDate': '2026-09-17',
          'value': 2,
        });
        expect(
          rollingSchedule(
            await db.select(db.maintenanceTasks).getSingle(),
          ).nextDate,
          '2026-09-19',
        );
        expect(
          (await db.select(db.taskEvents).get()).any(
            (e) => e.id == 'webview-reminder-only',
          ),
          isFalse,
        );
        expect(
          (await db.select(db.taskEvents).get()).any((e) => e.id == 'legacy'),
          isTrue,
        );
        final cycleRepo = MaintenanceCycleRepository(db, now: () => clock);
        await cycleRepo.confirm(
          prepareMaintenanceCycle(
            id: 'cycle',
            tankId: tank,
            chemical: DosingChemical.po4,
            input: const MaintenanceDosingInput(dailyChange: .02),
            startDate: '2026-09-12',
          ),
        );
        var cycleRow = await db.select(db.maintenanceCycles).getSingle();
        final input = stateMap(jsonDecode(cycleRow.inputJson))
          ..['webviewSnoozedUntil'] = clock
              .add(const Duration(hours: 3))
              .toUtc()
              .toIso8601String();
        await db
            .update(db.maintenanceCycles)
            .write(
              MaintenanceCyclesCompanion(inputJson: Value(jsonEncode(input))),
            );
        await act('cycle.delay', {
          'cycleId': 'cycle',
          'value': 2,
          'occurrenceDate': '2026-09-17',
        });
        cycleRow = await db.select(db.maintenanceCycles).getSingle();
        expect(cycleRow.refillDate, '2026-09-17');
        expect(cycleRow.refillDeferredUntil, '2026-09-19');
        expect(
          stateMap(
            jsonDecode(cycleRow.inputJson),
          ).containsKey('webviewSnoozedUntil'),
          isFalse,
        );
        await act('update', {
          'taskId': first.id,
          'intervalUnit': 'month',
          'intervalAmount': 2,
        });
        await act('update', {'taskId': first.id, 'title': '改名保留月份'});
        expect(
          (await db.select(db.maintenanceTasks).getSingle()).intervalUnit,
          'month',
        );
        expect(
          (await db.select(db.maintenanceTasks).getSingle()).intervalAmount,
          2,
        );
        await expectLater(
          act('update', {'taskId': first.id, 'intervalDays': 30}),
          throwsFormatException,
        );
        final snapshot = await store.readState();
        await expectLater(
          actions.handle({
            'action': 'stop',
            'taskId': first.id,
            'tankId': 'other',
            'expectedRevision': snapshot['revision'],
          }),
          throwsFormatException,
        );
        expect(await store.readState(), snapshot);

        clock = DateTime(2026, 9, 12, 12);
        Map<String, dynamic> day(String plan, int index, String date) => {
          'id': '$plan-$index',
          'tankId': tank,
          'title': '配方第$index天',
          'cycle': '单次任务',
          'due': '$date 09:00',
          'scheduledDate': date,
          'state': 'soon',
          'source': 'lanthanum-plan',
          'planId': plan,
          'dayIndex': index,
          'totalDays': 3,
          'oneOff': true,
        };
        await act('plan.create', {
          'source': 'lanthanum-plan',
          'fromDate': '2026-09-12',
          'tasks': [
            day('old', 1, '2026-09-12'),
            day('old', 2, '2026-09-13'),
            day('old', 3, '2026-09-14'),
          ],
        });
        await act('complete', {'taskId': 'old-1', 'value': '2026-09-12'});
        await act('plan.stop', {'taskId': 'old-3'});
        final afterStop = {
          for (final t in await db.select(db.maintenanceTasks).get())
            t.id: t.status,
        };
        expect(afterStop['old-1'], 'completed');
        expect(afterStop['old-2'], 'enabled');
        expect(afterStop['old-3'], 'skipped');
        final beforeBadReplace = await store.readState();
        final invalid = day('invalid', 1, '2026-09-13')..['title'] = '';
        await expectLater(
          act('plan.replace', {
            'source': 'lanthanum-plan',
            'fromDate': '2026-09-13',
            'tasks': [invalid],
          }),
          throwsFormatException,
        );
        expect(await store.readState(), beforeBadReplace);
        await act('plan.replace', {
          'source': 'lanthanum-plan',
          'fromDate': '2026-09-13',
          'tasks': [day('new', 1, '2026-09-13')],
        });
        final afterReplace = {
          for (final t in await db.select(db.maintenanceTasks).get())
            t.id: t.status,
        };
        expect(afterReplace['old-1'], 'completed');
        expect(afterReplace['old-2'], 'skipped');
        expect(afterReplace['old-3'], 'skipped');
        expect(afterReplace['new-1'], 'enabled');
        await expectLater(
          actions.handle({
            'action': 'stop',
            'tankId': tank,
            'taskId': first.id,
            'expectedRevision': beforeBadReplace['revision'],
          }),
          throwsA(isA<NativeStateConflict>()),
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'fresh WebView database starts empty, persists UUID data across restart without seeding demos',
    () async {
      final folder = await Directory.systemTemp.createTemp('native-state-');
      final file = File('${folder.path}/state.sqlite');
      var db = AppDatabase(NativeDatabase(file), seedDefaultTank: false);
      try {
        var store = NativeStateStore(db);
        final first = await store.readState();
        final state = copyState(first);
        expect(state['tanks'], isEmpty);
        expect(state['records'], isEmpty);
        expect(state['tankId'], '');
        expect(state['parameters'], hasLength(6));
        const tankId = '00000000-0000-4000-8000-000000009999';
        addTank(state, tankId);
        (state['records'] as List).add({
          'id': '00000000-0000-4000-8000-000000000777',
          'tankId': tankId,
          'parameterId': 'no3',
          'low': 10,
          'high': 25,
          'interpolation': 17,
          'date': '2026-09-08T11:42:00.000Z',
          'note': '人工确认',
          'photoEstimate': {
            'low': 10,
            'high': 25,
            'interpolation': 17.42,
            'source': 'local-lab',
            'algorithmVersion': 'mvp-1',
          },
        });
        state['timerDefaults'] = {'$tankId:no3': 180};
        await store.commitState(
          state,
          expectedRevision: first['revision'] as int,
        );
        final written = await store.readState();
        final records = await db.select(db.testRecords).get();
        expect(records.single.parameterId, AppDatabase.no3Id);
        expect(records.single.estimatedInterpolation, 17.42);
        expect(records.single.confirmedInterpolation, 17);
        expect(records.single.photoPath, isNull);
        await db.close();
        db = AppDatabase(NativeDatabase(file), seedDefaultTank: false);
        store = NativeStateStore(db);
        final reopened = await store.readState();
        expect(reopened, written);
        expect((reopened['state'] as Map)['tanks'], hasLength(1));
        expect(await db.select(db.reagentProfiles).get(), hasLength(1));
      } finally {
        await db.close();
        await folder.delete(recursive: true);
      }
    },
  );

  test(
    'cross-tank record mutation rolls back all changes and missing history cannot delete records',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      try {
        final store = NativeStateStore(db);
        var before = await store.readState();
        var state = copyState(before);
        addTank(state, 'tank-b');
        (state['records'] as List).add({
          'id': 'record-a',
          'tankId': AppDatabase.defaultTankId,
          'parameterId': 'no3',
          'low': 5,
          'high': 5,
          'date': '2026-09-08T10:00:00Z',
          'note': '',
        });
        before = await store.saveState(
          state,
          expectedRevision: before['revision'] as int,
        );
        state = copyState(before);
        (state['tanks'] as List).first['name'] = 'Should roll back';
        (state['records'] as List).single['tankId'] = 'tank-b';
        await expectLater(
          store.commitState(state, expectedRevision: before['revision'] as int),
          throwsFormatException,
        );
        expect(await store.readState(), before);
        state = copyState(before)..['records'] = [];
        await expectLater(
          store.commitState(state, expectedRevision: before['revision'] as int),
          throwsFormatException,
        );
        expect(await db.select(db.testRecords).get(), hasLength(1));
      } finally {
        await db.close();
      }
    },
  );

  test(
    'stale writes reject native updates; unrelated save preserves archival, original estimate and active draft',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      try {
        final store = NativeStateStore(db);
        final first = await store.readState();
        await TankRepository(
          db,
        ).updateTank(tankId: AppDatabase.defaultTankId, name: '原生已更新');
        await expectLater(
          store.commitState(
            copyState(first),
            expectedRevision: first['revision'] as int,
          ),
          throwsA(isA<NativeStateConflict>()),
        );
        final now = DateTime.now().toUtc();
        await db
            .into(db.tanks)
            .insert(
              TanksCompanion.insert(
                id: 'archive',
                name: '旧海缸',
                isArchived: const Value(true),
                notes: const Value('保留'),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.activeTestSessions)
            .insert(
              ActiveTestSessionsCompanion.insert(
                id: 'draft',
                tankId: AppDatabase.defaultTankId,
                parameterId: AppDatabase.no3Id,
                startedAt: now,
                timerDurationSeconds: 300,
                stage: 'waiting',
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.testRecords)
            .insert(
              TestRecordsCompanion.insert(
                id: 'legacy',
                tankId: AppDatabase.defaultTankId,
                parameterId: AppDatabase.no3Id,
                confirmedMinValue: 10,
                confirmedMaxValue: const Value(25),
                estimatedMinValue: const Value(5),
                estimatedMaxValue: const Value(10),
                estimatedInterpolation: const Value(7.12),
                estimationMethod: const Value('legacy'),
                estimationVersion: const Value('old-v'),
                qualityScore: const Value(.72),
                failureReason: const Value('保留'),
                unit: 'mg/L',
                measuredAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );
        var before = await store.readState();
        final state = copyState(before);
        (state['records'] as List).single['low'] = 12;
        (state['records'] as List).single['note'] = '用户改值';
        await store.saveState(
          state,
          expectedRevision: before['revision'] as int,
        );
        final record = await db.select(db.testRecords).getSingle();
        expect(record.confirmedMinValue, 12);
        expect(record.estimatedInterpolation, 7.12);
        expect(record.qualityScore, .72);
        expect(record.failureReason, '保留');
        expect(await db.select(db.activeTestSessions).get(), hasLength(1));
        expect(
          (await db.select(db.tanks).get())
              .singleWhere((t) => t.id == 'archive')
              .notes,
          '保留',
        );
        before = await store.readState();
        expect(
          await store.saveState(
            copyState(before),
            expectedRevision: before['revision'] as int,
          ),
          before,
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'native rolling history remains authoritative and interval units survive Web roundtrip',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      try {
        final repo = MaintenanceRepository(db);
        final taskId = await repo.createTask(
          tankId: AppDatabase.defaultTankId,
          title: '月度维护',
          intervalAmount: 1,
          intervalUnit: MaintenanceIntervalUnit.month,
          dueAt: DateTime(2026, 9, 30, 9),
        );
        final original = await db.select(db.maintenanceTasks).getSingle();
        final store = NativeStateStore(db),
            before = await NativeStateStore(db).readState();
        final state = copyState(before);
        final task = (state['tasks'] as List).single as Map;
        expect(task['nativeIntervalUnit'], 'month');
        expect(task['intervalDays'], isNull);
        expect(task['id'], taskId);
        await store.saveState(
          state,
          expectedRevision: before['revision'] as int,
        );
        expect(await db.select(db.maintenanceTasks).getSingle(), original);
        await repo.setNotificationId(
          tankId: AppDatabase.defaultTankId,
          taskId: taskId,
          notificationId: 7781,
        );
        final withNotification = await db
            .select(db.maintenanceTasks)
            .getSingle();
        expect((await store.readState())['revision'], before['revision']);
        await store.saveState(
          state,
          expectedRevision: before['revision'] as int,
        );
        (task['rolling'] as Map)['completed'] = [
          {'dueDate': '2026-09-30', 'completedDate': '2026-09-09'},
        ];
        await expectLater(
          store.saveState(state, expectedRevision: before['revision'] as int),
          throwsFormatException,
        );
        expect(
          await db.select(db.maintenanceTasks).getSingle(),
          withNotification,
        );
      } finally {
        await db.close();
      }
    },
  );
}
