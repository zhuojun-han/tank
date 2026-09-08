import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/backup/local_backup_service.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase source;
  late AppDatabase destination;
  setUp(() {
    source = AppDatabase(NativeDatabase.memory());
    destination = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await source.close();
    await destination.close();
  });

  test(
    'v12 round trip preserves per-tank dates and volume, including a valid date after clock rollback',
    () async {
      final second = await TankRepository(
        source,
      ).createTank(name: '有日期缸', startedOn: '2000-02-29', volumeLiters: 120.5);
      final future = await TankRepository(source).createTank(name: '设备回拨缸');
      await (source.update(source.tanks)..where((t) => t.id.equals(future)))
          .write(const TanksCompanion(startedOn: Value('9999-12-31')));
      final data = await LocalBackupService(source).exportJson();
      expect((jsonDecode(data) as Map)['formatVersion'], 12);
      await LocalBackupService(destination).restoreReplace(data);
      final tanks = {
        for (final tank in await destination.select(destination.tanks).get())
          tank.id: tank,
      };
      expect(tanks[AppDatabase.defaultTankId]!.startedOn, isNull);
      expect(tanks[AppDatabase.defaultTankId]!.volumeLiters, isNull);
      expect(tanks[second]!.startedOn, '2000-02-29');
      expect(tanks[second]!.volumeLiters, 120.5);
      expect(tanks[future]!.startedOn, '9999-12-31');
    },
  );

  test(
    'v11 missing fields restores as unset without inferring from timestamps',
    () async {
      final data =
          jsonDecode(await LocalBackupService(source).exportJson())
              as Map<String, dynamic>;
      data['formatVersion'] = 11;
      for (final tank in data['tanks'] as List) {
        (tank as Map).remove('startedOn');
        tank.remove('volumeLiters');
      }
      await TankRepository(destination).updateTank(
        tankId: AppDatabase.defaultTankId,
        name: '旧本机',
        startedOn: const Value('2000-01-01'),
        volumeLiters: const Value(99),
      );
      await LocalBackupService(destination).restoreReplace(jsonEncode(data));
      final tank = await destination.select(destination.tanks).getSingle();
      expect(tank.startedOn, isNull);
      expect(tank.volumeLiters, isNull);
      expect(tank.createdAt, isNotNull);
    },
  );

  test(
    'invalid calendar or volume is rejected before replace and merge write anything',
    () async {
      await TankRepository(
        destination,
      ).createTank(name: '不能丢的本机缸', startedOn: '2000-01-01');
      final before = await destination.select(destination.tanks).get();
      final sourceJson = await LocalBackupService(source).exportJson();
      for (final change in <(String, Object)>[
        ('startedOn', '2026-02-30'),
        ('startedOn', '2026-1-01'),
        ('startedOn', '2026-09-08T00:00:00Z'),
        ('startedOn', 20260908),
        ('volumeLiters', 0),
        ('volumeLiters', -3),
        ('volumeLiters', '120 L'),
      ]) {
        final data = jsonDecode(sourceJson) as Map<String, dynamic>;
        ((data['tanks'] as List).first as Map)[change.$1] = change.$2;
        final invalid = jsonEncode(data);
        await expectLater(
          LocalBackupService(destination).restoreReplace(invalid),
          throwsFormatException,
        );
        await expectLater(
          LocalBackupService(destination).restoreMerge(invalid),
          throwsFormatException,
        );
        expect(await destination.select(destination.tanks).get(), before);
      }
    },
  );

  test(
    'empty archived date normalizes to unset for both compatible versions',
    () async {
      final sourceJson = await LocalBackupService(source).exportJson();
      for (final version in [11, 12]) {
        final data = jsonDecode(sourceJson) as Map<String, dynamic>;
        data['formatVersion'] = version;
        ((data['tanks'] as List).single as Map)['startedOn'] = '';
        await LocalBackupService(destination).restoreReplace(jsonEncode(data));
        expect(
          (await destination.select(destination.tanks).getSingle()).startedOn,
          isNull,
        );
      }
    },
  );

  test(
    'same tank id with differing metadata remaps its records instead of overwriting local tank',
    () async {
      final now = DateTime.utc(2026, 9, 8);
      await source
          .into(source.testRecords)
          .insert(
            TestRecordsCompanion.insert(
              id: 'source-record',
              tankId: AppDatabase.defaultTankId,
              parameterId: AppDatabase.no3Id,
              confirmedMinValue: 5,
              unit: 'mg/L',
              measuredAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await LocalBackupService(
        destination,
      ).restoreReplace(await LocalBackupService(source).exportJson());
      // All other tank fields remain identical, so the new metadata itself must
      // participate in merge conflict detection.
      await source
          .update(source.tanks)
          .write(
            const TanksCompanion(
              startedOn: Value('2000-01-01'),
              volumeLiters: Value(123.5),
            ),
          );
      await LocalBackupService(
        destination,
      ).restoreMerge(await LocalBackupService(source).exportJson());
      final tanks = await destination.select(destination.tanks).get();
      expect(tanks, hasLength(2));
      final original = tanks.singleWhere(
        (t) => t.id == AppDatabase.defaultTankId,
      );
      final imported = tanks.singleWhere(
        (t) => t.id != AppDatabase.defaultTankId,
      );
      expect(original.startedOn, isNull);
      expect(original.volumeLiters, isNull);
      expect(imported.startedOn, '2000-01-01');
      expect(imported.volumeLiters, 123.5);
      final records = await destination.select(destination.testRecords).get();
      expect(records, hasLength(2));
      expect(records.map((r) => r.tankId).toSet(), {original.id, imported.id});
    },
  );
}
