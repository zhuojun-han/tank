import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/backup/local_backup_service.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/maintenance/data/maintenance_repository.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';

Map<String, dynamic> legacySnapshot(String source) {
  final data = jsonDecode(source) as Map<String, dynamic>;
  data.remove('exportedAt');
  data.remove('formatVersion');
  for (final tank in data['tanks'] as List) {
    (tank as Map).remove('startedOn');
    tank.remove('volumeLiters');
  }
  return data;
}

void main() {
  test(
    'v11 migration adds only nullable tank metadata and preserves the complete existing snapshot',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'tank-v12-migration-',
      );
      final file = File('${directory.path}/db.sqlite');
      final old = AppDatabase(NativeDatabase(file));
      final second = await TankRepository(
        old,
      ).createTank(name: '历史第二缸', notes: '必须保留');
      final now = DateTime.utc(2026, 9, 8, 1);
      await old
          .into(old.testRecords)
          .insert(
            TestRecordsCompanion.insert(
              id: 'historical-record',
              tankId: second,
              parameterId: AppDatabase.no3Id,
              confirmedMinValue: 5,
              confirmedMaxValue: const Value(10),
              confirmedInterpolation: const Value(7),
              unit: 'mg/L',
              measuredAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await MaintenanceRepository(old, now: () => now).createTask(
        tankId: second,
        title: '原维护',
        intervalAmount: 7,
        intervalUnit: MaintenanceIntervalUnit.day,
        dueAt: now,
      );
      await TankRepository(old).setTarget(
        tankId: second,
        parameterId: AppDatabase.no3Id,
        minValue: 2,
        maxValue: 10,
      );
      final before = legacySnapshot(await LocalBackupService(old).exportJson());
      await old.customStatement('ALTER TABLE tanks DROP COLUMN started_on');
      await old.customStatement('ALTER TABLE tanks DROP COLUMN volume_liters');
      await old.customStatement('PRAGMA user_version=11');
      await old.close();
      final upgraded = AppDatabase(NativeDatabase(file));
      try {
        final tanks = await upgraded.select(upgraded.tanks).get();
        expect(tanks, hasLength(2));
        expect(
          tanks.every((t) => t.startedOn == null && t.volumeLiters == null),
          isTrue,
        );
        expect(
          (await upgraded.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          12,
        );
        expect(
          legacySnapshot(await LocalBackupService(upgraded).exportJson()),
          before,
        );
        await TankRepository(upgraded).updateTank(
          tankId: second,
          name: '历史第二缸',
          notes: '必须保留',
          startedOn: const Value('2020-02-29'),
          volumeLiters: const Value(120),
        );
      } finally {
        await upgraded.close();
      }
      final reopened = AppDatabase(NativeDatabase(file));
      try {
        final tank = await (reopened.select(
          reopened.tanks,
        )..where((t) => t.id.equals(second))).getSingle();
        expect(tank.startedOn, '2020-02-29');
        expect(tank.volumeLiters, 120);
        expect(
          legacySnapshot(
            await LocalBackupService(reopened).exportJson(),
          )['testRecords'],
          before['testRecords'],
        );
      } finally {
        await reopened.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
