import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';

void main() {
  late AppDatabase db;
  late TankRepository repository;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = TankRepository(db);
  });
  tearDown(() => db.close());

  Future<Tank> read(String id) =>
      (db.select(db.tanks)..where((t) => t.id.equals(id))).getSingle();

  test('create only switches tanks when makeCurrent is requested', () async {
    await repository.createTank(name: '默认不切缸');
    expect(
      (await db.select(db.appPreferences).getSingle()).currentTankId,
      AppDatabase.defaultTankId,
    );
    final selected = await repository.createTank(
      name: '创建后进入',
      startedOn: '2000-01-01',
      volumeLiters: 120,
      makeCurrent: true,
    );
    expect(
      (await db.select(db.appPreferences).getSingle()).currentTankId,
      selected,
    );
    expect((await repository.watchCurrentTank().first)?.id, selected);
    expect(
      (await repository.readParameterStates(selected))
          .where((parameter) => parameter.isEnabled)
          .map((parameter) => parameter.parameter.id)
          .toSet(),
      {AppDatabase.no3Id, AppDatabase.po4Id},
    );
    await repository.createTank(name: '后续仍默认不切');
    expect(
      (await db.select(db.appPreferences).getSingle()).currentTankId,
      selected,
    );
  });

  test(
    'switch failure rolls back the new tank and its parameter rows',
    () async {
      final tanks = await db.select(db.tanks).get();
      final parameters = await db.select(db.tankParameters).get();
      final preferences = await db.select(db.appPreferences).get();
      await db.customStatement(
        'CREATE TRIGGER reject_current_tank_change '
        'BEFORE UPDATE OF current_tank_id ON app_preferences '
        "BEGIN SELECT RAISE(ABORT, 'test blocked switch'); END",
      );
      await expectLater(
        repository.createTank(name: '不能部分创建', makeCurrent: true),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains('test blocked switch'),
          ),
        ),
      );
      expect(await db.select(db.tanks).get(), tanks);
      expect(await db.select(db.tankParameters).get(), parameters);
      expect(await db.select(db.appPreferences).get(), preferences);
    },
  );

  test(
    'create/edit/omit/clear metadata stays scoped to the selected tank',
    () async {
      final first = await repository.createTank(
        name: '第一缸',
        notes: '原备注',
        startedOn: '2000-02-29',
        volumeLiters: 120.5,
      );
      final second = await repository.createTank(
        name: '第二缸',
        startedOn: '2001-01-01',
        volumeLiters: 60,
      );
      final originalSecond = await read(second);
      final parameters = await db.select(db.tankParameters).get();
      final preferences = await db.select(db.appPreferences).get();
      expect((await read(AppDatabase.defaultTankId)).startedOn, isNull);
      expect((await read(AppDatabase.defaultTankId)).volumeLiters, isNull);
      await repository.updateTank(tankId: first, name: '改名', notes: '改备注');
      expect((await read(first)).startedOn, '2000-02-29');
      expect((await read(first)).volumeLiters, 120.5);
      await repository.updateTank(
        tankId: first,
        name: '改名',
        notes: '改备注',
        startedOn: const Value('2002-03-04'),
        volumeLiters: const Value(250),
      );
      expect((await read(first)).startedOn, '2002-03-04');
      expect((await read(first)).volumeLiters, 250);
      await repository.updateTank(
        tankId: first,
        name: '改名',
        notes: '改备注',
        startedOn: const Value(null),
        volumeLiters: const Value(null),
      );
      expect((await read(first)).startedOn, isNull);
      expect((await read(first)).volumeLiters, isNull);
      await repository.updateTank(
        tankId: first,
        name: '改名',
        startedOn: const Value(''),
      );
      expect((await read(first)).startedOn, isNull);
      expect(await read(second), originalSecond);
      expect(await db.select(db.tankParameters).get(), parameters);
      expect(await db.select(db.appPreferences).get(), preferences);
    },
  );

  test(
    'invalid metadata fails before any write; omitted future archive date is preserved',
    () async {
      final id = await repository.createTank(
        name: '原缸',
        startedOn: '2000-01-01',
        volumeLiters: 100,
      );
      final before = await read(id);
      for (final invalid in ['2026-02-30', '9999-12-31']) {
        await expectLater(
          repository.updateTank(
            tankId: id,
            name: '不能写入',
            startedOn: Value(invalid),
          ),
          throwsFormatException,
        );
        await expectLater(
          repository.createTank(name: '不能创建', startedOn: invalid),
          throwsFormatException,
        );
      }
      for (final invalid in [0.0, -1.0, double.nan, double.infinity]) {
        await expectLater(
          repository.updateTank(
            tankId: id,
            name: '不能写入',
            volumeLiters: Value(invalid),
          ),
          throwsFormatException,
        );
        await expectLater(
          repository.createTank(name: '不能创建', volumeLiters: invalid),
          throwsFormatException,
        );
      }
      expect(await read(id), before);
      expect(await db.select(db.tanks).get(), hasLength(2));
      await (db.update(db.tanks)..where((t) => t.id.equals(id))).write(
        const TanksCompanion(startedOn: Value('9999-12-31')),
      );
      await repository.updateTank(tankId: id, name: '回拨后的备注修改', notes: '日期未改');
      expect((await read(id)).startedOn, '9999-12-31');
      expect((await read(id)).volumeLiters, 100);
    },
  );
}
