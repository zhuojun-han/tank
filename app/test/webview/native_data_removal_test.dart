import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/aquarium/domain/fish_stock.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_cycle.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_dosing.dart';
import 'package:lanjiao_water_quality/features/calculators/data/maintenance_cycle_repository.dart';
import 'package:lanjiao_water_quality/features/test_timer/application/test_workflow_controller.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_notification_coordinator.dart';
import 'package:lanjiao_water_quality/webview/native_data_removal.dart';
import 'package:lanjiao_water_quality/webview/native_state_store.dart';

Future<void> seed(AppDatabase db) async {
  final now = DateTime.utc(2026, 9, 12);
  for (final id in ['a', 'b']) {
    await db
        .into(db.tanks)
        .insert(
          TanksCompanion.insert(
            id: id,
            name: id,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.tankParameters)
        .insert(
          TankParametersCompanion.insert(
            tankId: id,
            parameterId: AppDatabase.no3Id,
            updatedAt: now,
          ),
        );
    await db
        .into(db.waterQualityTargets)
        .insert(
          WaterQualityTargetsCompanion.insert(
            id: id,
            tankId: id,
            parameterId: AppDatabase.no3Id,
            unit: 'mg/L',
            updatedAt: now,
          ),
        );
    await db
        .into(db.testRecords)
        .insert(
          TestRecordsCompanion.insert(
            id: id,
            tankId: id,
            parameterId: AppDatabase.no3Id,
            confirmedMinValue: 10,
            unit: 'mg/L',
            measuredAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.maintenanceTasks)
        .insert(
          MaintenanceTasksCompanion.insert(
            id: id,
            tankId: id,
            title: '维护',
            intervalAmount: 7,
            intervalUnit: 'day',
            dueAt: now,
            notificationId: Value(id == 'a' ? 0x10000001 : 0x10000002),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.taskEvents)
        .insert(
          TaskEventsCompanion.insert(
            id: id,
            taskId: id,
            type: 'snoozed',
            occurredAt: now,
            snoozedUntil: Value(now.add(const Duration(hours: 1))),
            note: const Value('webview-reminder-only'),
          ),
        );
    await db
        .into(db.testTimerDefaults)
        .insert(
          TestTimerDefaultsCompanion.insert(
            tankId: id,
            parameterId: AppDatabase.no3Id,
            durationSeconds: 180,
            updatedAt: now,
          ),
        );
    await db
        .into(db.activeTestSessions)
        .insert(
          ActiveTestSessionsCompanion.insert(
            id: id,
            tankId: id,
            parameterId: AppDatabase.no3Id,
            startedAt: now,
            timerDurationSeconds: 180,
            stage: 'timerRunning',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await MaintenanceCycleRepository(db, now: () => now).confirm(
      prepareMaintenanceCycle(
        id: id,
        tankId: id,
        chemical: DosingChemical.po4,
        startDate: '2026-09-12',
        input: const MaintenanceDosingInput(dailyChange: .02),
      ),
    );
  }
  await db
      .update(db.appPreferences)
      .write(
        AppPreferencesCompanion(
          currentTankId: const Value('a'),
          fishStockJson: Value(
            FishStockCodec.encode([
              for (final id in ['a', 'b'])
                FishStockItem(
                  id: id,
                  tankId: id,
                  species: '小丑鱼',
                  quantity: 1,
                  introducedOn: now,
                  artworkKind: FishArtworkKind.builtinClownfish,
                ),
            ]),
          ),
        ),
      );
}

void main() {
  test(
    'delete is atomic, scoped, cancels owned reminders and survives restart',
    () async {
      final dir = await Directory.systemTemp.createTemp('lanjiao-removal-');
      final file = File('${dir.path}/test.sqlite');
      var db = AppDatabase(NativeDatabase(file), seedDefaultTank: false);
      try {
        await seed(db);
        final before = await NativeStateStore(db).readState();
        final params = {
          'confirmed': true,
          'tankId': 'a',
          'expectedRevision': before['revision'],
        };
        await expectLater(
          NativeDataRemoval(
            db,
          ).execute({...params, 'confirmed': false}, reset: false),
          throwsFormatException,
        );
        await expectLater(
          NativeDataRemoval(
            db,
          ).execute({...params, 'expectedRevision': -1}, reset: false),
          throwsFormatException,
        );
        await db.customStatement(
          "CREATE TRIGGER reject_removal BEFORE DELETE ON tanks BEGIN SELECT RAISE(ABORT, 'test rollback'); END",
        );
        await expectLater(
          NativeDataRemoval(db).execute(params, reset: false),
          throwsA(isA<Exception>()),
        );
        expect(await NativeStateStore(db).readState(), before);
        await db.customStatement('DROP TRIGGER reject_removal');
        final ids = await NativeDataRemoval(db).execute(params, reset: false);
        expect(
          ids,
          containsAll([
            0x10000001,
            maintenanceDailyNotificationId(0x10000001),
            testTimerNotificationId('a'),
          ]),
        );
        expect(ids, isNot(contains(0x10000002)));
        await db.close();
        db = AppDatabase(NativeDatabase(file), seedDefaultTank: false);
        final after = (await NativeStateStore(db).readState())['state'] as Map;
        expect(after['tankId'], 'b');
        for (final key in [
          'tanks',
          'records',
          'tasks',
          'maintenanceCycles',
          'fishStock',
        ]) {
          expect((after[key] as List).single['id'], 'b');
        }
        expect((await db.select(db.taskEvents).get()).single.taskId, 'b');
        expect(
          (await db.select(db.activeTestSessions).get()).single.tankId,
          'b',
        );
        expect(
          (await db.select(db.testTimerDefaults).get()).single.tankId,
          'b',
        );
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        final last = await NativeStateStore(db).readState();
        await NativeDataRemoval(db).execute({
          'confirmed': true,
          'tankId': 'b',
          'expectedRevision': last['revision'],
        }, reset: false);
        expect(
          (await NativeStateStore(db).readState())['state']['tanks'],
          isEmpty,
        );
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'reset removes every user table and restores only the built-in catalog',
    () async {
      final db = AppDatabase(NativeDatabase.memory(), seedDefaultTank: false);
      try {
        await seed(db);
        final snapshot = await NativeStateStore(db).readState();
        await db.customStatement(
          "CREATE TRIGGER reject_reset BEFORE DELETE ON tanks BEGIN SELECT RAISE(ABORT, 'test rollback'); END",
        );
        final params = {
          'confirmed': true,
          'expectedRevision': snapshot['revision'],
        };
        await expectLater(
          NativeDataRemoval(db).execute(params, reset: true),
          throwsA(isA<Exception>()),
        );
        expect(await NativeStateStore(db).readState(), snapshot);
        await db.customStatement('DROP TRIGGER reject_reset');
        await NativeDataRemoval(db).execute(params, reset: true);
        final state = (await NativeStateStore(db).readState())['state'] as Map;
        for (final key in [
          'tanks',
          'records',
          'tasks',
          'maintenanceCycles',
          'fishStock',
          'targets',
        ]) {
          expect(state[key], isEmpty);
        }
        expect(state['tankId'], '');
        expect(await db.select(db.taskEvents).get(), isEmpty);
        expect(await db.select(db.activeTestSessions).get(), isEmpty);
        expect(await db.select(db.testTimerDefaults).get(), isEmpty);
        expect(
          (await db.select(db.waterParameters).get()).every((p) => p.isBuiltIn),
          isTrue,
        );
        expect(state['parameters'], hasLength(6));
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await db.close();
      }
    },
  );
}
