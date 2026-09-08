import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/data/backup/local_backup_service.dart';
import 'package:lanjiao_water_quality/features/calculators/data/maintenance_cycle_repository.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_cycle.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_dosing.dart';
import 'package:lanjiao_water_quality/features/maintenance/data/maintenance_repository.dart';
import 'package:lanjiao_water_quality/features/maintenance/domain/rolling_schedule.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';
import 'package:lanjiao_water_quality/features/test_timer/domain/kh_titration.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'v10 upgrade preserves data and initializes only enabled empty KH once',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'app-v11-migration-',
      );
      final file = File('${directory.path}/db.sqlite');
      final old = AppDatabase(NativeDatabase(file));
      await old.select(old.tanks).get();
      await old.customStatement(
        "INSERT INTO tank_parameters (tank_id,parameter_id,is_enabled,updated_at) VALUES (?, ?, 1, 0)",
        [AppDatabase.defaultTankId, AppDatabase.khId],
      );
      await old.customStatement(
        "INSERT INTO test_records (id,tank_id,parameter_id,confirmed_min_value,unit,measured_at,created_at,updated_at) VALUES ('old-range',?,?,10,'mg/L',0,0,0)",
        [AppDatabase.defaultTankId, AppDatabase.no3Id],
      );
      await old.customStatement(
        'ALTER TABLE app_preferences DROP COLUMN kh_target_defaults_applied',
      );
      await old.customStatement(
        'ALTER TABLE test_records DROP COLUMN kh_titration_json',
      );
      await old.customStatement(
        'ALTER TABLE maintenance_tasks DROP COLUMN rolling_json',
      );
      await old.customStatement('DROP TABLE maintenance_cycles');
      await old.customStatement(
        'CREATE TABLE legacy_targets (id TEXT NOT NULL PRIMARY KEY, tank_id TEXT NOT NULL REFERENCES tanks(id), parameter_id TEXT NOT NULL REFERENCES water_parameters(id), min_value REAL NOT NULL, max_value REAL NOT NULL, unit TEXT NOT NULL, updated_at INTEGER NOT NULL, UNIQUE(tank_id,parameter_id))',
      );
      await old.customStatement(
        'INSERT INTO legacy_targets SELECT * FROM water_quality_targets',
      );
      await old.customStatement('DROP TABLE water_quality_targets');
      await old.customStatement(
        'ALTER TABLE legacy_targets RENAME TO water_quality_targets',
      );
      await old.customStatement('PRAGMA user_version=10');
      await old.close();
      final db = AppDatabase(NativeDatabase(file));
      try {
        final target = await db.select(db.waterQualityTargets).getSingle();
        expect([target.minValue, target.maxValue], [7, 9]);
        expect((await db.select(db.testRecords).getSingle()).id, 'old-range');
        expect(await db.select(db.maintenanceCycles).get(), isEmpty);
        expect(
          (await db.select(db.appPreferences).getSingle())
              .khTargetDefaultsApplied,
          isTrue,
        );
        await db
            .update(db.waterQualityTargets)
            .write(
              const WaterQualityTargetsCompanion(
                minValue: Value(null),
                maxValue: Value(null),
              ),
            );
        await db.initializeKhTargetDefaults();
        expect(
          (await db.select(db.waterQualityTargets).getSingle()).minValue,
          isNull,
        );
        final columns = await db
            .customSelect('PRAGMA table_info(water_quality_targets)')
            .get();
        expect(
          columns
              .where((c) => c.read<String>('name') == 'min_value')
              .single
              .read<int>('notnull'),
          0,
        );
      } finally {
        await db.close();
        directory.deleteSync(recursive: true);
      }
    },
  );

  test(
    'v11 backup preserves recipes, delayed refill, rolling history and raw KH metadata',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final restored = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      addTearDown(restored.close);
      final now = DateTime(2026, 9, 8, 12);
      final repo = MaintenanceCycleRepository(db, now: () => now);
      final first = prepareMaintenanceCycle(
        input: const MaintenanceDosingInput(
          dailyChange: .5,
          flow: 100,
          unit: PumpFlowUnit.mlPerMinute,
        ),
        chemical: DosingChemical.kh,
        tankId: AppDatabase.defaultTankId,
        startDate: '2026-09-05',
        id: 'first',
      );
      await repo.confirm(first);
      final next = prepareMaintenanceCycle(
        input: const MaintenanceDosingInput(
          dailyChange: .5,
          flow: 100,
          unit: PumpFlowUnit.mlPerMinute,
          khStrength: 8,
        ),
        chemical: DosingChemical.kh,
        tankId: AppDatabase.defaultTankId,
        startDate: '2026-09-07',
        id: 'second',
        previous: first,
        retainedMl: 300,
      );
      await repo.confirm(next);
      await repo.delay('second', 2);
      await repo.setNotificationId('second', 901);
      final tasks = MaintenanceRepository(db, now: () => now);
      final taskId = await tasks.createTask(
        tankId: AppDatabase.defaultTankId,
        title: 'weekly',
        intervalAmount: 7,
        intervalUnit: MaintenanceIntervalUnit.day,
        dueAt: DateTime(2026, 9, 6),
      );
      await tasks.complete(
        tankId: AppDatabase.defaultTankId,
        taskId: taskId,
        completedDate: DateTime(2026, 9, 7),
      );
      final result = calculateKhTitration(1, .49);
      await db
          .into(db.tankParameters)
          .insert(
            TankParametersCompanion.insert(
              tankId: AppDatabase.defaultTankId,
              parameterId: AppDatabase.khId,
              updatedAt: now.toUtc(),
            ),
          );
      await db
          .into(db.testRecords)
          .insert(
            TestRecordsCompanion.insert(
              id: 'kh-record',
              tankId: AppDatabase.defaultTankId,
              parameterId: AppDatabase.khId,
              confirmedMinValue: 8.2,
              khTitrationJson: Value(jsonEncode(result.toJson())),
              unit: 'dKH',
              measuredAt: now.toUtc(),
              createdAt: now.toUtc(),
              updatedAt: now.toUtc(),
            ),
          );
      final json = await LocalBackupService(db).exportJson();
      await LocalBackupService(restored).restoreReplace(json);
      final cycles = await restored.select(restored.maintenanceCycles).get();
      expect(cycles, hasLength(2));
      final second = cycles.singleWhere((c) => c.id == 'second');
      expect(second.previousCycleId, 'first');
      expect(second.addedStockMl, closeTo(160, 1e-8));
      expect(second.addedWaterMl, closeTo(40, 1e-8));
      expect(second.refillDeferredUntil, '2026-09-13');
      expect(second.notificationId, isNull);
      final task = await restored.select(restored.maintenanceTasks).getSingle();
      expect(
        rollingSchedule(task).completed.single.completedDate,
        '2026-09-07',
      );
      expect(rollingSchedule(task).nextDate, '2026-09-14');
      final record = await restored.select(restored.testRecords).getSingle();
      expect(record.confirmedMinValue, 8.2);
      expect(validateKhTitrationJson(record.khTitrationJson!).dkh, result.dkh);

      final broken = jsonDecode(json) as Map<String, dynamic>;
      broken['maintenanceCycles'][1]['effectPerMl'] = 2;
      await expectLater(
        LocalBackupService(restored).restoreReplace(jsonEncode(broken)),
        throwsFormatException,
      );
      expect(
        (await restored.select(restored.maintenanceCycles).get()),
        hasLength(2),
      );
      expect(
        (await restored.select(restored.testRecords).getSingle())
            .confirmedMinValue,
        8.2,
      );
      await LocalBackupService(restored).restoreMerge(json);
      expect(
        (await restored.select(restored.maintenanceCycles).get()),
        hasLength(2),
      );
    },
  );

  test(
    'legacy backup initialization preserves custom and disabled target states',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final restored = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      addTearDown(restored.close);
      final tanks = TankRepository(db);
      await db.select(db.tanks).get();
      await db
          .into(db.tankParameters)
          .insert(
            TankParametersCompanion.insert(
              tankId: AppDatabase.defaultTankId,
              parameterId: AppDatabase.khId,
              updatedAt: DateTime.now().toUtc(),
            ),
          );
      await tanks.setTarget(
        tankId: AppDatabase.defaultTankId,
        parameterId: AppDatabase.khId,
        minValue: 7.8,
        maxValue: 7.81,
      );
      final legacy =
          jsonDecode(await LocalBackupService(db).exportJson())
              as Map<String, dynamic>;
      legacy['formatVersion'] = 10;
      legacy.remove('maintenanceCycles');
      legacy['appPreferences'][0].remove('khTargetDefaultsApplied');
      await LocalBackupService(restored).restoreReplace(jsonEncode(legacy));
      final target = await restored
          .select(restored.waterQualityTargets)
          .getSingle();
      expect([target.minValue, target.maxValue], [7.8, 7.81]);
      expect(
        (await restored.select(restored.appPreferences).getSingle())
            .khTargetDefaultsApplied,
        isTrue,
      );
    },
  );
}
