import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database/app_database.dart';

class TankParameterState {
  const TankParameterState({
    required this.parameter,
    required this.isEnabled,
    this.isAssociated = true,
  });

  final WaterParameter parameter;
  final bool isEnabled;
  final bool isAssociated;
}

class TankRepository {
  TankRepository(this._database, [this._uuid = const Uuid()]);

  final AppDatabase _database;
  final Uuid _uuid;

  Stream<List<Tank>> watchActiveTanks() {
    final query = _database.select(_database.tanks)
      ..where((tank) => tank.isArchived.equals(false))
      ..orderBy([(tank) => OrderingTerm.asc(tank.createdAt)]);
    return query.watch();
  }

  Stream<Tank?> watchCurrentTank() {
    final query = _database.select(_database.tanks).join([
      innerJoin(
        _database.appPreferences,
        _database.appPreferences.currentTankId.equalsExp(_database.tanks.id),
      ),
    ])..where(_database.appPreferences.id.equals(1));
    return query.watchSingleOrNull().map(
      (row) => row?.readTable(_database.tanks),
    );
  }

  Future<String> readThemeMode() {
    final query = _database.select(_database.appPreferences)
      ..where((row) => row.id.equals(1));
    return query.getSingle().then((row) => row.themeMode);
  }

  Stream<bool> watchMaintenanceNotificationsEnabled() {
    final query = _database.select(_database.appPreferences)
      ..where((row) => row.id.equals(1));
    return query.watchSingle().map(
      (row) => row.maintenanceNotificationsEnabled,
    );
  }

  Future<void> setMaintenanceNotificationsEnabled(bool enabled) async {
    final changed =
        await (_database.update(
          _database.appPreferences,
        )..where((row) => row.id.equals(1))).write(
          AppPreferencesCompanion(
            maintenanceNotificationsEnabled: Value(enabled),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    if (changed != 1) throw StateError('应用偏好不存在');
  }

  Future<void> setThemeMode(String mode) async {
    if (!const {'system', 'light', 'dark'}.contains(mode)) {
      throw ArgumentError.value(mode, 'mode', '不支持的主题模式');
    }
    final changed =
        await (_database.update(
          _database.appPreferences,
        )..where((row) => row.id.equals(1))).write(
          AppPreferencesCompanion(
            themeMode: Value(mode),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    if (changed != 1) throw StateError('应用偏好不存在');
  }

  Stream<List<WaterParameter>> watchEnabledParameters(String tankId) {
    final query =
        _database.select(_database.waterParameters).join([
            innerJoin(
              _database.tankParameters,
              _database.tankParameters.parameterId.equalsExp(
                _database.waterParameters.id,
              ),
            ),
          ])
          ..where(
            _database.tankParameters.tankId.equals(tankId) &
                _database.tankParameters.isEnabled.equals(true),
          )
          ..orderBy([OrderingTerm.asc(_database.waterParameters.code)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows) row.readTable(_database.waterParameters),
      ],
    );
  }

  Stream<List<TankParameterState>> watchParameterStates(String tankId) {
    final query = _database.select(_database.waterParameters).join([
      leftOuterJoin(
        _database.tankParameters,
        _database.tankParameters.parameterId.equalsExp(
              _database.waterParameters.id,
            ) &
            _database.tankParameters.tankId.equals(tankId),
      ),
    ])..orderBy([OrderingTerm.asc(_database.waterParameters.code)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          TankParameterState(
            parameter: row.readTable(_database.waterParameters),
            isEnabled:
                row.readTableOrNull(_database.tankParameters)?.isEnabled ??
                false,
            isAssociated: row.readTableOrNull(_database.tankParameters) != null,
          ),
      ],
    );
  }

  Future<List<TankParameterState>> readParameterStates(String tankId) async {
    final query = _database.select(_database.waterParameters).join([
      leftOuterJoin(
        _database.tankParameters,
        _database.tankParameters.parameterId.equalsExp(
              _database.waterParameters.id,
            ) &
            _database.tankParameters.tankId.equals(tankId),
      ),
    ])..orderBy([OrderingTerm.asc(_database.waterParameters.code)]);
    final rows = await query.get();
    return [
      for (final row in rows)
        TankParameterState(
          parameter: row.readTable(_database.waterParameters),
          isEnabled:
              row.readTableOrNull(_database.tankParameters)?.isEnabled ?? false,
          isAssociated: row.readTableOrNull(_database.tankParameters) != null,
        ),
    ];
  }

  Stream<List<WaterQualityTarget>> watchTargets(String tankId) {
    final query = _database.select(_database.waterQualityTargets)
      ..where((target) => target.tankId.equals(tankId));
    return query.watch();
  }

  Future<String> createTank({required String name, String? notes}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw ArgumentError('海缸名称不能为空');
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      await _database
          .into(_database.tanks)
          .insert(
            TanksCompanion.insert(
              id: id,
              name: trimmedName,
              notes: Value(_trimToNull(notes)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _database.batch((batch) {
        batch.insertAll(_database.tankParameters, [
          TankParametersCompanion.insert(
            tankId: id,
            parameterId: AppDatabase.no3Id,
            updatedAt: now,
          ),
          TankParametersCompanion.insert(
            tankId: id,
            parameterId: AppDatabase.po4Id,
            updatedAt: now,
          ),
        ]);
      });
    });
    return id;
  }

  Future<void> updateTank({
    required String tankId,
    required String name,
    String? notes,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw ArgumentError('海缸名称不能为空');
    final count =
        await (_database.update(
          _database.tanks,
        )..where((tank) => tank.id.equals(tankId))).write(
          TanksCompanion(
            name: Value(trimmedName),
            notes: Value(_trimToNull(notes)),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    if (count != 1) throw StateError('海缸不存在');
  }

  Future<void> switchTank(String tankId) async {
    final tank = await (_database.select(
      _database.tanks,
    )..where((tank) => tank.id.equals(tankId))).getSingleOrNull();
    if (tank == null || tank.isArchived) throw StateError('无法切换到不存在或已归档的海缸');
    await _database
        .into(_database.appPreferences)
        .insertOnConflictUpdate(
          AppPreferencesCompanion.insert(
            id: const Value(1),
            currentTankId: Value(tankId),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<void> archiveTank(String tankId) async {
    await _database.transaction(() async {
      final active = await (_database.select(
        _database.tanks,
      )..where((tank) => tank.isArchived.equals(false))).get();
      if (active.length <= 1) throw StateError('至少保留一个未归档海缸');
      final target = active.where((tank) => tank.id == tankId).firstOrNull;
      if (target == null) throw StateError('海缸不存在或已归档');
      final now = DateTime.now().toUtc();
      await (_database.update(
        _database.tanks,
      )..where((tank) => tank.id.equals(tankId))).write(
        TanksCompanion(isArchived: const Value(true), updatedAt: Value(now)),
      );
      final preference = await _database
          .select(_database.appPreferences)
          .getSingle();
      if (preference.currentTankId == tankId) {
        final replacement = active.firstWhere((tank) => tank.id != tankId);
        await _database
            .into(_database.appPreferences)
            .insertOnConflictUpdate(
              AppPreferencesCompanion.insert(
                id: const Value(1),
                currentTankId: Value(replacement.id),
                updatedAt: now,
              ),
            );
      }
    });
  }

  Future<String> createCustomParameter({
    required String tankId,
    required String code,
    required String displayName,
    required String unit,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    final trimmedName = displayName.trim();
    final trimmedUnit = unit.trim();
    if (normalizedCode.isEmpty || trimmedName.isEmpty || trimmedUnit.isEmpty) {
      throw ArgumentError('参数简称、名称和单位均不能为空');
    }
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      final existing = await _database.select(_database.waterParameters).get();
      if (existing.any((item) => item.code.toUpperCase() == normalizedCode)) {
        throw StateError('参数简称已存在');
      }
      await _database
          .into(_database.waterParameters)
          .insert(
            WaterParametersCompanion.insert(
              id: id,
              code: normalizedCode,
              displayName: trimmedName,
              unit: trimmedUnit,
              isBuiltIn: false,
              createdAt: now,
            ),
          );
      await _database
          .into(_database.tankParameters)
          .insert(
            TankParametersCompanion.insert(
              tankId: tankId,
              parameterId: id,
              updatedAt: now,
            ),
          );
    });
    return id;
  }

  Future<void> setParameterEnabled({
    required String tankId,
    required String parameterId,
    required bool enabled,
  }) async {
    await _database.transaction(() async {
      if (!enabled) {
        final enabledRows =
            await (_database.select(_database.tankParameters)..where(
                  (row) =>
                      row.tankId.equals(tankId) & row.isEnabled.equals(true),
                ))
                .get();
        if (enabledRows.length <= 1 &&
            enabledRows.any((row) => row.parameterId == parameterId)) {
          throw StateError('每个海缸至少保留一个启用参数');
        }
      }
      await _database
          .into(_database.tankParameters)
          .insertOnConflictUpdate(
            TankParametersCompanion.insert(
              tankId: tankId,
              parameterId: parameterId,
              isEnabled: Value(enabled),
              updatedAt: DateTime.now().toUtc(),
            ),
          );
    });
  }

  Future<void> setTarget({
    required String tankId,
    required String parameterId,
    required double minValue,
    required double maxValue,
  }) async {
    if (!minValue.isFinite ||
        !maxValue.isFinite ||
        minValue < 0 ||
        maxValue < 0 ||
        minValue > maxValue) {
      throw ArgumentError('目标范围必须为非负数，且下限不能大于上限');
    }
    final parameterQuery =
        _database.select(_database.waterParameters).join([
          innerJoin(
            _database.tankParameters,
            _database.tankParameters.parameterId.equalsExp(
              _database.waterParameters.id,
            ),
          ),
        ])..where(
          _database.waterParameters.id.equals(parameterId) &
              _database.tankParameters.tankId.equals(tankId) &
              _database.tankParameters.isEnabled.equals(true),
        );
    final parameterRow = await parameterQuery.getSingleOrNull();
    if (parameterRow == null) throw StateError('参数未在此海缸启用');
    final parameter = parameterRow.readTable(_database.waterParameters);
    final existing =
        await (_database.select(_database.waterQualityTargets)..where(
              (target) =>
                  target.tankId.equals(tankId) &
                  target.parameterId.equals(parameterId),
            ))
            .getSingleOrNull();
    final now = DateTime.now().toUtc();
    await _database
        .into(_database.waterQualityTargets)
        .insertOnConflictUpdate(
          WaterQualityTargetsCompanion.insert(
            id: existing?.id ?? _uuid.v4(),
            tankId: tankId,
            parameterId: parameterId,
            minValue: minValue,
            maxValue: maxValue,
            unit: parameter.unit,
            updatedAt: now,
          ),
        );
  }
}

String? _trimToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
