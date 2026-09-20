import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/data/backup/local_backup_service.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_cycle.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_dosing.dart';
import 'package:lanjiao_water_quality/features/calculators/data/maintenance_cycle_repository.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_cycle_items.dart';
import 'package:lanjiao_water_quality/features/maintenance/domain/rolling_schedule.dart';
import 'package:lanjiao_water_quality/webview/native_state_store.dart';
import 'package:lanjiao_water_quality/webview/native_task_actions.dart';

MaintenanceCycle makeCycle(
  String date, {
  String id = 'theory',
  double volume = 250,
  MaintenanceCycle? previous,
  double retained = 0,
}) => prepareMaintenanceCycle(
  input: MaintenanceDosingInput(
    dailyChange: .1,
    flow: 100,
    unit: PumpFlowUnit.mlPerMinute,
    volumeMl: volume,
  ),
  chemical: DosingChemical.po4,
  tankId: AppDatabase.defaultTankId,
  startDate: date,
  id: id,
  previous: previous,
  retainedMl: retained,
  theory: MaintenanceTheory(
    planId: id,
    source: 'lanthanum-plan',
    target: .05,
    planStartDate: date,
    endDate: addRollingDays(date, 2),
    lastDayRatio: .5,
  ),
);

Map<String, dynamic> webCycle(MaintenanceCycle c) => {
  'id': c.id,
  'tankId': c.tankId,
  'chemical': c.chemical.name,
  'startDate': c.startDate,
  'refillDate': c.refillDate,
  'solutionMl': c.solutionMl,
  'dailyLiquidMl': c.dailyLiquidMl,
  'effectPerMl': c.effectPerMl,
  'retainedMl': c.retainedMl,
  'addedStockMl': c.addedStockMl,
  'addedWaterMl': c.addedWaterMl,
  if (c.previousCycleId != null) 'previousCycleId': c.previousCycleId,
  'theory': c.theory!.toJson(),
  'input': {
    'solutionMl': c.input.volumeMl,
    'waterL': c.input.waterL,
    'po4Rise': c.input.dailyChange,
    'po4Flow': c.input.flow,
    'po4Minutes': c.input.minutes,
    'po4Unit': 'ml/min',
    'khStrength': c.input.khStrength,
    'khPurity': c.input.khPurity,
    'temperature': c.input.temperature,
  },
};

void main() {
  test(
    'finite last dose, restart and backup keep the course and reject invalid metadata',
    () async {
      final dir = await Directory.systemTemp.createTemp('theory-cycle-');
      final file = File('${dir.path}/data.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      final c = makeCycle('2026-09-10');
      expect(cycleRemainingMl(c, '2026-09-12'), 50);
      expect(cycleRemainingMl(c, '2026-09-13'), 0);
      expect(cycleRemainingMl(c, '2026-09-30'), 0);
      expect(
        cycleNeedsRefill(c),
        isFalse,
      ); // Exactly enough for the final half dose.
      expect(
        maintenanceCycleNotificationItems([
          c,
        ], DateTime(2026, 9, 10)).single.task.title,
        contains('计划结束'),
      );
      final refill = makeCycle('2026-09-10', volume: 200);
      expect(cycleNeedsRefill(refill), isTrue);
      expect(
        maintenanceCycleOccurrences(
          [refill],
          tankId: c.tankId,
          start: DateTime(2026, 9, 13),
          days: 10,
          now: DateTime(2026, 9, 13),
        ),
        isEmpty,
      );
      expect(
        delayMaintenanceCycle(refill, 10, '2026-09-11').refillDeferredUntil,
        '2026-09-12',
      );
      await MaintenanceCycleRepository(
        db,
        now: () => DateTime(2026, 9, 10),
      ).confirm(c);
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      final restored = (await MaintenanceCycleRepository(
        db,
      ).getCycles()).single;
      expect(restored.theory!.toJson(), c.theory!.toJson());
      final backup = LocalBackupService(db),
          json = await LocalBackupService(db).exportJson();
      expect((jsonDecode(json) as Map)['formatVersion'], 13);
      await backup.restoreReplace(json);
      expect(
        (await MaintenanceCycleRepository(
          db,
        ).getCycles()).single.theory!.toJson(),
        c.theory!.toJson(),
      );
      final bad = jsonDecode(json) as Map<String, dynamic>;
      final row = (bad['maintenanceCycles'] as List).single as Map;
      final input = jsonDecode(row['inputJson'] as String) as Map;
      (input['theory'] as Map)['lastDayRatio'] = 2;
      row['inputJson'] = jsonEncode(input);
      await expectLater(
        backup.restoreReplace(jsonEncode(bad)),
        throwsFormatException,
      );
      expect(
        (await MaintenanceCycleRepository(
          db,
        ).getCycles()).single.theory!.lastDayRatio,
        .5,
      );
    },
  );

  test(
    'native confirmation atomically replaces the old source and stop preserves other tanks',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.now(), today = cycleDateKey(DateTime.now());
      final store = NativeStateStore(db);
      await store.readState();
      await db
          .into(db.tanks)
          .insert(
            TanksCompanion.insert(
              id: 'other',
              name: 'other',
              createdAt: now,
              updatedAt: now,
            ),
          );
      for (final id in ['old', 'other', 'kh']) {
        await db
            .into(db.maintenanceTasks)
            .insert(
              MaintenanceTasksCompanion.insert(
                id: id,
                tankId: id == 'other' ? 'other' : AppDatabase.defaultTankId,
                title: id,
                intervalAmount: 1,
                intervalUnit: 'day',
                dueAt: now,
                isOneOff: const Value(true),
                source: Value(
                  id == 'kh' ? 'alkalinity-plan' : 'lanthanum-plan',
                ),
                planId: Value(id),
                planDayIndex: const Value(1),
                planTotalDays: const Value(1),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
      final stable = prepareMaintenanceCycle(
        input: const MaintenanceDosingInput(dailyChange: .1),
        chemical: DosingChemical.po4,
        tankId: AppDatabase.defaultTankId,
        startDate: today,
        id: 'stable',
      );
      await MaintenanceCycleRepository(db).confirm(stable);
      final next = makeCycle(today, previous: stable, retained: 100);
      var before = await store.readState();
      final state =
          jsonDecode(jsonEncode(before['state'])) as Map<String, dynamic>;
      ((state['maintenanceCycles'] as List).single as Map)['closedOnDate'] =
          today;
      (state['maintenanceCycles'] as List).add(webCycle(next));
      await db.customStatement(
        "CREATE TRIGGER reject_theory BEFORE INSERT ON maintenance_cycles WHEN NEW.id = 'theory' BEGIN SELECT RAISE(ABORT, 'test'); END",
      );
      await expectLater(
        store.saveState(state, expectedRevision: before['revision'] as int),
        throwsA(anything),
      );
      expect(
        (await MaintenanceCycleRepository(db).getCycles()).single.closedOnDate,
        isNull,
      );
      expect(
        (await db.select(db.maintenanceTasks).get()).every(
          (t) => t.status == 'enabled',
        ),
        isTrue,
      );
      await db.customStatement('DROP TRIGGER reject_theory');
      before = await store.saveState(
        state,
        expectedRevision: before['revision'] as int,
      );
      final tasks = {
        for (final t in await db.select(db.maintenanceTasks).get()) t.id: t,
      };
      expect(tasks['old']!.status, 'skipped');
      expect(tasks['other']!.status, 'enabled');
      expect(tasks['kh']!.status, 'enabled');
      final action = NativeTaskActions(db, store);
      await expectLater(
        action.handle({
          'action': 'cycle.stop',
          'taskId': next.id,
          'tankId': 'other',
          'expectedRevision': before['revision'],
        }),
        throwsFormatException,
      );
      await action.handle({
        'action': 'cycle.stop',
        'taskId': next.id,
        'tankId': next.tankId,
        'expectedRevision': before['revision'],
      });
      expect(
        (await MaintenanceCycleRepository(db).getCycles()).last.closedOnDate,
        today,
      );
    },
  );
}
