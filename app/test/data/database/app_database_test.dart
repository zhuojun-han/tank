import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/backup/local_backup_service.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/maintenance/data/maintenance_repository.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';
import 'package:lanjiao_water_quality/features/test_records/data/test_record_repository.dart';
import 'package:lanjiao_water_quality/features/test_timer/data/test_session_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase database;
  late TankRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = TankRepository(database);
  });

  tearDown(() => database.close());

  test('schema v8 事务性创建默认海缸、内置参数、试剂、偏好和阶段 4 表', () async {
    final tanks = await database.select(database.tanks).get();
    final parameters = await database.select(database.waterParameters).get();
    final enabled = await repository
        .watchEnabledParameters(AppDatabase.defaultTankId)
        .first;
    final reagents = await database.select(database.reagentProfiles).get();
    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();

    expect(version.read<int>('user_version'), 10);
    expect(tanks, hasLength(1));
    expect(tanks.single.name, '我的海缸');
    expect(
      parameters.map((item) => item.code),
      containsAll(['NO3', 'PO4', 'KH', 'CA', 'MG', 'K']),
    );
    expect(enabled.map((item) => item.code), ['NO3', 'PO4']);
    expect(reagents.single.brand, '益尔');
    expect(reagents.single.colorLevelsJson, '[0,1,5,10,25,50,100]');
    expect(
      (await database.select(database.appPreferences).getSingle()).themeMode,
      'system',
    );
    expect(
      (await database.select(database.appPreferences).getSingle())
          .maintenanceNotificationsEnabled,
      isTrue,
    );
    expect(
      (await database.select(database.appPreferences).getSingle())
          .fishStockJson,
      '[]',
    );
    final stageFourTables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name IN ('test_timer_defaults', 'active_test_sessions')",
        )
        .get();
    expect(
      stageFourTables.map((row) => row.read<String>('name')),
      containsAll(['test_timer_defaults', 'active_test_sessions']),
    );
  });

  test('检测记录分离算法估值与人工确认值并关联正确海缸', () async {
    final now = DateTime.utc(2026, 8, 10, 1, 2, 3);
    await database
        .into(database.testRecords)
        .insert(
          TestRecordsCompanion.insert(
            id: 'record-1',
            tankId: AppDatabase.defaultTankId,
            parameterId: AppDatabase.no3Id,
            reagentProfileId: const Value(AppDatabase.ealNo3ReagentId),
            capturedAt: Value(now.subtract(const Duration(minutes: 5))),
            estimatedMinValue: const Value(10),
            estimatedMaxValue: const Value(25),
            estimationMethod: const Value('manual-color-level'),
            estimationVersion: const Value('unvalidated-v0'),
            qualityScore: const Value(0.7),
            confidence: const Value('medium'),
            confirmedMinValue: 15,
            unit: 'mg/L',
            measuredAt: now,
            confirmedAt: Value(now),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final record = await database.select(database.testRecords).getSingle();
    expect(record.tankId, AppDatabase.defaultTankId);
    expect(record.parameterId, AppDatabase.no3Id);
    expect(record.estimatedMinValue, 10);
    expect(record.estimatedMaxValue, 25);
    expect(record.confirmedMinValue, 15);
    expect(record.confirmedMaxValue, equals(null));
    expect(record.reagentProfileId, AppDatabase.ealNo3ReagentId);
    expect(
      record.capturedAt?.toUtc(),
      now.subtract(const Duration(minutes: 5)),
    );
    expect(record.confirmedAt?.toUtc(), now);
    expect(record.qualityScore, 0.7);
    expect(record.confidence, 'medium');
    expect(record.wasManuallyEdited, isFalse);
  });

  test('手动记录仓库校验参数归属、按缸隔离并支持编辑', () async {
    final records = TestRecordRepository(database);
    final secondTankId = await repository.createTank(name: '记录隔离缸');
    final id = await records.createManual(
      tankId: secondTankId,
      parameterId: AppDatabase.no3Id,
      confirmedMinValue: 3,
      measuredAt: DateTime.utc(2026, 8, 10),
    );
    await records.updateConfirmed(
      id: id,
      tankId: secondTankId,
      confirmedMinValue: 4,
      confirmedMaxValue: 5,
      measuredAt: DateTime.utc(2026, 8, 10, 1),
      notes: '复测',
    );

    expect(
      await records.watchForTank(AppDatabase.defaultTankId).first,
      isEmpty,
    );
    final secondRecords = await records.watchForTank(secondTankId).first;
    expect(secondRecords.single.confirmedMinValue, 4);
    expect(secondRecords.single.confirmedMaxValue, 5);
    expect(secondRecords.single.notes, '复测');
    expect(
      secondRecords.single.confirmedAt?.toUtc(),
      DateTime.utc(2026, 8, 10, 1),
    );
    expect(secondRecords.single.wasManuallyEdited, isTrue);
    await expectLater(
      records.createManual(
        tankId: secondTankId,
        parameterId: AppDatabase.khId,
        confirmedMinValue: 8,
        measuredAt: DateTime.now(),
      ),
      throwsStateError,
    );
  });

  test('schema v1 迁移到 v8 时保留旧数据并创建阶段 2/3/4 表', () async {
    final migrated = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('CREATE TABLE legacy_marker (value TEXT NOT NULL)');
          raw.execute("INSERT INTO legacy_marker VALUES ('kept')");
          raw.userVersion = 1;
        },
      ),
    );
    addTearDown(migrated.close);

    final marker = await migrated
        .customSelect('SELECT value FROM legacy_marker')
        .getSingle();
    final version = await migrated
        .customSelect('PRAGMA user_version')
        .getSingle();
    final columns = await migrated
        .customSelect('PRAGMA table_info(test_records)')
        .get();

    expect(marker.read<String>('value'), 'kept');
    final taskColumns = await migrated
        .customSelect('PRAGMA table_info(maintenance_tasks)')
        .get();
    final eventColumns = await migrated
        .customSelect('PRAGMA table_info(task_events)')
        .get();

    expect(version.read<int>('user_version'), 10);
    expect(
      columns.map((row) => row.read<String>('name')),
      containsAll(['estimated_min_value', 'confirmed_min_value']),
    );
    expect(
      taskColumns.map((row) => row.read<String>('name')),
      containsAll([
        'tank_id',
        'due_at',
        'preferred_reminder_time',
        'status',
        'is_one_off',
        'source',
        'plan_id',
        'plan_day_index',
        'plan_total_days',
      ]),
    );
    expect(
      eventColumns.map((row) => row.read<String>('name')),
      containsAll(['task_id', 'type', 'occurred_at', 'snoozed_until']),
    );
    final stageFourTables = await migrated
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name IN ('test_timer_defaults', 'active_test_sessions')",
        )
        .get();
    expect(stageFourTables, hasLength(2));
  });

  test('schema v2 迁移到 v8 时保留旧数据并创建后续表', () async {
    final migrated = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('CREATE TABLE legacy_marker (value TEXT NOT NULL)');
          raw.execute("INSERT INTO legacy_marker VALUES ('from-v2')");
          raw.userVersion = 2;
        },
      ),
    );
    addTearDown(migrated.close);

    final marker = await migrated
        .customSelect('SELECT value FROM legacy_marker')
        .getSingle();
    final version = await migrated
        .customSelect('PRAGMA user_version')
        .getSingle();
    final tables = await migrated
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name IN ('maintenance_tasks', 'task_events')",
        )
        .get();

    expect(marker.read<String>('value'), 'from-v2');
    expect(version.read<int>('user_version'), 10);
    expect(
      tables.map((row) => row.read<String>('name')),
      containsAll(['maintenance_tasks', 'task_events']),
    );
  });

  test('schema v3 迁移到 v8 回填确认时间且不伪造算法字段', () async {
    final measuredAt = DateTime.utc(2026, 8, 10, 3, 4, 5);
    final microseconds = measuredAt.microsecondsSinceEpoch;
    final migrated = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
CREATE TABLE test_records (
  id TEXT NOT NULL PRIMARY KEY,
  tank_id TEXT NOT NULL,
  parameter_id TEXT NOT NULL,
  estimated_min_value REAL NULL,
  estimated_max_value REAL NULL,
  estimation_method TEXT NULL,
  estimation_version TEXT NULL,
  confirmed_min_value REAL NOT NULL,
  confirmed_max_value REAL NULL,
  unit TEXT NOT NULL,
  measured_at INTEGER NOT NULL,
  notes TEXT NULL,
  photo_path TEXT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
          raw.execute(
            "INSERT INTO test_records "
            "(id, tank_id, parameter_id, confirmed_min_value, unit, "
            "measured_at, created_at, updated_at) VALUES "
            "('legacy-record', 'tank', 'parameter', 5, 'mg/L', "
            '$microseconds, $microseconds, $microseconds)',
          );
          raw.userVersion = 3;
        },
      ),
    );
    addTearDown(migrated.close);

    final record = await migrated
        .customSelect('SELECT * FROM test_records')
        .getSingle();
    final version = await migrated
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 10);
    expect(record.read<int>('confirmed_at'), microseconds);
    expect(record.read<int>('was_manually_edited'), 0);
    expect(record.data['captured_at'], isNull);
    expect(record.data['quality_score'], isNull);
    expect(record.data['confidence'], isNull);
    expect(record.data['failure_reason'], isNull);
  });

  test('schema v4 迁移到 v8 为检测草稿增加确认时间并创建偏好表', () async {
    final migrated = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
CREATE TABLE active_test_sessions (
  id TEXT NOT NULL PRIMARY KEY
)
''');
          raw.userVersion = 4;
        },
      ),
    );
    addTearDown(migrated.close);

    final version = await migrated
        .customSelect('PRAGMA user_version')
        .getSingle();
    final columns = await migrated
        .customSelect('PRAGMA table_info(active_test_sessions)')
        .get();

    expect(version.read<int>('user_version'), 10);
    expect(
      columns.map((row) => row.read<String>('name')),
      contains('draft_confirmed_at'),
    );
    final confirmedColumn = columns.singleWhere(
      (row) => row.read<String>('name') == 'draft_confirmed_at',
    );
    expect(confirmedColumn.read<int>('notnull'), 0);
  });

  test('schema v5 迁移到 v8 为既有应用偏好补主题、通知和鱼类档案', () async {
    final migrated = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
CREATE TABLE app_preferences (
  id INTEGER NOT NULL DEFAULT 1 PRIMARY KEY,
  current_tank_id TEXT NULL,
  updated_at INTEGER NOT NULL
)
''');
          raw.execute(
            'INSERT INTO app_preferences '
            '(id, current_tank_id, updated_at) VALUES (1, NULL, 0)',
          );
          raw.userVersion = 5;
        },
      ),
    );
    addTearDown(migrated.close);

    final version = await migrated
        .customSelect('PRAGMA user_version')
        .getSingle();
    final preference = await migrated
        .select(migrated.appPreferences)
        .getSingle();

    expect(version.read<int>('user_version'), 10);
    expect(preference.themeMode, 'system');
    expect(preference.maintenanceNotificationsEnabled, isTrue);
    expect(preference.fishStockJson, '[]');
  });

  test('schema v6 迁移到 v8 保留任务并补一次性计划与鱼类字段', () async {
    final migrated = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
CREATE TABLE app_preferences (
  id INTEGER NOT NULL DEFAULT 1 PRIMARY KEY,
  current_tank_id TEXT NULL,
  theme_mode TEXT NOT NULL DEFAULT 'system',
  updated_at INTEGER NOT NULL
)
''');
          raw.execute(
            'INSERT INTO app_preferences '
            '(id, current_tank_id, theme_mode, updated_at) '
            "VALUES (1, NULL, 'dark', 0)",
          );
          raw.execute('''
CREATE TABLE maintenance_tasks (
  id TEXT NOT NULL PRIMARY KEY,
  tank_id TEXT NOT NULL,
  title TEXT NOT NULL,
  notes TEXT NULL,
  interval_amount INTEGER NOT NULL,
  interval_unit TEXT NOT NULL,
  due_at INTEGER NOT NULL,
  preferred_reminder_time TEXT NOT NULL DEFAULT '09:00',
  status TEXT NOT NULL DEFAULT 'enabled',
  notification_id INTEGER NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
          raw.execute(
            'INSERT INTO maintenance_tasks '
            '(id, tank_id, title, interval_amount, interval_unit, due_at, '
            'preferred_reminder_time, status, created_at, updated_at) '
            "VALUES ('legacy-task', 'legacy-tank', '旧换水任务', 7, 'day', "
            "0, '09:00', 'enabled', 0, 0)",
          );
          raw.userVersion = 6;
        },
      ),
    );
    addTearDown(migrated.close);

    final preference = await migrated
        .select(migrated.appPreferences)
        .getSingle();
    final task = await migrated.select(migrated.maintenanceTasks).getSingle();

    expect(preference.themeMode, 'dark');
    expect(preference.maintenanceNotificationsEnabled, isTrue);
    expect(preference.fishStockJson, '[]');
    expect(task.id, 'legacy-task');
    expect(task.title, '旧换水任务');
    expect(task.isOneOff, isFalse);
    expect(task.source, isNull);
    expect(task.planId, isNull);
    expect(task.planDayIndex, isNull);
    expect(task.planTotalDays, isNull);
  });

  test('schema v7 迁移到 v8 为既有偏好补空鱼类档案', () async {
    final migrated = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
CREATE TABLE app_preferences (
  id INTEGER NOT NULL DEFAULT 1 PRIMARY KEY,
  current_tank_id TEXT NULL,
  theme_mode TEXT NOT NULL DEFAULT 'system',
  maintenance_notifications_enabled INTEGER NOT NULL DEFAULT 1,
  updated_at INTEGER NOT NULL
)
''');
          raw.execute(
            'INSERT INTO app_preferences '
            '(id, current_tank_id, theme_mode, '
            'maintenance_notifications_enabled, updated_at) '
            "VALUES (1, NULL, 'dark', 0, 0)",
          );
          raw.userVersion = 7;
        },
      ),
    );
    addTearDown(migrated.close);

    final preference = await migrated
        .select(migrated.appPreferences)
        .getSingle();
    final version = await migrated
        .customSelect('PRAGMA user_version')
        .getSingle();

    expect(version.read<int>('user_version'), 10);
    expect(preference.themeMode, 'dark');
    expect(preference.maintenanceNotificationsEnabled, isFalse);
    expect(preference.fishStockJson, '[]');
  });

  test('主题偏好持久化并拒绝未知模式', () async {
    await repository.setThemeMode('dark');
    expect(await repository.readThemeMode(), 'dark');
    await repository.setThemeMode('light');
    expect(await repository.readThemeMode(), 'light');
    await expectLater(repository.setThemeMode('sepia'), throwsArgumentError);
  });

  test('新增海缸、参数、目标和启停状态严格按海缸隔离', () async {
    final secondTankId = await repository.createTank(name: '办公室海缸');
    final customId = await repository.createCustomParameter(
      tankId: AppDatabase.defaultTankId,
      code: 'SAL',
      displayName: '盐度',
      unit: 'ppt',
    );
    await repository.setParameterEnabled(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.khId,
      enabled: true,
    );
    await repository.setTarget(
      tankId: AppDatabase.defaultTankId,
      parameterId: customId,
      minValue: 34,
      maxValue: 35,
    );
    await repository.setTarget(
      tankId: secondTankId,
      parameterId: AppDatabase.no3Id,
      minValue: 1,
      maxValue: 5,
    );

    final firstEnabled = await repository
        .watchEnabledParameters(AppDatabase.defaultTankId)
        .first;
    final secondEnabled = await repository
        .watchEnabledParameters(secondTankId)
        .first;
    final targets = await database.select(database.waterQualityTargets).get();

    expect(
      firstEnabled.map((item) => item.code),
      containsAll(['NO3', 'PO4', 'KH', 'SAL']),
    );
    expect(secondEnabled.map((item) => item.code), ['NO3', 'PO4']);
    expect(
      targets
          .where((item) => item.tankId == AppDatabase.defaultTankId)
          .single
          .parameterId,
      customId,
    );
    expect(
      targets.where((item) => item.tankId == secondTankId).single.parameterId,
      AppDatabase.no3Id,
    );
  });

  test('切换和归档当前海缸时选择未归档替代项', () async {
    final secondTankId = await repository.createTank(name: '第二海缸');
    await repository.switchTank(secondTankId);
    expect((await repository.watchCurrentTank().first)?.id, secondTankId);

    await repository.archiveTank(secondTankId);
    expect(
      (await repository.watchCurrentTank().first)?.id,
      AppDatabase.defaultTankId,
    );
    final active = await repository.watchActiveTanks().first;
    expect(active.map((item) => item.id), [AppDatabase.defaultTankId]);
    await expectLater(
      repository.archiveTank(AppDatabase.defaultTankId),
      throwsStateError,
    );
  });

  test('停用参数保留目标且不能停用最后一个参数', () async {
    await repository.setTarget(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
      minValue: 1,
      maxValue: 5,
    );
    await repository.setParameterEnabled(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
      enabled: false,
    );
    expect(
      await database.select(database.waterQualityTargets).get(),
      hasLength(1),
    );
    await expectLater(
      repository.setParameterEnabled(
        tankId: AppDatabase.defaultTankId,
        parameterId: AppDatabase.po4Id,
        enabled: false,
      ),
      throwsStateError,
    );
  });

  test('版本化 JSON 备份合并后保留海缸关联', () async {
    final secondTankId = await repository.createTank(name: '备份海缸');
    await repository.setTarget(
      tankId: secondTankId,
      parameterId: AppDatabase.po4Id,
      minValue: 0.01,
      maxValue: 0.05,
    );
    final now = DateTime.utc(2026, 8, 10);
    await database
        .into(database.testRecords)
        .insert(
          TestRecordsCompanion.insert(
            id: 'backup-record',
            tankId: secondTankId,
            parameterId: AppDatabase.po4Id,
            confirmedMinValue: 0.03,
            unit: 'mg/L',
            measuredAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    final maintenance = MaintenanceRepository(
      database,
      now: () => DateTime.utc(2026, 8, 10, 9),
    );
    final taskId = await maintenance.createTask(
      tankId: secondTankId,
      title: '清洗滤棉',
      intervalAmount: 3,
      intervalUnit: MaintenanceIntervalUnit.day,
      dueAt: DateTime.utc(2026, 8, 10, 9),
    );
    await maintenance.complete(tankId: secondTankId, taskId: taskId);
    final testSessions = TestSessionRepository(
      database,
      now: () => DateTime.utc(2026, 8, 10, 10),
    );
    await testSessions.setDefaultDurationSeconds(
      tankId: secondTankId,
      parameterId: AppDatabase.po4Id,
      durationSeconds: 600,
    );
    await testSessions.createDraft(
      tankId: secondTankId,
      parameterId: AppDatabase.po4Id,
    );
    final backup = await LocalBackupService(database).exportJson();

    final restored = AppDatabase(NativeDatabase.memory());
    addTearDown(restored.close);
    await LocalBackupService(restored).restoreMerge(backup);

    final tanks = await restored.select(restored.tanks).get();
    final targets = await restored.select(restored.waterQualityTargets).get();
    final records = await restored.select(restored.testRecords).get();
    final tasks = await restored.select(restored.maintenanceTasks).get();
    final events = await restored.select(restored.taskEvents).get();
    final timerDefaults = await restored
        .select(restored.testTimerDefaults)
        .get();
    final activeSessions = await restored
        .select(restored.activeTestSessions)
        .get();
    expect(tanks.any((item) => item.id == secondTankId), isTrue);
    expect(
      targets.singleWhere((item) => item.tankId == secondTankId).parameterId,
      AppDatabase.po4Id,
    );
    expect(records.single.tankId, secondTankId);
    expect(records.single.confirmedMinValue, 0.03);
    expect(tasks.single.tankId, secondTankId);
    expect(events.single.taskId, tasks.single.id);
    expect(events.single.type, TaskEventType.completed.name);
    expect(timerDefaults.single.tankId, secondTankId);
    expect(timerDefaults.single.durationSeconds, 600);
    expect(activeSessions.single.tankId, secondTankId);
    expect(activeSessions.single.parameterId, AppDatabase.po4Id);
  });

  test('备份格式 v8 兼容读取不含维护任务和检测草稿的 v2 备份', () async {
    final decoded =
        jsonDecode(await LocalBackupService(database).exportJson())
            as Map<String, dynamic>;
    decoded['formatVersion'] = 2;
    decoded.remove('maintenanceTasks');
    decoded.remove('taskEvents');
    decoded.remove('testTimerDefaults');
    decoded.remove('activeTestSessions');

    final restored = AppDatabase(NativeDatabase.memory());
    addTearDown(restored.close);
    await LocalBackupService(restored).restoreMerge(jsonEncode(decoded));

    expect(await restored.select(restored.tanks).get(), hasLength(1));
    expect(await restored.select(restored.maintenanceTasks).get(), isEmpty);
    expect(await restored.select(restored.taskEvents).get(), isEmpty);
    expect(await restored.select(restored.testTimerDefaults).get(), isEmpty);
    expect(await restored.select(restored.activeTestSessions).get(), isEmpty);
  });

  test('备份格式 v8 读取 v3 记录时保守回填阶段 4 字段', () async {
    await TestRecordRepository(database).createManual(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
      confirmedMinValue: 5,
      measuredAt: DateTime.utc(2026, 8, 10, 1),
    );
    final decoded =
        jsonDecode(await LocalBackupService(database).exportJson())
            as Map<String, dynamic>;
    decoded['formatVersion'] = 3;
    decoded.remove('testTimerDefaults');
    decoded.remove('activeTestSessions');
    final legacyRecord =
        (decoded['testRecords'] as List).single as Map<String, dynamic>;
    for (final key in [
      'reagentProfileId',
      'capturedAt',
      'confirmedAt',
      'qualityScore',
      'confidence',
      'failureReason',
      'wasManuallyEdited',
    ]) {
      legacyRecord.remove(key);
    }

    final restored = AppDatabase(NativeDatabase.memory());
    addTearDown(restored.close);
    await LocalBackupService(restored).restoreMerge(jsonEncode(decoded));

    final record = await restored.select(restored.testRecords).getSingle();
    expect(record.confirmedAt, record.measuredAt);
    expect(record.wasManuallyEdited, isFalse);
    expect(record.reagentProfileId, isNull);
    expect(record.capturedAt, isNull);
    expect(record.qualityScore, isNull);
    expect(record.confidence, isNull);
    expect(record.failureReason, isNull);
  });

  test('备份格式 v8 兼容读取缺少草稿确认时间的 v4 备份', () async {
    final sessions = TestSessionRepository(database);
    final sessionId = await sessions.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
    );
    await sessions.updateReviewDraft(
      tankId: AppDatabase.defaultTankId,
      sessionId: sessionId,
      confirmedMinValue: 10,
      confirmedAt: DateTime.utc(2026, 8, 13, 2, 30),
    );
    final decoded =
        jsonDecode(await LocalBackupService(database).exportJson())
            as Map<String, dynamic>;
    decoded['formatVersion'] = 4;
    final legacySession =
        (decoded['activeTestSessions'] as List).single as Map<String, dynamic>;
    legacySession.remove('draftConfirmedAt');

    final restored = AppDatabase(NativeDatabase.memory());
    addTearDown(restored.close);
    await LocalBackupService(restored).restoreMerge(jsonEncode(decoded));

    final draft = await restored
        .select(restored.activeTestSessions)
        .getSingle();
    expect(draft.draftConfirmedMinValue, 10);
    expect(draft.draftConfirmedAt, isNull);
  });
}
