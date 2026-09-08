import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/backup/local_backup_service.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('同 ID 异内容会重映射整条父子关系且不覆盖或错绑本地数据', () async {
    final source = AppDatabase(NativeDatabase.memory());
    final destination = AppDatabase(NativeDatabase.memory());
    addTearDown(source.close);
    addTearDown(destination.close);
    final time = DateTime.utc(2026, 8, 13, 1, 2, 3);

    await source.batch((batch) {
      batch.insert(
        source.tanks,
        Tank(
          id: 'collision-tank',
          name: '备份海缸',
          notes: '来自备份',
          isArchived: false,
          createdAt: time,
          updatedAt: time,
        ),
      );
      batch.insert(
        source.tankParameters,
        TankParameter(
          tankId: 'collision-tank',
          parameterId: AppDatabase.no3Id,
          isEnabled: true,
          updatedAt: time,
        ),
      );
      batch.insert(
        source.waterQualityTargets,
        WaterQualityTarget(
          id: 'collision-target',
          tankId: 'collision-tank',
          parameterId: AppDatabase.no3Id,
          minValue: 1,
          maxValue: 5,
          unit: 'mg/L',
          updatedAt: time,
        ),
      );
      batch.insert(
        source.testRecords,
        _record(
          id: 'collision-record',
          tankId: 'collision-tank',
          value: 5,
          time: time,
        ),
      );
      batch.insert(
        source.maintenanceTasks,
        _task(
          id: 'collision-task',
          tankId: 'collision-tank',
          title: '备份换水',
          time: time,
        ),
      );
      batch.insert(
        source.taskEvents,
        TaskEvent(
          id: 'collision-event',
          taskId: 'collision-task',
          type: 'completed',
          occurredAt: time,
          snoozedUntil: null,
          note: '备份事件',
        ),
      );
    });

    await destination.batch((batch) {
      batch.insert(
        destination.tanks,
        Tank(
          id: 'collision-tank',
          name: '本地海缸',
          notes: '必须保留',
          isArchived: false,
          createdAt: time,
          updatedAt: time,
        ),
      );
      batch.insert(
        destination.waterQualityTargets,
        WaterQualityTarget(
          id: 'collision-target',
          tankId: AppDatabase.defaultTankId,
          parameterId: AppDatabase.no3Id,
          minValue: 2,
          maxValue: 4,
          unit: 'mg/L',
          updatedAt: time,
        ),
      );
      batch.insert(
        destination.testRecords,
        _record(
          id: 'collision-record',
          tankId: AppDatabase.defaultTankId,
          value: 99,
          time: time,
        ),
      );
      batch.insert(
        destination.maintenanceTasks,
        _task(
          id: 'collision-task',
          tankId: AppDatabase.defaultTankId,
          title: '本地换水',
          time: time,
        ),
      );
      batch.insert(
        destination.taskEvents,
        TaskEvent(
          id: 'collision-event',
          taskId: 'collision-task',
          type: 'completed',
          occurredAt: time,
          snoozedUntil: null,
          note: '本地事件',
        ),
      );
    });

    var suffix = 0;
    final service = LocalBackupService(
      destination,
      idGenerator: () => 'restored-${suffix++}',
    );
    await service.restoreMerge(await LocalBackupService(source).exportJson());

    final tanks = await destination.select(destination.tanks).get();
    final localTank = tanks.singleWhere((item) => item.id == 'collision-tank');
    final importedTank = tanks.singleWhere((item) => item.name == '备份海缸');
    expect(localTank.name, '本地海缸');
    expect(importedTank.id, isNot('collision-tank'));

    final records = await destination.select(destination.testRecords).get();
    final localRecord = records.singleWhere(
      (item) => item.id == 'collision-record',
    );
    final importedRecord = records.singleWhere(
      (item) => item.confirmedMinValue == 5,
    );
    expect(localRecord.confirmedMinValue, 99);
    expect(importedRecord.id, isNot('collision-record'));
    expect(importedRecord.tankId, importedTank.id);

    final targets = await destination
        .select(destination.waterQualityTargets)
        .get();
    final importedTarget = targets.singleWhere(
      (item) => item.tankId == importedTank.id,
    );
    expect(importedTarget.id, isNot('collision-target'));

    final tasks = await destination.select(destination.maintenanceTasks).get();
    final importedTask = tasks.singleWhere((item) => item.title == '备份换水');
    expect(importedTask.id, isNot('collision-task'));
    expect(importedTask.tankId, importedTank.id);
    final events = await destination.select(destination.taskEvents).get();
    final importedEvent = events.singleWhere((item) => item.note == '备份事件');
    expect(importedEvent.id, isNot('collision-event'));
    expect(importedEvent.taskId, importedTask.id);
  });

  test('导出的 Unix 毫秒时间以 UTC 恢复并保留 v7 草稿确认时间', () async {
    final source = AppDatabase(NativeDatabase.memory());
    final destination = AppDatabase(NativeDatabase.memory());
    addTearDown(source.close);
    addTearDown(destination.close);
    final confirmedAt = DateTime.utc(2026, 8, 13, 2, 30, 45);
    final createdAt = DateTime.utc(2026, 8, 13, 2);

    await source
        .into(source.activeTestSessions)
        .insert(
          ActiveTestSessionsCompanion.insert(
            id: 'utc-session',
            tankId: AppDatabase.defaultTankId,
            parameterId: AppDatabase.no3Id,
            startedAt: createdAt,
            timerDurationSeconds: 300,
            draftConfirmedMinValue: const Value(10),
            draftConfirmedAt: Value(confirmedAt),
            stage: 'review',
            createdAt: createdAt,
            updatedAt: confirmedAt,
          ),
        );

    final json = await LocalBackupService(source).exportJson();
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final session =
        (decoded['activeTestSessions'] as List).single as Map<String, dynamic>;
    expect(session['draftConfirmedAt'], confirmedAt.millisecondsSinceEpoch);

    await LocalBackupService(destination).restoreMerge(json);
    final restored = await destination
        .select(destination.activeTestSessions)
        .getSingle();
    // Drift's SQLite adapter materializes DateTime in the device zone. The
    // persisted instant and the backup wire representation must remain UTC.
    expect(restored.draftConfirmedAt!.toUtc(), confirmedAt);
    final reExported =
        jsonDecode(await LocalBackupService(destination).exportJson())
            as Map<String, dynamic>;
    final reExportedSession =
        (reExported['activeTestSessions'] as List).single
            as Map<String, dynamic>;
    expect(
      reExportedSession['draftConfirmedAt'],
      confirmedAt.millisecondsSinceEpoch,
    );
  });
}

TestRecord _record({
  required String id,
  required String tankId,
  required double value,
  required DateTime time,
}) {
  return TestRecord(
    id: id,
    tankId: tankId,
    parameterId: AppDatabase.no3Id,
    reagentProfileId: null,
    capturedAt: null,
    estimatedMinValue: null,
    estimatedMaxValue: null,
    estimationMethod: null,
    estimationVersion: null,
    qualityScore: null,
    confidence: null,
    failureReason: null,
    confirmedMinValue: value,
    confirmedMaxValue: null,
    unit: 'mg/L',
    measuredAt: time,
    confirmedAt: time,
    notes: null,
    photoPath: null,
    wasManuallyEdited: false,
    createdAt: time,
    updatedAt: time,
  );
}

MaintenanceTask _task({
  required String id,
  required String tankId,
  required String title,
  required DateTime time,
}) {
  return MaintenanceTask(
    isOneOff: false,
    id: id,
    tankId: tankId,
    title: title,
    notes: null,
    intervalAmount: 7,
    intervalUnit: 'day',
    dueAt: time.add(const Duration(days: 7)),
    preferredReminderTime: '09:00',
    status: 'enabled',
    notificationId: null,
    createdAt: time,
    updatedAt: time,
  );
}
