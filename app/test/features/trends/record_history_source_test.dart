import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/trends/data/record_history_source.dart';
import 'package:lanjiao_water_quality/features/test_records/data/test_record_repository.dart';

void main() {
  late AppDatabase db;
  late DatabaseRecordHistorySource source;
  const scope = (
    tankId: AppDatabase.defaultTankId,
    parameterId: AppDatabase.no3Id,
  );
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    source = DatabaseRecordHistorySource(db);
    await db.select(db.tanks).get();
  });
  tearDown(() => db.close());
  Future<void> insert(
    int i, {
    bool point = true,
    String parameter = AppDatabase.no3Id,
  }) => db
      .into(db.testRecords)
      .insert(
        TestRecordsCompanion.insert(
          id: 'r${i.toString().padLeft(4, '0')}-$parameter',
          tankId: scope.tankId,
          parameterId: parameter,
          confirmedMinValue: 10,
          confirmedMaxValue: const Value(25),
          confirmedInterpolation: Value(point ? 18 : null),
          unit: 'mg/L',
          measuredAt: DateTime.utc(2026, 9, 8).add(Duration(minutes: i ~/ 2)),
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          notes: Value('record-$i'),
        ),
      )
      .then((_) {});

  test(
    'cursor pages are bounded, stable at timestamp ties and survive a deleted cursor',
    () async {
      for (var i = 0; i < 33; i++) {
        await insert(i);
      }
      await insert(100, parameter: AppDatabase.po4Id);
      final first = await source.readPage(scope);
      expect(first, hasLength(10));
      final allIds = first.map((r) => r.id).toSet();
      var cursor = first.last;
      await (db.delete(
        db.testRecords,
      )..where((r) => r.id.equals(cursor.id))).go();
      await insert(200); // A new head must not shift later cursor pages.
      while (true) {
        final page = await source.readPage(scope, after: cursor);
        if (page.isEmpty) break;
        expect(page.length, lessThanOrEqualTo(10));
        expect(page.every((r) => !allIds.contains(r.id)), isTrue);
        allIds.addAll(page.map((r) => r.id));
        cursor = page.last;
      }
      expect(allIds, hasLength(33));
      expect(allIds.any((id) => id.startsWith('r0200')), isFalse);
      final latest = await TestRecordRepository(
        db,
      ).watchLatestForTank(scope.tankId).first;
      expect(latest, hasLength(2));
      expect(
        latest.singleWhere((r) => r.parameterId == scope.parameterId).id,
        startsWith('r0200'),
      );
    },
  );

  test(
    'chart reads a visible window and both distant interpolation neighbors across nulls',
    () async {
      for (var i = 0; i < 61; i++) {
        await insert(i, point: i == 0 || i == 60);
      }
      final window = await source.readChartWindow(scope, 20, 10);
      expect(window.map((r) => r.index), [
        0,
        ...List.generate(10, (i) => i + 20),
        60,
      ]);
      expect(window, hasLength(12));
      final overview = await source.watchOverview(scope).first;
      expect(overview.count, 61);
      expect(overview.maximum, 25);
      expect(overview.pointMaximum, 18);
      expect((await source.readChartWindow(scope, 60, 10)).last.index, 60);
      expect(
        await source.readPage((
          tankId: 'absent',
          parameterId: scope.parameterId,
        )),
        isEmpty,
      );
    },
  );
}
