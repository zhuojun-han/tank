import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database/app_database.dart';
import '../../test_records/data/local_photo_storage.dart';
import '../domain/test_timer.dart';

enum ActiveTestStage {
  preparation,
  timerRunning,
  timerPaused,
  timerCompleted,
  photoReady,
  review,
}

/// Owns per-tank timer defaults and the unfinished test draft lifecycle.
///
/// An active draft is unique for a tank/parameter pair. Saving or explicitly
/// discarding it removes the draft; neither operation touches another tank's
/// session.
class TestSessionRepository {
  factory TestSessionRepository(
    AppDatabase database, {
    Uuid uuid = const Uuid(),
    DateTime Function()? now,
  }) => TestSessionRepository._(database, uuid, now ?? DateTime.now);

  TestSessionRepository._(this._database, this._uuid, this._now);

  final AppDatabase _database;
  final Uuid _uuid;
  final DateTime Function() _now;

  Stream<int> watchDefaultDurationSeconds({
    required String tankId,
    required String parameterId,
  }) {
    final query = _database.select(_database.testTimerDefaults)
      ..where(
        (row) =>
            row.tankId.equals(tankId) & row.parameterId.equals(parameterId),
      );
    return query.watchSingleOrNull().map(
      (row) => row?.durationSeconds ?? TestTimerSnapshot.initialDurationSeconds,
    );
  }

  Future<int> readDefaultDurationSeconds({
    required String tankId,
    required String parameterId,
  }) async {
    await _requireParameter(tankId, parameterId, requireEnabled: true);
    return _readStoredDefault(tankId, parameterId);
  }

  Future<void> setDefaultDurationSeconds({
    required String tankId,
    required String parameterId,
    required int durationSeconds,
  }) async {
    TestTimerSnapshot.validateDuration(durationSeconds);
    await _requireParameter(tankId, parameterId, requireEnabled: true);
    await _database
        .into(_database.testTimerDefaults)
        .insert(
          TestTimerDefaultsCompanion.insert(
            tankId: tankId,
            parameterId: parameterId,
            durationSeconds: durationSeconds,
            updatedAt: _utcNow(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Stream<ActiveTestSession?> watchDraft({
    required String tankId,
    required String parameterId,
  }) {
    final query = _database.select(_database.activeTestSessions)
      ..where(
        (row) =>
            row.tankId.equals(tankId) & row.parameterId.equals(parameterId),
      );
    return query.watchSingleOrNull();
  }

  Future<ActiveTestSession?> readDraft({
    required String tankId,
    required String parameterId,
  }) {
    final query = _database.select(_database.activeTestSessions)
      ..where(
        (row) =>
            row.tankId.equals(tankId) & row.parameterId.equals(parameterId),
      );
    return query.getSingleOrNull();
  }

  /// Resolves a persisted draft from a notification deep link.
  ///
  /// The returned row still carries its tank id, so all subsequent mutations
  /// continue to use the tank-scoped methods below.
  Stream<ActiveTestSession?> watchDraftById(String sessionId) {
    final normalizedId = sessionId.trim();
    if (normalizedId.isEmpty) {
      return const Stream<ActiveTestSession?>.empty();
    }
    final query = _database.select(_database.activeTestSessions)
      ..where((row) => row.id.equals(normalizedId));
    return query.watchSingleOrNull();
  }

  Future<ActiveTestSession?> readDraftById(String sessionId) {
    final normalizedId = sessionId.trim();
    if (normalizedId.isEmpty) {
      return Future<ActiveTestSession?>.value();
    }
    final query = _database.select(_database.activeTestSessions)
      ..where((row) => row.id.equals(normalizedId));
    return query.getSingleOrNull();
  }

  /// Resolves a notification target only when it belongs to the supplied
  /// tank. Use this whenever a caller already has a tank context.
  Future<ActiveTestSession?> readDraftByIdForTank({
    required String tankId,
    required String sessionId,
  }) {
    final normalizedId = sessionId.trim();
    if (normalizedId.isEmpty) return Future<ActiveTestSession?>.value();
    final query = _database.select(_database.activeTestSessions)
      ..where((row) => row.id.equals(normalizedId) & row.tankId.equals(tankId));
    return query.getSingleOrNull();
  }

  Future<String> createDraft({
    required String tankId,
    required String parameterId,
    String? reagentProfileId,
    DateTime? startedAt,
  }) async {
    await _requireParameter(tankId, parameterId, requireEnabled: true);
    await _requireMatchingReagent(
      reagentProfileId,
      parameterId,
      requireEnabled: true,
    );
    if (await readDraft(tankId: tankId, parameterId: parameterId) != null) {
      throw StateError('此海缸和参数已有未完成检测草稿');
    }
    final now = _utcNow();
    final id = _uuid.v4();
    final duration = await _readStoredDefault(tankId, parameterId);
    TestTimerSnapshot.validateDuration(duration);
    await _database
        .into(_database.activeTestSessions)
        .insert(
          ActiveTestSessionsCompanion.insert(
            id: id,
            tankId: tankId,
            parameterId: parameterId,
            reagentProfileId: Value(reagentProfileId),
            startedAt: (startedAt ?? now).toUtc(),
            timerDurationSeconds: duration,
            stage: ActiveTestStage.preparation.name,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// Replaces the persisted timer state. The duration copied into the draft
  /// is never changed here, so changing a default cannot alter a running test.
  Future<void> updateTimer({
    required String tankId,
    required String sessionId,
    required DateTime startedAt,
    DateTime? timerEndsAt,
    int? pausedRemainingSeconds,
    required ActiveTestStage stage,
  }) async {
    final session = await _requireDraft(tankId: tankId, sessionId: sessionId);
    _validateTimerState(
      durationSeconds: session.timerDurationSeconds,
      timerEndsAt: timerEndsAt,
      pausedRemainingSeconds: pausedRemainingSeconds,
      stage: stage,
    );
    final changed =
        await (_database.update(_database.activeTestSessions)..where(
              (row) => row.id.equals(sessionId) & row.tankId.equals(tankId),
            ))
            .write(
              ActiveTestSessionsCompanion(
                startedAt: Value(startedAt.toUtc()),
                timerEndsAt: Value(timerEndsAt?.toUtc()),
                pausedRemainingSeconds: Value(pausedRemainingSeconds),
                stage: Value(stage.name),
                updatedAt: Value(_utcNow()),
              ),
            );
    if (changed != 1) throw StateError('检测草稿不存在或不属于此海缸');
  }

  /// A stale UI snapshot must not complete a restarted or already advanced draft.
  /// The conditional write also makes concurrent expiry callbacks idempotent.
  Future<bool> completeElapsedTimer({
    required String tankId,
    required String sessionId,
    required DateTime expectedEndsAt,
    required DateTime now,
  }) async {
    if (expectedEndsAt.isAfter(now)) return false;
    final changed =
        await (_database.update(_database.activeTestSessions)..where(
              (row) =>
                  row.id.equals(sessionId) &
                  row.tankId.equals(tankId) &
                  row.stage.equals(ActiveTestStage.timerRunning.name) &
                  row.timerEndsAt.equals(expectedEndsAt.toUtc()),
            ))
            .write(
              ActiveTestSessionsCompanion(
                timerEndsAt: const Value(null),
                pausedRemainingSeconds: const Value(null),
                stage: Value(ActiveTestStage.timerCompleted.name),
                updatedAt: Value(now.toUtc()),
              ),
            );
    return changed == 1;
  }

  Future<void> updatePhoto({
    required String tankId,
    required String sessionId,
    String? photoPath,
  }) async {
    await _requireDraft(tankId: tankId, sessionId: sessionId);
    final normalizedPhotoPath = _normalizeRelativePhotoPath(photoPath);
    final changed =
        await (_database.update(_database.activeTestSessions)..where(
              (row) => row.id.equals(sessionId) & row.tankId.equals(tankId),
            ))
            .write(
              ActiveTestSessionsCompanion(
                draftPhotoPath: Value(normalizedPhotoPath),
                updatedAt: Value(_utcNow()),
              ),
            );
    if (changed != 1) throw StateError('检测草稿不存在或不属于此海缸');
  }

  /// Persists the review form and provisional estimation output without
  /// creating a formal test record. This makes an unfinished review resumable
  /// after navigation or process restart.
  Future<void> updateReviewDraft({
    required String tankId,
    required String sessionId,
    double? confirmedMinValue,
    double? confirmedMaxValue,
    double? confirmedInterpolation,
    double? estimatedInterpolation,
    DateTime? confirmedAt,
    String? notes,
    DateTime? capturedAt,
    double? estimatedMinValue,
    double? estimatedMaxValue,
    String? estimationMethod,
    String? estimationVersion,
    double? qualityScore,
    String? confidence,
    String? failureReason,
  }) async {
    _validatePoint(
      confirmedMinValue,
      confirmedMaxValue,
      confirmedInterpolation,
    );
    if (confirmedMinValue == null && confirmedMaxValue != null) {
      throw ArgumentError('草稿确认范围缺少最小值');
    }
    if (confirmedMinValue != null) {
      _validateRange(confirmedMinValue, confirmedMaxValue, '草稿确认值');
    }
    if (estimatedMinValue == null && estimatedMaxValue != null) {
      throw ArgumentError('草稿算法估值范围缺少最小值');
    }
    if (estimatedMinValue != null) {
      _validateRange(estimatedMinValue, estimatedMaxValue, '草稿算法估值');
    }
    _validateEstimationMetadata(
      qualityScore: qualityScore,
      confidence: confidence,
    );
    await _requireDraft(tankId: tankId, sessionId: sessionId);
    final changed =
        await (_database.update(_database.activeTestSessions)..where(
              (row) => row.id.equals(sessionId) & row.tankId.equals(tankId),
            ))
            .write(
              ActiveTestSessionsCompanion(
                draftCapturedAt: Value(capturedAt?.toUtc()),
                draftEstimatedMinValue: Value(estimatedMinValue),
                draftEstimatedMaxValue: Value(estimatedMaxValue),
                draftEstimationMethod: Value(_emptyToNull(estimationMethod)),
                draftEstimationVersion: Value(_emptyToNull(estimationVersion)),
                draftQualityScore: Value(qualityScore),
                draftConfidence: Value(_emptyToNull(confidence)),
                draftFailureReason: Value(_emptyToNull(failureReason)),
                draftConfirmedMinValue: Value(confirmedMinValue),
                draftConfirmedMaxValue: Value(confirmedMaxValue),
                draftConfirmedInterpolation: Value(confirmedInterpolation),
                draftEstimatedInterpolation: Value(estimatedInterpolation),
                draftConfirmedAt: Value(confirmedAt?.toUtc()),
                draftNotes: Value(_emptyToNull(notes)),
                stage: Value(ActiveTestStage.review.name),
                updatedAt: Value(_utcNow()),
              ),
            );
    if (changed != 1) throw StateError('检测草稿不存在或不属于此海缸');
  }

  Future<void> updateStage({
    required String tankId,
    required String sessionId,
    required ActiveTestStage stage,
  }) async {
    await _requireDraft(tankId: tankId, sessionId: sessionId);
    final changed =
        await (_database.update(_database.activeTestSessions)..where(
              (row) => row.id.equals(sessionId) & row.tankId.equals(tankId),
            ))
            .write(
              ActiveTestSessionsCompanion(
                stage: Value(stage.name),
                updatedAt: Value(_utcNow()),
              ),
            );
    if (changed != 1) throw StateError('检测草稿不存在或不属于此海缸');
  }

  /// Deletes the draft row and returns its metadata so a higher layer can
  /// remove the retained photo only after the database transaction succeeds.
  Future<ActiveTestSession> discardDraft({
    required String tankId,
    required String sessionId,
  }) {
    return _database.transaction(() async {
      final session = await _requireDraft(tankId: tankId, sessionId: sessionId);
      final deleted =
          await (_database.delete(_database.activeTestSessions)..where(
                (row) => row.id.equals(sessionId) & row.tankId.equals(tankId),
              ))
              .go();
      if (deleted != 1) throw StateError('检测草稿不存在或不属于此海缸');
      return session;
    });
  }

  Future<String> saveDraftAsRecord({
    required String tankId,
    required String sessionId,
    required double confirmedMinValue,
    double? confirmedMaxValue,
    double? confirmedInterpolation,
    double? estimatedInterpolation,
    DateTime? confirmedAt,
    DateTime? capturedAt,
    String? notes,
    double? estimatedMinValue,
    double? estimatedMaxValue,
    String? estimationMethod,
    String? estimationVersion,
    double? qualityScore,
    String? confidence,
    String? failureReason,
  }) async {
    _validateRange(confirmedMinValue, confirmedMaxValue, '确认值');
    _validatePoint(
      confirmedMinValue,
      confirmedMaxValue,
      confirmedInterpolation,
    );
    if (estimatedMinValue != null || estimatedMaxValue != null) {
      if (estimatedMinValue == null) {
        throw ArgumentError('算法估值范围缺少最小值');
      }
      _validateRange(estimatedMinValue, estimatedMaxValue, '算法估值');
    }
    _validateEstimationMetadata(
      qualityScore: qualityScore,
      confidence: confidence,
    );

    return _database.transaction(() async {
      final session = await _requireDraft(tankId: tankId, sessionId: sessionId);
      final parameter = await _requireParameter(
        tankId,
        session.parameterId,
        requireEnabled: true,
      );
      await _requireMatchingReagent(
        session.reagentProfileId,
        session.parameterId,
        requireEnabled: true,
      );
      final resolvedCapturedAt = capturedAt ?? session.draftCapturedAt;
      final resolvedEstimatedMin =
          estimatedMinValue ?? session.draftEstimatedMinValue;
      final resolvedEstimatedMax =
          estimatedMaxValue ?? session.draftEstimatedMaxValue;
      final resolvedEstimationMethod =
          _emptyToNull(estimationMethod) ?? session.draftEstimationMethod;
      final resolvedEstimationVersion =
          _emptyToNull(estimationVersion) ?? session.draftEstimationVersion;
      final resolvedQualityScore = qualityScore ?? session.draftQualityScore;
      final resolvedConfidence =
          _emptyToNull(confidence) ?? session.draftConfidence;
      final resolvedFailureReason =
          _emptyToNull(failureReason) ?? session.draftFailureReason;
      final resolvedNotes = _emptyToNull(notes) ?? session.draftNotes;
      if (resolvedEstimatedMin != null || resolvedEstimatedMax != null) {
        if (resolvedEstimatedMin == null) {
          throw StateError('检测草稿的算法估值范围缺少最小值');
        }
        _validateRange(resolvedEstimatedMin, resolvedEstimatedMax, '算法估值');
      }
      _validateEstimationMetadata(
        qualityScore: resolvedQualityScore,
        confidence: resolvedConfidence,
      );
      final now = _utcNow();
      final recordId = _uuid.v4();
      final confirmedAtUtc =
          confirmedAt?.toUtc() ?? session.draftConfirmedAt ?? _utcNow();
      await _database
          .into(_database.testRecords)
          .insert(
            TestRecordsCompanion.insert(
              id: recordId,
              tankId: tankId,
              parameterId: session.parameterId,
              reagentProfileId: Value(session.reagentProfileId),
              capturedAt: Value(resolvedCapturedAt?.toUtc()),
              estimatedMinValue: Value(resolvedEstimatedMin),
              estimatedMaxValue: Value(resolvedEstimatedMax),
              estimationMethod: Value(resolvedEstimationMethod),
              estimationVersion: Value(resolvedEstimationVersion),
              qualityScore: Value(resolvedQualityScore),
              confidence: Value(resolvedConfidence),
              failureReason: Value(resolvedFailureReason),
              confirmedMinValue: confirmedMinValue,
              confirmedMaxValue: Value(confirmedMaxValue),
              confirmedInterpolation: Value(confirmedInterpolation),
              estimatedInterpolation: Value(
                session.draftEstimatedInterpolation,
              ),
              unit: parameter.unit,
              measuredAt: confirmedAtUtc,
              confirmedAt: Value(confirmedAtUtc),
              notes: Value(resolvedNotes),
              // Photos are temporary comparison artifacts and never become
              // part of the durable measurement record.
              photoPath: const Value(null),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final deleted =
          await (_database.delete(_database.activeTestSessions)..where(
                (row) => row.id.equals(sessionId) & row.tankId.equals(tankId),
              ))
              .go();
      if (deleted != 1) throw StateError('保存时检测草稿状态发生变化');
      return recordId;
    });
  }

  Future<int> _readStoredDefault(String tankId, String parameterId) async {
    final query = _database.select(_database.testTimerDefaults)
      ..where(
        (row) =>
            row.tankId.equals(tankId) & row.parameterId.equals(parameterId),
      );
    return (await query.getSingleOrNull())?.durationSeconds ??
        TestTimerSnapshot.initialDurationSeconds;
  }

  Future<ActiveTestSession> _requireDraft({
    required String tankId,
    required String sessionId,
  }) async {
    final query = _database.select(_database.activeTestSessions)
      ..where((row) => row.id.equals(sessionId) & row.tankId.equals(tankId));
    final session = await query.getSingleOrNull();
    if (session == null) throw StateError('检测草稿不存在或不属于此海缸');
    return session;
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

  void _validateTimerState({
    required int durationSeconds,
    required DateTime? timerEndsAt,
    required int? pausedRemainingSeconds,
    required ActiveTestStage stage,
  }) {
    TestTimerSnapshot.validateDuration(durationSeconds);
    if (pausedRemainingSeconds != null &&
        (pausedRemainingSeconds < 0 ||
            pausedRemainingSeconds > durationSeconds)) {
      throw ArgumentError.value(
        pausedRemainingSeconds,
        'pausedRemainingSeconds',
        '暂停剩余时间无效',
      );
    }
    switch (stage) {
      case ActiveTestStage.timerRunning:
        if (timerEndsAt == null || pausedRemainingSeconds != null) {
          throw ArgumentError('运行中计时必须有结束时间且不能有暂停剩余时间');
        }
        break;
      case ActiveTestStage.timerPaused:
        if (timerEndsAt != null ||
            pausedRemainingSeconds == null ||
            pausedRemainingSeconds <= 0) {
          throw ArgumentError('暂停计时必须仅保存正数剩余秒数');
        }
        break;
      case ActiveTestStage.timerCompleted:
        if (timerEndsAt != null || pausedRemainingSeconds != null) {
          throw ArgumentError('已完成计时不能保留结束时间或暂停秒数');
        }
        break;
      case ActiveTestStage.preparation:
      case ActiveTestStage.photoReady:
      case ActiveTestStage.review:
        if (timerEndsAt != null && pausedRemainingSeconds != null) {
          throw ArgumentError('计时结束时间和暂停剩余时间不能同时存在');
        }
        break;
    }
  }

  void _validateRange(double min, double? max, String label) {
    if (!min.isFinite ||
        min < 0 ||
        (max != null && (!max.isFinite || max < 0 || max < min))) {
      throw ArgumentError('$label范围无效');
    }
  }

  void _validateEstimationMetadata({
    required double? qualityScore,
    required String? confidence,
  }) {
    if (qualityScore != null &&
        (!qualityScore.isFinite || qualityScore < 0 || qualityScore > 1)) {
      throw ArgumentError.value(qualityScore, 'qualityScore', '质量评分必须在 0 到 1');
    }
    final normalizedConfidence = _emptyToNull(confidence);
    if (normalizedConfidence != null &&
        !const {'low', 'medium', 'high'}.contains(normalizedConfidence)) {
      throw ArgumentError.value(confidence, 'confidence', '置信度标签无效');
    }
  }

  DateTime _utcNow() => _now().toUtc();
}

String? _emptyToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String? _normalizeRelativePhotoPath(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final normalized = normalizeManagedPhotoReference(value);
  if (normalized == null) {
    throw ArgumentError.value(value, 'photoPath', '照片路径必须位于应用私有目录内');
  }
  return normalized;
}

void _validatePoint(double? min, double? max, double? point) {
  if (point != null &&
      (min == null || !point.isFinite || point < min || point > (max ?? min))) {
    throw ArgumentError('插值必须在范围内');
  }
}
