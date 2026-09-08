import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';
import 'package:lanjiao_water_quality/features/test_records/data/test_record_repository.dart';
import 'package:lanjiao_water_quality/features/test_timer/domain/kh_titration.dart';

void main() {
  test(
    'KH confirmed value is numeric one decimal; editing preserves original titration',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      try {
        final tanks = TankRepository(db), records = TestRecordRepository(db);
        await tanks.setParameterEnabled(
          tankId: AppDatabase.defaultTankId,
          parameterId: AppDatabase.khId,
          enabled: true,
        );
        final id = await records.createKhTitration(
          tankId: AppDatabase.defaultTankId,
          initialMl: 1,
          remainingMl: .48,
          measuredAt: DateTime.utc(2026, 9, 8),
        );
        var record = (await records.readById(
          tankId: AppDatabase.defaultTankId,
          id: id,
        ))!;
        expect(record.confirmedMinValue, 8);
        expect(record.confirmedMaxValue, isNull);
        final original = record.khTitrationJson;
        expect(validateKhTitrationJson(original!).displayDkh, '8.0');
        await records.updateConfirmed(
          id: id,
          tankId: record.tankId,
          confirmedMinValue: 8.1,
          measuredAt: record.measuredAt,
        );
        record = (await records.readById(tankId: record.tankId, id: id))!;
        expect(record.confirmedMinValue, 8.1);
        expect(record.khTitrationJson, original);
        expect(record.wasManuallyEdited, true);
        await expectLater(
          records.createKhTitration(
            tankId: record.tankId,
            initialMl: 1,
            remainingMl: 1,
            measuredAt: record.measuredAt,
          ),
          throwsFormatException,
        );
        expect(await db.select(db.testRecords).get(), hasLength(1));
      } finally {
        await db.close();
      }
    },
  );
  test(
    'first enable creates KH 7–9; disable and explicit clear preserve target and tank isolation',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      try {
        final tanks = TankRepository(db);
        final first = AppDatabase.defaultTankId;
        final second = await tanks.createTank(name: '第二缸');
        Future<void> enable(String id, bool enabled) =>
            tanks.setParameterEnabled(
              tankId: id,
              parameterId: AppDatabase.khId,
              enabled: enabled,
            );
        await enable(first, true);
        var target = await db.select(db.waterQualityTargets).getSingle();
        expect((target.minValue, target.maxValue), (7, 9));
        await tanks.setTarget(
          tankId: first,
          parameterId: AppDatabase.khId,
          minValue: 7.8,
          maxValue: 7.81,
        );
        await enable(first, false);
        await enable(first, true);
        target = await db.select(db.waterQualityTargets).getSingle();
        expect((target.minValue, target.maxValue), (7.8, 7.81));
        await tanks.setTarget(
          tankId: first,
          parameterId: AppDatabase.khId,
          minValue: null,
          maxValue: null,
        );
        await enable(first, false);
        await enable(first, true);
        await enable(second, true);
        final targets = await db.select(db.waterQualityTargets).get();
        expect(targets, hasLength(2));
        expect(targets.singleWhere((t) => t.tankId == first).minValue, isNull);
        expect(targets.singleWhere((t) => t.tankId == second).minValue, 7);
        await tanks.setTarget(
          tankId: first,
          parameterId: AppDatabase.khId,
          minValue: null,
          maxValue: 8,
        );
        expect(
          (await db.select(db.waterQualityTargets).get())
              .singleWhere((t) => t.tankId == first)
              .maxValue,
          8,
        );
      } finally {
        await db.close();
      }
    },
  );
}
