import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database/app_database.dart';

class TestRecordRepository {
  TestRecordRepository(this._database, [this._uuid = const Uuid()]);

  final AppDatabase _database;
  final Uuid _uuid;

  /// Overview and advice only need the latest record for each parameter.
  Stream<List<TestRecord>> watchLatestForTank(String tankId) => _database
      .customSelect(
        'SELECT * FROM (SELECT r.*, ROW_NUMBER() OVER ('
        'PARTITION BY parameter_id ORDER BY measured_at DESC, updated_at DESC, id DESC'
        ') AS history_rank FROM test_records r WHERE tank_id = ?) '
        'WHERE history_rank = 1',
        variables: [Variable<String>(tankId)],
        readsFrom: {_database.testRecords},
      )
      .watch()
      .map(
        (rows) => [for (final row in rows) _database.testRecords.map(row.data)],
      );

  Stream<List<TestRecord>> watchForTank(String tankId) {
    return (_database.select(_database.testRecords)
          ..where((row) => row.tankId.equals(tankId))
          ..orderBy([
            (row) => OrderingTerm.desc(row.measuredAt),
            (row) => OrderingTerm.desc(row.updatedAt),
          ]))
        .watch();
  }

  Stream<TestRecord?> watchById({required String tankId, required String id}) {
    return (_database.select(_database.testRecords)
          ..where((row) => row.id.equals(id) & row.tankId.equals(tankId)))
        .watchSingleOrNull();
  }

  Future<TestRecord?> readById({required String tankId, required String id}) {
    return (_database.select(_database.testRecords)
          ..where((row) => row.id.equals(id) & row.tankId.equals(tankId)))
        .getSingleOrNull();
  }

  Stream<List<ReagentProfile>> watchReagentsForParameter(
    String parameterId, {
    bool includeDisabled = false,
  }) {
    final query = _database.select(_database.reagentProfiles)
      ..where(
        (row) =>
            row.parameterId.equals(parameterId) &
            (includeDisabled
                ? const Constant(true)
                : row.isEnabled.equals(true)),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.brand)]);
    return query.watch();
  }

  Future<String> createManual({
    required String tankId,
    required String parameterId,
    String? reagentProfileId,
    required double confirmedMinValue,
    double? confirmedMaxValue,
    double? confirmedInterpolation,
    required DateTime measuredAt,
    String? notes,
  }) async {
    _validateValues(confirmedMinValue, confirmedMaxValue);
    validateInterpolation(
      confirmedMinValue,
      confirmedMaxValue,
      confirmedInterpolation,
    );
    final parameter = await _requireParameter(
      tankId,
      parameterId,
      requireEnabled: true,
    );
    await _requireMatchingReagent(
      reagentProfileId,
      parameterId,
      requireEnabled: true,
    );
    final now = DateTime.now().toUtc();
    final confirmedAt = measuredAt.toUtc();
    final id = _uuid.v4();
    await _database
        .into(_database.testRecords)
        .insert(
          TestRecordsCompanion.insert(
            id: id,
            tankId: tankId,
            parameterId: parameterId,
            reagentProfileId: Value(reagentProfileId),
            confirmedMinValue: confirmedMinValue,
            confirmedMaxValue: Value(confirmedMaxValue),
            confirmedInterpolation: Value(confirmedInterpolation),
            unit: parameter.unit,
            measuredAt: confirmedAt,
            confirmedAt: Value(confirmedAt),
            notes: Value(_emptyToNull(notes)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> updateConfirmed({
    required String id,
    required String tankId,
    required double confirmedMinValue,
    double? confirmedMaxValue,
    double? confirmedInterpolation,
    required DateTime measuredAt,
    String? notes,
  }) async {
    _validateValues(confirmedMinValue, confirmedMaxValue);
    validateInterpolation(
      confirmedMinValue,
      confirmedMaxValue,
      confirmedInterpolation,
    );
    final record = await _requireRecord(id: id, tankId: tankId);
    final confirmedAt = measuredAt.toUtc();
    final changed =
        await (_database.update(_database.testRecords)..where(
              (row) => row.id.equals(id) & row.tankId.equals(record.tankId),
            ))
            .write(
              TestRecordsCompanion(
                confirmedMinValue: Value(confirmedMinValue),
                confirmedMaxValue: Value(confirmedMaxValue),
                confirmedInterpolation: Value(confirmedInterpolation),
                measuredAt: Value(confirmedAt),
                confirmedAt: Value(confirmedAt),
                notes: Value(_emptyToNull(notes)),
                wasManuallyEdited: const Value(true),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
    if (changed != 1) throw StateError('检测记录不存在');
  }

  /// Edits the user-owned fields while intentionally leaving the captured
  /// photo timestamp and all original estimation fields untouched.
  Future<void> editRecord({
    required String id,
    required String sourceTankId,
    required String targetTankId,
    required String parameterId,
    String? reagentProfileId,
    required double confirmedMinValue,
    double? confirmedMaxValue,
    double? confirmedInterpolation,
    required DateTime confirmedAt,
    String? notes,
  }) async {
    _validateValues(confirmedMinValue, confirmedMaxValue);
    validateInterpolation(
      confirmedMinValue,
      confirmedMaxValue,
      confirmedInterpolation,
    );
    await _requireRecord(id: id, tankId: sourceTankId);
    final parameter = await _requireParameter(
      targetTankId,
      parameterId,
      requireEnabled: false,
    );
    await _requireMatchingReagent(
      reagentProfileId,
      parameterId,
      requireEnabled: false,
    );
    final confirmedAtUtc = confirmedAt.toUtc();
    final changed =
        await (_database.update(_database.testRecords)..where(
              (row) => row.id.equals(id) & row.tankId.equals(sourceTankId),
            ))
            .write(
              TestRecordsCompanion(
                tankId: Value(targetTankId),
                parameterId: Value(parameterId),
                reagentProfileId: Value(reagentProfileId),
                confirmedMinValue: Value(confirmedMinValue),
                confirmedMaxValue: Value(confirmedMaxValue),
                confirmedInterpolation: Value(confirmedInterpolation),
                unit: Value(parameter.unit),
                measuredAt: Value(confirmedAtUtc),
                confirmedAt: Value(confirmedAtUtc),
                notes: Value(_emptyToNull(notes)),
                wasManuallyEdited: const Value(true),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
    if (changed != 1) throw StateError('检测记录不存在或不属于此海缸');
  }

  /// Detaches the retained photo without deleting the numeric record or any
  /// algorithm metadata. File deletion is handled separately by the caller.
  Future<void> clearPhoto({required String id, required String tankId}) async {
    final changed =
        await (_database.update(
          _database.testRecords,
        )..where((row) => row.id.equals(id) & row.tankId.equals(tankId))).write(
          TestRecordsCompanion(
            photoPath: const Value(null),
            wasManuallyEdited: const Value(true),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    if (changed != 1) throw StateError('检测记录不存在或不属于此海缸');
  }

  /// Deletes only the database row and returns its metadata (including the
  /// former photo path). The caller may delete the file after this succeeds;
  /// a database failure therefore never removes the file first.
  Future<TestRecord> deleteRecord({
    required String id,
    required String tankId,
  }) {
    return _database.transaction(() async {
      final record = await _requireRecord(id: id, tankId: tankId);
      final deleted = await (_database.delete(
        _database.testRecords,
      )..where((row) => row.id.equals(id) & row.tankId.equals(tankId))).go();
      if (deleted != 1) throw StateError('检测记录不存在或不属于此海缸');
      return record;
    });
  }

  Future<TestRecord> _requireRecord({
    required String id,
    String? tankId,
  }) async {
    final query = _database.select(_database.testRecords)
      ..where((row) {
        final idMatches = row.id.equals(id);
        return tankId == null
            ? idMatches
            : idMatches & row.tankId.equals(tankId);
      });
    final record = await query.getSingleOrNull();
    if (record == null) throw StateError('检测记录不存在或不属于此海缸');
    return record;
  }

  Future<WaterParameter> _requireParameter(
    String tankId,
    String parameterId, {
    required bool requireEnabled,
  }) async {
    final query =
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
              (requireEnabled
                  ? _database.tankParameters.isEnabled.equals(true)
                  : const Constant(true)),
        );
    final association = await query.getSingleOrNull();
    if (association == null) {
      throw StateError(requireEnabled ? '参数未在此海缸启用' : '参数不属于此海缸');
    }
    return association.readTable(_database.waterParameters);
  }

  Future<void> _requireMatchingReagent(
    String? reagentProfileId,
    String parameterId, {
    required bool requireEnabled,
  }) async {
    if (reagentProfileId == null) return;
    final query = _database.select(_database.reagentProfiles)
      ..where(
        (row) =>
            row.id.equals(reagentProfileId) &
            row.parameterId.equals(parameterId) &
            (requireEnabled
                ? row.isEnabled.equals(true)
                : const Constant(true)),
      );
    if (await query.getSingleOrNull() == null) {
      throw StateError('试剂与检测参数不匹配或不可用');
    }
  }

  void _validateValues(double min, double? max) {
    if (!min.isFinite ||
        min < 0 ||
        (max != null && (!max.isFinite || max < 0 || max < min))) {
      throw ArgumentError('检测值范围无效');
    }
  }
}

String? _emptyToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

void validateInterpolation(double min, double? max, double? point) {
  if (point != null &&
      (!point.isFinite || point < min || point > (max ?? min))) {
    throw ArgumentError('插值必须在范围内');
  }
}
