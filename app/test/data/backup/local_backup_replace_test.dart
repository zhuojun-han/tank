import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/backup/local_backup_service.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/maintenance/data/maintenance_repository.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';
import 'package:lanjiao_water_quality/features/test_timer/data/test_session_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('v7 数据快照覆盖全部 11 张业务表并以备份状态权威恢复', () async {
    final source = AppDatabase(NativeDatabase.memory());
    final destination = AppDatabase(NativeDatabase.memory());
    addTearDown(source.close);
    addTearDown(destination.close);
    final now = DateTime.utc(2026, 8, 24, 1, 2, 3);
    final tanks = TankRepository(source);

    final secondTankId = await tanks.createTank(name: '迁移目标海缸', notes: '完整配置');
    final customParameterId = await tanks.createCustomParameter(
      tankId: secondTankId,
      code: 'SIO2',
      displayName: '硅酸盐',
      unit: 'mg/L',
    );
    await tanks.setParameterEnabled(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.po4Id,
      enabled: false,
    );
    await tanks.setTarget(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
      minValue: 1,
      maxValue: 8,
    );
    await tanks.setTarget(
      tankId: secondTankId,
      parameterId: customParameterId,
      minValue: 0,
      maxValue: 0.5,
    );
    await tanks.switchTank(secondTankId);
    await tanks.setThemeMode('dark');

    await (source.update(
      source.reagentProfiles,
    )..where((row) => row.id.equals(AppDatabase.ealNo3ReagentId))).write(
      ReagentProfilesCompanion(
        cardVersion: const Value('迁移卡-v2'),
        defaultDevelopmentSeconds: const Value(420),
        updatedAt: Value(now),
      ),
    );

    await source
        .into(source.testRecords)
        .insert(
          TestRecordsCompanion.insert(
            id: 'trend-record',
            tankId: AppDatabase.defaultTankId,
            parameterId: AppDatabase.no3Id,
            confirmedMinValue: 7,
            unit: 'mg/L',
            measuredAt: now,
            confirmedAt: Value(now),
            photoPath: const Value('water_quality_photos/legacy-record.jpg'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final maintenance = MaintenanceRepository(source, now: () => now);
    final taskId = await maintenance.createTask(
      tankId: secondTankId,
      title: '同步滤棉维护',
      intervalAmount: 3,
      intervalUnit: MaintenanceIntervalUnit.day,
      dueAt: now.add(const Duration(days: 1)),
      preferredReminderTime: '08:30',
    );
    await maintenance.snooze(
      tankId: secondTankId,
      taskId: taskId,
      until: now.add(const Duration(days: 2)),
    );
    await (source.update(source.maintenanceTasks)
          ..where((row) => row.id.equals(taskId)))
        .write(const MaintenanceTasksCompanion(notificationId: Value(12345)));

    final sessions = TestSessionRepository(source, now: () => now);
    await sessions.setDefaultDurationSeconds(
      tankId: secondTankId,
      parameterId: AppDatabase.no3Id,
      durationSeconds: 480,
    );
    final sessionId = await sessions.createDraft(
      tankId: secondTankId,
      parameterId: AppDatabase.no3Id,
      reagentProfileId: AppDatabase.ealNo3ReagentId,
    );
    await sessions.updatePhoto(
      tankId: secondTankId,
      sessionId: sessionId,
      photoPath: 'water_quality_photos/legacy-draft.jpg',
    );
    await sessions.updateReviewDraft(
      tankId: secondTankId,
      sessionId: sessionId,
      confirmedMinValue: 5,
      confirmedAt: now,
      notes: '可恢复草稿数值',
    );

    final service = LocalBackupService(source);
    final sourceJson = await service.exportJson();
    final sourceMap = jsonDecode(sourceJson) as Map<String, dynamic>;
    expect(sourceMap['formatVersion'], 10);
    expect(
      sourceMap.keys.toSet(),
      containsAll(<String>{
        'tanks',
        'waterParameters',
        'tankParameters',
        'waterQualityTargets',
        'reagentProfiles',
        'appPreferences',
        'testRecords',
        'maintenanceTasks',
        'taskEvents',
        'testTimerDefaults',
        'activeTestSessions',
      }),
    );
    expect(
      ((sourceMap['testRecords'] as List).single
          as Map<String, dynamic>)['photoPath'],
      isNull,
    );
    expect(
      ((sourceMap['activeTestSessions'] as List).single
          as Map<String, dynamic>)['draftPhotoPath'],
      isNull,
    );
    expect(
      ((sourceMap['maintenanceTasks'] as List).single
          as Map<String, dynamic>)['notificationId'],
      isNull,
    );

    final localOnlyTankId = await TankRepository(
      destination,
    ).createTank(name: '必须被快照替换的本机海缸');
    final result = await LocalBackupService(
      destination,
    ).restoreReplace(sourceJson);
    expect(result.insertedTankCount, 2);
    expect(result.insertedRecordCount, 1);
    expect(result.insertedTaskCount, 1);
    expect(result.photoTransfers, isEmpty);
    expect(
      await (destination.select(
        destination.tanks,
      )..where((row) => row.id.equals(localOnlyTankId))).getSingleOrNull(),
      isNull,
    );

    final restoredMap =
        jsonDecode(await LocalBackupService(destination).exportJson())
            as Map<String, dynamic>;
    expect(_withoutExportTime(restoredMap), _withoutExportTime(sourceMap));

    final restoredPreference = await destination
        .select(destination.appPreferences)
        .getSingle();
    expect(restoredPreference.currentTankId, secondTankId);
    expect(restoredPreference.themeMode, 'dark');
    final restoredPo4 =
        await (destination.select(destination.tankParameters)..where(
              (row) =>
                  row.tankId.equals(AppDatabase.defaultTankId) &
                  row.parameterId.equals(AppDatabase.po4Id),
            ))
            .getSingle();
    expect(restoredPo4.isEnabled, isFalse);
    expect(
      (await destination.select(destination.testRecords).getSingle()).photoPath,
      isNull,
    );
    expect(
      (await destination.select(destination.activeTestSessions).getSingle())
          .draftPhotoPath,
      isNull,
    );
    expect(
      (await destination.select(destination.maintenanceTasks).getSingle())
          .notificationId,
      isNull,
    );
  });

  test('旧 v5 JSON 的照片引用会被验证但恢复时剥离', () async {
    final source = AppDatabase(NativeDatabase.memory());
    final destination = AppDatabase(NativeDatabase.memory());
    addTearDown(source.close);
    addTearDown(destination.close);
    final now = DateTime.utc(2026, 8, 24, 2);
    await source
        .into(source.testRecords)
        .insert(
          TestRecordsCompanion.insert(
            id: 'legacy-photo-record',
            tankId: AppDatabase.defaultTankId,
            parameterId: AppDatabase.no3Id,
            confirmedMinValue: 10,
            unit: 'mg/L',
            measuredAt: now,
            photoPath: const Value('water_quality_photos/old.jpg'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final sessionId = await TestSessionRepository(source).createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
    );
    await TestSessionRepository(source).updatePhoto(
      tankId: AppDatabase.defaultTankId,
      sessionId: sessionId,
      photoPath: 'water_quality_photos/old-draft.jpg',
    );

    final legacy =
        jsonDecode(await LocalBackupService(source).exportJson())
            as Map<String, dynamic>;
    legacy['formatVersion'] = 5;
    ((legacy['testRecords'] as List).single
            as Map<String, dynamic>)['photoPath'] =
        'water_quality_photos/old.jpg';
    ((legacy['activeTestSessions'] as List).single
            as Map<String, dynamic>)['draftPhotoPath'] =
        'water_quality_photos/old-draft.jpg';

    await LocalBackupService(destination).restoreReplace(jsonEncode(legacy));

    expect(
      (await destination.select(destination.testRecords).getSingle()).photoPath,
      isNull,
    );
    expect(
      (await destination.select(destination.activeTestSessions).getSingle())
          .draftPhotoPath,
      isNull,
    );
  });
}

Map<String, dynamic> _withoutExportTime(Map<String, dynamic> source) {
  return Map<String, dynamic>.from(source)..remove('exportedAt');
}
