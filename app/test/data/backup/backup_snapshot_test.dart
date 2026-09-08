import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/data/backup/local_backup_service.dart';

class _PauseSnapshot extends QueryInterceptor {
  bool armed = false;
  final readTanks = Completer<void>(), resume = Completer<void>();
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final rows = await executor.runSelect(statement, args);
    if (armed && statement.contains('FROM "tanks"')) {
      armed = false;
      readTanks.complete();
      await resume.future;
    }
    return rows;
  }
}

void main() {
  test(
    'export holds one snapshot while an independent parent/child write is pending',
    () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final gate = _PauseSnapshot();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(gate));
      final restored = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      addTearDown(restored.close);
      await db.select(db.tanks).get();
      gate.armed = true;
      final exporting = LocalBackupService(db).exportJson();
      await gate.readTanks.future;
      var committed = false;
      final now = DateTime.utc(2026, 9, 8);
      final writer = db.transaction(() async {
        await db
            .into(db.tanks)
            .insert(
              TanksCompanion.insert(
                id: 'new-tank',
                name: 'concurrent',
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.testRecords)
            .insert(
              TestRecordsCompanion.insert(
                id: 'new-record',
                tankId: 'new-tank',
                parameterId: AppDatabase.no3Id,
                confirmedMinValue: 7,
                unit: 'mg/L',
                measuredAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );
        committed = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(committed, isFalse);
      gate.resume.complete();
      final snapshot = await exporting;
      await writer;
      final data = jsonDecode(snapshot) as Map;
      expect(
        (data['tanks'] as List).any((r) => r['id'] == 'new-tank'),
        isFalse,
      );
      expect(
        (data['testRecords'] as List).any((r) => r['id'] == 'new-record'),
        isFalse,
      );
      await LocalBackupService(restored).restoreReplace(snapshot);
      expect(await restored.select(restored.testRecords).get(), isEmpty);
      expect(await db.select(db.testRecords).get(), hasLength(1));
    },
  );
}
