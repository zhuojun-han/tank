import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

class Tanks extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get notes => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class WaterParameters extends Table {
  TextColumn get id => text()();
  TextColumn get code => text().unique()();
  TextColumn get displayName => text().withLength(min: 1, max: 40)();
  TextColumn get unit => text().withLength(min: 1, max: 20)();
  BoolColumn get isBuiltIn => boolean()();
  BoolColumn get photoSupported =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TankParameters extends Table {
  TextColumn get tankId => text().references(Tanks, #id)();
  TextColumn get parameterId => text().references(WaterParameters, #id)();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {tankId, parameterId};
}

class WaterQualityTargets extends Table {
  TextColumn get id => text()();
  TextColumn get tankId => text().references(Tanks, #id)();
  TextColumn get parameterId => text().references(WaterParameters, #id)();
  RealColumn get minValue => real().nullable()();
  RealColumn get maxValue => real().nullable()();
  TextColumn get unit => text().withLength(min: 1, max: 20)();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {tankId, parameterId},
  ];
}

class ReagentProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get brand => text().withLength(min: 1, max: 80)();
  TextColumn get parameterId => text().references(WaterParameters, #id)();
  TextColumn get unit => text().withLength(min: 1, max: 20)();
  TextColumn get colorLevelsJson => text()();
  IntColumn get defaultDevelopmentSeconds => integer()();
  TextColumn get cardVersion => text().nullable()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AppPreferences extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get currentTankId => text().nullable().references(Tanks, #id)();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  BoolColumn get maintenanceNotificationsEnabled =>
      boolean().withDefault(const Constant(true))();
  TextColumn get fishStockJson => text().withDefault(const Constant('[]'))();
  BoolColumn get khTargetDefaultsApplied =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TestRecords extends Table {
  TextColumn get id => text()();
  TextColumn get tankId => text().references(Tanks, #id)();
  TextColumn get parameterId => text().references(WaterParameters, #id)();
  TextColumn get reagentProfileId =>
      text().nullable().references(ReagentProfiles, #id)();
  DateTimeColumn get capturedAt => dateTime().nullable()();
  RealColumn get estimatedMinValue => real().nullable()();
  RealColumn get estimatedMaxValue => real().nullable()();
  TextColumn get estimationMethod => text().nullable()();
  TextColumn get estimationVersion => text().nullable()();
  RealColumn get qualityScore => real().nullable()();
  TextColumn get confidence => text().nullable()();
  TextColumn get failureReason => text().nullable()();
  TextColumn get khTitrationJson => text().nullable()();
  RealColumn get confirmedMinValue => real()();
  RealColumn get confirmedInterpolation => real().nullable()();
  RealColumn get estimatedInterpolation => real().nullable()();
  RealColumn get confirmedMaxValue => real().nullable()();
  TextColumn get unit => text().withLength(min: 1, max: 20)();
  // Retained for backwards compatibility with schema v2/v3 readers. New
  // writes keep this in sync with confirmedAt.
  DateTimeColumn get measuredAt => dateTime()();
  DateTimeColumn get confirmedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  // Legacy-only compatibility field. New captures, records and backups keep
  // this null because photos are deleted after the current comparison.
  TextColumn get photoPath => text().nullable()();
  BoolColumn get wasManuallyEdited =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MaintenanceTasks extends Table {
  TextColumn get id => text()();
  TextColumn get tankId => text().references(Tanks, #id)();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get notes => text().nullable()();
  IntColumn get intervalAmount => integer()();
  TextColumn get intervalUnit => text().withLength(min: 1, max: 10)();
  DateTimeColumn get dueAt => dateTime()();
  TextColumn get preferredReminderTime =>
      text().withLength(min: 5, max: 5).withDefault(const Constant('09:00'))();
  TextColumn get status => text().withDefault(const Constant('enabled'))();
  BoolColumn get isOneOff => boolean().withDefault(const Constant(false))();
  TextColumn get source => text().nullable()();
  TextColumn get planId => text().nullable()();
  IntColumn get planDayIndex => integer().nullable()();
  IntColumn get planTotalDays => integer().nullable()();
  TextColumn get recurrenceJson => text().nullable()();
  TextColumn get rollingJson => text().nullable()();
  IntColumn get notificationId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('MaintenanceCycleRow')
class MaintenanceCycles extends Table {
  TextColumn get id => text()();
  TextColumn get tankId => text().references(Tanks, #id)();
  TextColumn get chemical => text()();
  TextColumn get startDate => text()();
  TextColumn get refillDate => text()();
  RealColumn get solutionMl => real()();
  RealColumn get dailyLiquidMl => real()();
  RealColumn get effectPerMl => real()();
  RealColumn get retainedMl => real()();
  RealColumn get addedStockMl => real()();
  RealColumn get addedWaterMl => real()();
  TextColumn get inputJson => text()();
  // Checked as a same-tank/reagent history link by the repository and backup.
  TextColumn get previousCycleId => text().nullable()();
  TextColumn get closedOnDate => text().nullable()();
  TextColumn get refillDeferredUntil => text().nullable()();
  IntColumn get notificationId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TaskEvents extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(MaintenanceTasks, #id)();
  TextColumn get type => text().withLength(min: 1, max: 16)();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get snoozedUntil => dateTime().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TestTimerDefaults extends Table {
  TextColumn get tankId => text().references(Tanks, #id)();
  TextColumn get parameterId => text().references(WaterParameters, #id)();
  IntColumn get durationSeconds => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {tankId, parameterId};
}

class ActiveTestSessions extends Table {
  TextColumn get id => text()();
  TextColumn get tankId => text().references(Tanks, #id)();
  TextColumn get parameterId => text().references(WaterParameters, #id)();
  TextColumn get reagentProfileId =>
      text().nullable().references(ReagentProfiles, #id)();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get timerDurationSeconds => integer()();
  DateTimeColumn get timerEndsAt => dateTime().nullable()();
  IntColumn get pausedRemainingSeconds => integer().nullable()();
  // Legacy-only compatibility field. Current capture flow never persists a
  // temporary photo reference into a draft.
  TextColumn get draftPhotoPath => text().nullable()();
  DateTimeColumn get draftCapturedAt => dateTime().nullable()();
  RealColumn get draftEstimatedMinValue => real().nullable()();
  RealColumn get draftEstimatedMaxValue => real().nullable()();
  TextColumn get draftEstimationMethod => text().nullable()();
  TextColumn get draftEstimationVersion => text().nullable()();
  RealColumn get draftQualityScore => real().nullable()();
  TextColumn get draftConfidence => text().nullable()();
  TextColumn get draftFailureReason => text().nullable()();
  RealColumn get draftConfirmedMinValue => real().nullable()();
  RealColumn get draftConfirmedInterpolation => real().nullable()();
  RealColumn get draftEstimatedInterpolation => real().nullable()();
  RealColumn get draftConfirmedMaxValue => real().nullable()();
  DateTimeColumn get draftConfirmedAt => dateTime().nullable()();
  TextColumn get draftNotes => text().nullable()();
  TextColumn get stage => text().withLength(min: 1, max: 32)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {tankId, parameterId},
  ];
}

@DriftDatabase(
  tables: [
    Tanks,
    WaterParameters,
    TankParameters,
    WaterQualityTargets,
    ReagentProfiles,
    AppPreferences,
    TestRecords,
    MaintenanceTasks,
    MaintenanceCycles,
    TaskEvents,
    TestTimerDefaults,
    ActiveTestSessions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.open() : super(_openConnection());

  static const defaultTankId = '00000000-0000-4000-8000-000000000001';
  static const no3Id = '00000000-0000-4000-8000-000000000101';
  static const po4Id = '00000000-0000-4000-8000-000000000102';
  static const khId = '00000000-0000-4000-8000-000000000103';
  static const caId = '00000000-0000-4000-8000-000000000104';
  static const mgId = '00000000-0000-4000-8000-000000000105';
  static const potassiumId = '00000000-0000-4000-8000-000000000106';
  static const ealNo3ReagentId = '00000000-0000-4000-8000-000000000201';

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      // Drift 在迁移事务内执行 onCreate；直接 seed 可保持建表与初始数据原子性。
      await _seedInitialData();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(testRecords);
      }
      if (from < 3) {
        await migrator.createTable(maintenanceTasks);
        await migrator.createTable(taskEvents);
      }
      if (from < 4) {
        // A normal v2/v3 database already has test_records. The existence
        // check also makes recovery from an incomplete historical database
        // conservative: create the current table instead of adding columns to
        // a missing table.
        if (from >= 2 && await _tableExists('test_records')) {
          await migrator.addColumn(testRecords, testRecords.reagentProfileId);
          await migrator.addColumn(testRecords, testRecords.capturedAt);
          await migrator.addColumn(testRecords, testRecords.qualityScore);
          await migrator.addColumn(testRecords, testRecords.confidence);
          await migrator.addColumn(testRecords, testRecords.failureReason);
          await migrator.addColumn(testRecords, testRecords.confirmedAt);
          await migrator.addColumn(testRecords, testRecords.wasManuallyEdited);
          await customStatement(
            'UPDATE test_records '
            'SET confirmed_at = measured_at '
            'WHERE confirmed_at IS NULL',
          );
        } else if (!await _tableExists('test_records')) {
          await migrator.createTable(testRecords);
        }
        await migrator.createTable(testTimerDefaults);
        await migrator.createTable(activeTestSessions);
      }
      if (from >= 4 && from < 5) {
        if (await _tableExists('active_test_sessions')) {
          await migrator.addColumn(
            activeTestSessions,
            activeTestSessions.draftConfirmedAt,
          );
        } else {
          await migrator.createTable(activeTestSessions);
        }
      }
      if (from < 6) {
        if (await _tableExists('app_preferences')) {
          await migrator.addColumn(appPreferences, appPreferences.themeMode);
        } else {
          await migrator.createTable(appPreferences);
        }
      }
      if (from < 7) {
        if (await _tableExists('app_preferences')) {
          if (!await _columnExists(
            'app_preferences',
            'maintenance_notifications_enabled',
          )) {
            await migrator.addColumn(
              appPreferences,
              appPreferences.maintenanceNotificationsEnabled,
            );
          }
        } else {
          await migrator.createTable(appPreferences);
        }
        if (await _tableExists('maintenance_tasks')) {
          if (!await _columnExists('maintenance_tasks', 'is_one_off')) {
            await migrator.addColumn(
              maintenanceTasks,
              maintenanceTasks.isOneOff,
            );
          }
          if (!await _columnExists('maintenance_tasks', 'source')) {
            await migrator.addColumn(maintenanceTasks, maintenanceTasks.source);
          }
          if (!await _columnExists('maintenance_tasks', 'plan_id')) {
            await migrator.addColumn(maintenanceTasks, maintenanceTasks.planId);
          }
          if (!await _columnExists('maintenance_tasks', 'plan_day_index')) {
            await migrator.addColumn(
              maintenanceTasks,
              maintenanceTasks.planDayIndex,
            );
          }
          if (!await _columnExists('maintenance_tasks', 'plan_total_days')) {
            await migrator.addColumn(
              maintenanceTasks,
              maintenanceTasks.planTotalDays,
            );
          }
        } else {
          await migrator.createTable(maintenanceTasks);
        }
      }
      if (from < 8) {
        if (await _tableExists('app_preferences')) {
          if (!await _columnExists('app_preferences', 'fish_stock_json')) {
            await migrator.addColumn(
              appPreferences,
              appPreferences.fishStockJson,
            );
          }
        } else {
          await migrator.createTable(appPreferences);
        }
      }
      if (from < 9 &&
          !await _columnExists('maintenance_tasks', 'recurrence_json')) {
        if (await _tableExists('maintenance_tasks')) {
          await migrator.addColumn(
            maintenanceTasks,
            maintenanceTasks.recurrenceJson,
          );
        } else {
          await migrator.createTable(maintenanceTasks);
        }
      }
      if (from < 10) {
        if (!await _tableExists('test_records')) {
          await migrator.createTable(testRecords);
        }
        if (!await _tableExists('active_test_sessions')) {
          await migrator.createTable(activeTestSessions);
        }
        for (final column in [
          testRecords.confirmedInterpolation,
          testRecords.estimatedInterpolation,
        ]) {
          if (!await _columnExists('test_records', column.name)) {
            await migrator.addColumn(testRecords, column);
          }
        }
        for (final column in [
          activeTestSessions.draftConfirmedInterpolation,
          activeTestSessions.draftEstimatedInterpolation,
        ]) {
          if (!await _columnExists('active_test_sessions', column.name)) {
            await migrator.addColumn(activeTestSessions, column);
          }
        }
        if (await _tableExists('water_parameters')) {
          await (update(
            waterParameters,
          )..where((p) => p.code.equals('PO4'))).write(
            const WaterParametersCompanion(photoSupported: Value(true)),
          );
        }
      }
      if (from < 11) {
        if (!await _tableExists('maintenance_cycles')) {
          await migrator.createTable(maintenanceCycles);
        }
        if (await _tableExists('water_quality_targets')) {
          await migrator.alterTable(TableMigration(waterQualityTargets));
        } else {
          await migrator.createTable(waterQualityTargets);
        }
        if (!await _columnExists(
          'app_preferences',
          'kh_target_defaults_applied',
        )) {
          await migrator.addColumn(
            appPreferences,
            appPreferences.khTargetDefaultsApplied,
          );
        }
        if (!await _columnExists('test_records', 'kh_titration_json')) {
          await migrator.addColumn(testRecords, testRecords.khTitrationJson);
        }
        if (!await _columnExists('maintenance_tasks', 'rolling_json')) {
          await migrator.addColumn(
            maintenanceTasks,
            maintenanceTasks.rollingJson,
          );
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await initializeKhTargetDefaults();
    },
  );

  /// Run once per persisted state, including after an older backup is restored.
  /// Keep empty target rows so an intentional later clear is distinguishable.
  Future<void> initializeKhTargetDefaults() => transaction(() async {
    final preference = await select(appPreferences).getSingleOrNull();
    if (preference == null || preference.khTargetDefaultsApplied) return;
    if (!await _tableExists('water_parameters') ||
        !await _tableExists('tank_parameters')) {
      return;
    }
    final parameters = await (select(
      waterParameters,
    )..where((p) => p.code.upper().equals('KH'))).get();
    final now = DateTime.now().toUtc();
    for (final parameter in parameters) {
      final enabled =
          await (select(tankParameters)..where(
                (p) =>
                    p.parameterId.equals(parameter.id) &
                    p.isEnabled.equals(true),
              ))
              .get();
      for (final scope in enabled) {
        final existing =
            await (select(waterQualityTargets)..where(
                  (t) =>
                      t.tankId.equals(scope.tankId) &
                      t.parameterId.equals(parameter.id),
                ))
                .getSingleOrNull();
        if (existing == null) {
          await into(waterQualityTargets).insert(
            WaterQualityTargetsCompanion.insert(
              id: const Uuid().v4(),
              tankId: scope.tankId,
              parameterId: parameter.id,
              minValue: const Value(7),
              maxValue: const Value(9),
              unit: parameter.unit,
              updatedAt: now,
            ),
          );
        } else if (existing.minValue == null && existing.maxValue == null) {
          await (update(
            waterQualityTargets,
          )..where((t) => t.id.equals(existing.id))).write(
            WaterQualityTargetsCompanion(
              minValue: const Value(7),
              maxValue: const Value(9),
              updatedAt: Value(now),
            ),
          );
        }
      }
    }
    await (update(appPreferences)..where((p) => p.id.equals(1))).write(
      const AppPreferencesCompanion(khTargetDefaultsApplied: Value(true)),
    );
  });

  Future<bool> _tableExists(String tableName) async {
    final result = await customSelect(
      'SELECT COUNT(*) AS count FROM sqlite_master '
      "WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(tableName)],
    ).getSingle();
    return result.read<int>('count') > 0;
  }

  Future<bool> _columnExists(String tableName, String columnName) async {
    final columns = await customSelect('PRAGMA table_info($tableName)').get();
    return columns.any((row) => row.read<String>('name') == columnName);
  }

  Future<void> _seedInitialData() async {
    final now = DateTime.now().toUtc();
    const builtIns = [
      (id: no3Id, code: 'NO3', name: '硝酸盐', unit: 'mg/L', photo: true),
      (id: po4Id, code: 'PO4', name: '磷酸盐', unit: 'mg/L', photo: true),
      (id: khId, code: 'KH', name: '碳酸盐硬度', unit: 'dKH', photo: false),
      (id: caId, code: 'CA', name: '钙', unit: 'mg/L', photo: false),
      (id: mgId, code: 'MG', name: '镁', unit: 'mg/L', photo: false),
      (id: potassiumId, code: 'K', name: '钾', unit: 'mg/L', photo: false),
    ];

    await batch((batch) {
      batch.insert(
        tanks,
        TanksCompanion.insert(
          id: defaultTankId,
          name: '我的海缸',
          createdAt: now,
          updatedAt: now,
        ),
      );
      batch.insertAll(waterParameters, [
        for (final item in builtIns)
          WaterParametersCompanion.insert(
            id: item.id,
            code: item.code,
            displayName: item.name,
            unit: item.unit,
            isBuiltIn: true,
            photoSupported: Value(item.photo),
            createdAt: now,
          ),
      ]);
      batch.insertAll(tankParameters, [
        TankParametersCompanion.insert(
          tankId: defaultTankId,
          parameterId: no3Id,
          updatedAt: now,
        ),
        TankParametersCompanion.insert(
          tankId: defaultTankId,
          parameterId: po4Id,
          updatedAt: now,
        ),
      ]);
      batch.insert(
        reagentProfiles,
        ReagentProfilesCompanion.insert(
          id: ealNo3ReagentId,
          brand: '益尔',
          parameterId: no3Id,
          unit: 'mg/L',
          colorLevelsJson: '[0,1,5,10,25,50,100]',
          defaultDevelopmentSeconds: 300,
          updatedAt: now,
        ),
      );
      batch.insert(
        appPreferences,
        AppPreferencesCompanion.insert(
          currentTankId: const Value(defaultTankId),
          updatedAt: now,
        ),
      );
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, 'lanjiao.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
