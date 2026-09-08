import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/maintenance/data/maintenance_repository.dart';

void main() {
  test('v8 文件升级到 v9 保留旧任务和事件，新字段为空不伪造日期', () async {
    final directory = await Directory.systemTemp.createTemp(
      'lanjiao-v8-migration-',
    );
    final file = File('${directory.path}/legacy.sqlite');
    final old = AppDatabase(NativeDatabase(file));
    final repository = MaintenanceRepository(old);
    final id = await repository.createTask(
      tankId: AppDatabase.defaultTankId,
      title: '旧周期',
      intervalAmount: 3,
      intervalUnit: MaintenanceIntervalUnit.day,
      dueAt: DateTime(2026, 9, 1),
    );
    await repository.complete(tankId: AppDatabase.defaultTankId, taskId: id);
    final due = (await old.select(old.maintenanceTasks).getSingle()).dueAt;
    await old.customStatement(
      'ALTER TABLE maintenance_tasks DROP COLUMN recurrence_json',
    );
    await old.customStatement('PRAGMA user_version = 8');
    await old.close();
    final upgraded = AppDatabase(NativeDatabase(file));
    try {
      final task = await upgraded.select(upgraded.maintenanceTasks).getSingle();
      expect(task.id, id);
      expect(task.dueAt, due);
      expect(task.recurrenceJson, isNull);
      expect(await upgraded.select(upgraded.taskEvents).get(), hasLength(1));
      expect(
        (await upgraded.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        11,
      );
    } finally {
      await upgraded.close();
      await directory.delete(recursive: true);
    }
  });
}
