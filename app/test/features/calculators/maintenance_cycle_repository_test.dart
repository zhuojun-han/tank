import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/calculators/data/maintenance_cycle_repository.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_cycle.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_dosing.dart';

void main() {
  late AppDatabase db;
  late MaintenanceCycleRepository repo;
  var now = DateTime(2026, 9, 8, 12);
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 9, 8, 12);
    repo = MaintenanceCycleRepository(db, now: () => now);
    await db.select(db.tanks).get();
  });
  tearDown(() => db.close());

  MaintenanceCycle prepare(
    String id, {
    MaintenanceCycle? previous,
    String date = '2026-09-08',
    DosingChemical chemical = DosingChemical.po4,
    double retained = 0,
  }) => prepareMaintenanceCycle(
    input: MaintenanceDosingInput(
      dailyChange: chemical == DosingChemical.po4 ? 0.02 : 0.5,
    ),
    chemical: chemical,
    tankId: AppDatabase.defaultTankId,
    startDate: date,
    id: id,
    previous: previous,
    retainedMl: retained,
  );

  test(
    'preview writes nothing; confirmation persists precise snapshot without tasks/events',
    () async {
      final preview = prepare('first');
      expect(await repo.getCycles(), isEmpty);
      await repo.confirm(preview);
      final saved = (await repo.getCycles()).single;
      expect(saved.input.toJson(), preview.input.toJson());
      expect(saved.addedStockMl, preview.addedStockMl);
      expect(saved.refillDate, '2026-09-13');
      expect(await db.select(db.maintenanceTasks).get(), isEmpty);
      expect(await db.select(db.taskEvents).get(), isEmpty);
      await expectLater(repo.confirm(preview), throwsFormatException);
      expect(await repo.getCycles(), hasLength(1));
    },
  );

  test(
    'same reagent replacement atomically closes delayed old cycle, preserving KH',
    () async {
      final old = prepare('old');
      await repo.confirm(old);
      await repo.confirm(prepare('kh', chemical: DosingChemical.kh));
      await repo.delay('old', 2);
      now = DateTime(2026, 9, 10);
      await repo.confirm(
        prepare('new', previous: old, date: '2026-09-09', retained: 416),
      );
      final cycles = await repo.getCycles();
      final closed = cycles.singleWhere((c) => c.id == 'old');
      expect(closed.closedOnDate, '2026-09-09');
      expect(closed.refillDeferredUntil, '2026-09-15');
      expect(cycles.singleWhere((c) => c.id == 'kh').closedOnDate, isNull);
      expect(
        currentMaintenanceCycle(
          cycles,
          AppDatabase.defaultTankId,
          DosingChemical.po4,
        )!.id,
        'new',
      );
      await expectLater(
        repo.delay('old', 1, expectedDeferredUntil: closed.refillDeferredUntil),
        throwsFormatException,
      );
      final rows = maintenanceCycleOccurrences(
        cycles,
        tankId: AppDatabase.defaultTankId,
        start: DateTime(2026, 9, 15),
        days: 1,
        now: DateTime(2026, 9, 15),
      );
      expect(rows.any((o) => o.cycle.id == 'old'), isFalse);
    },
  );

  test(
    'stale competing confirmation and duplicate delay reject without partial writes',
    () async {
      final old = prepare('old');
      await repo.confirm(old);
      final competing = [
        prepare('a', previous: old),
        prepare('b', previous: old),
      ];
      final outcomes = await Future.wait(
        competing.map((c) async {
          try {
            await repo.confirm(c);
            return true;
          } on FormatException {
            return false;
          }
        }),
      );
      expect(outcomes.where((v) => v), hasLength(1));
      final cycles = await repo.getCycles();
      expect(cycles, hasLength(2));
      final current = currentMaintenanceCycle(
        cycles,
        AppDatabase.defaultTankId,
        DosingChemical.po4,
      )!;
      await repo.delay(current.id, 2);
      await expectLater(repo.delay(current.id, 2), throwsFormatException);
      expect(
        (await repo.getCycles())
            .singleWhere((c) => c.id == current.id)
            .refillDeferredUntil,
        '2026-09-15',
      );
    },
  );

  test(
    'future actual date and archived tank fail without replacing old cycle',
    () async {
      await expectLater(
        repo.confirm(prepare('future', date: '2026-09-09')),
        throwsFormatException,
      );
      expect(await repo.getCycles(), isEmpty);
      final original = prepare('first');
      await repo.confirm(original);
      now = DateTime(2026, 9, 9);
      await db.customStatement(
        'UPDATE tanks SET is_archived = 1 WHERE id = ?',
        [AppDatabase.defaultTankId],
      );
      await expectLater(
        repo.confirm(
          prepare('archived', previous: original, date: '2026-09-09'),
        ),
        throwsFormatException,
      );
      expect(await repo.getCycles(), hasLength(1));
    },
  );
}
