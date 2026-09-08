import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/data/backup/local_backup_service.dart';
import 'package:lanjiao_water_quality/features/test_records/data/test_record_repository.dart';
import 'package:lanjiao_water_quality/features/test_timer/data/test_session_repository.dart';

void main() {
  test(
    'schema9 upgrade preserves range/history and enables existing PO4',
    () async {
      final dir = Directory.systemTemp.createTempSync('v10-sync-');
      final file = File('${dir.path}/db.sqlite');
      final old = AppDatabase(NativeDatabase(file));
      await TestRecordRepository(old).createManual(
        tankId: AppDatabase.defaultTankId,
        parameterId: AppDatabase.no3Id,
        confirmedMinValue: 10,
        confirmedMaxValue: 25,
        measuredAt: DateTime.utc(2026, 9, 1),
      );
      await old.customStatement(
        "UPDATE water_parameters SET photo_supported=0 WHERE code='PO4'",
      );
      for (final column in [
        'confirmed_interpolation',
        'estimated_interpolation',
      ]) {
        await old.customStatement(
          'ALTER TABLE test_records DROP COLUMN $column',
        );
      }
      for (final column in [
        'draft_confirmed_interpolation',
        'draft_estimated_interpolation',
      ]) {
        await old.customStatement(
          'ALTER TABLE active_test_sessions DROP COLUMN $column',
        );
      }
      await old.customStatement('PRAGMA user_version=9');
      await old.close();
      final db = AppDatabase(NativeDatabase(file));
      try {
        final record = await db.select(db.testRecords).getSingle();
        expect(record.confirmedMinValue, 10);
        expect(record.confirmedMaxValue, 25);
        expect(record.confirmedInterpolation, isNull);
        final po4 = await (db.select(
          db.waterParameters,
        )..where((p) => p.code.equals('PO4'))).getSingle();
        expect(po4.photoSupported, isTrue);
      } finally {
        await db.close();
        dir.deleteSync(recursive: true);
      }
    },
  );
  test(
    'PO4 decimal interpolation survives review, editing and backup; original estimate stays unchanged',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final restored = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      addTearDown(restored.close);
      final sessions = TestSessionRepository(db);
      final id = await sessions.createDraft(
        tankId: AppDatabase.defaultTankId,
        parameterId: AppDatabase.po4Id,
      );
      await sessions.updateReviewDraft(
        tankId: AppDatabase.defaultTankId,
        sessionId: id,
        estimatedMinValue: .03,
        estimatedMaxValue: .1,
        estimatedInterpolation: .067,
        confirmedMinValue: .03,
        confirmedMaxValue: .1,
        confirmedInterpolation: .067,
        estimationMethod: 'lab-segment-linear-uncalibrated',
      );
      final recordId = await sessions.saveDraftAsRecord(
        tankId: AppDatabase.defaultTankId,
        sessionId: id,
        confirmedMinValue: .03,
        confirmedMaxValue: .1,
        confirmedInterpolation: .067,
      );
      final repo = TestRecordRepository(db);
      await repo.updateConfirmed(
        id: recordId,
        tankId: AppDatabase.defaultTankId,
        confirmedMinValue: .03,
        confirmedMaxValue: .1,
        confirmedInterpolation: .08,
        measuredAt: DateTime.now(),
      );
      final backup = await LocalBackupService(db).exportJson();
      await LocalBackupService(restored).restoreReplace(backup);
      final record = await restored.select(restored.testRecords).getSingle();
      expect(record.confirmedInterpolation, .08);
      expect(record.estimatedInterpolation, .067);
      expect(record.photoPath, isNull);
      await expectLater(
        repo.updateConfirmed(
          id: recordId,
          tankId: AppDatabase.defaultTankId,
          confirmedMinValue: .03,
          confirmedMaxValue: .1,
          confirmedInterpolation: 0,
          measuredAt: DateTime.now(),
        ),
        throwsArgumentError,
      );
      final corrupt = jsonDecode(backup) as Map<String, dynamic>;
      corrupt['testRecords'][0]['confirmedInterpolation'] = 99;
      await expectLater(
        LocalBackupService(restored).validateJson(jsonEncode(corrupt)),
        throwsFormatException,
      );
    },
  );
}
