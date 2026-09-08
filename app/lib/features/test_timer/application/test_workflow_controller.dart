import '../../../core/notifications/local_notification.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../data/database/app_database.dart';
import '../../image_estimation/domain/photo_capture_models.dart';
import '../../test_records/data/local_photo_storage.dart';
import '../data/test_session_repository.dart';

class TestWorkflowOperationResult {
  const TestWorkflowOperationResult({this.notificationResult});

  final NotificationOperationResult? notificationResult;

  bool get notificationUnavailable =>
      notificationResult != null && !notificationResult!.succeeded;
}

/// Coordinates the persisted draft, short timer notification and private
/// photo lifecycle. UI code never schedules a notification or deletes a file
/// directly.
class TestWorkflowController {
  factory TestWorkflowController({
    required TestSessionRepository repository,
    required LocalNotificationService notifications,
    required LocalPhotoStorage photoStorage,
    DateTime Function()? now,
  }) => TestWorkflowController._(
    repository,
    notifications,
    photoStorage,
    now ?? DateTime.now,
  );

  TestWorkflowController._(
    this._repository,
    this._notifications,
    this._photoStorage,
    this._now,
  );

  final TestSessionRepository _repository;
  final LocalNotificationService _notifications;
  final LocalPhotoStorage _photoStorage;
  final DateTime Function() _now;

  Future<void> setDefaultDuration({
    required String tankId,
    required String parameterId,
    required int seconds,
  }) {
    return _repository.setDefaultDurationSeconds(
      tankId: tankId,
      parameterId: parameterId,
      durationSeconds: seconds,
    );
  }

  /// KH uses a syringe reading immediately. Switching to it stops countdowns
  /// for this tank while keeping their unfinished inputs available to resume.
  Future<void> prepareKhTitration(String tankId) async {
    for (final session in await _repository.readRunningTimersForTank(tankId)) {
      await reset(session);
    }
  }

  Future<String> createDraft({
    required String tankId,
    required String parameterId,
    String? reagentProfileId,
  }) {
    return _repository.createDraft(
      tankId: tankId,
      parameterId: parameterId,
      reagentProfileId: reagentProfileId,
      startedAt: _now(),
    );
  }

  Future<TestWorkflowOperationResult> start(ActiveTestSession session) async {
    final now = _now().toUtc();
    final endsAt = now.add(Duration(seconds: session.timerDurationSeconds));
    await _repository.updateTimer(
      tankId: session.tankId,
      sessionId: session.id,
      startedAt: now,
      timerEndsAt: endsAt,
      stage: ActiveTestStage.timerRunning,
    );
    return _scheduleTimer(session, endsAt);
  }

  Future<TestWorkflowOperationResult> pause(ActiveTestSession session) async {
    final now = _now().toUtc();
    final endsAt = session.timerEndsAt;
    final remaining = endsAt == null
        ? 0
        : (endsAt.difference(now).inMilliseconds /
                  Duration.millisecondsPerSecond)
              .ceil()
              .clamp(0, session.timerDurationSeconds)
              .toInt();
    if (remaining == 0) return complete(session);
    await _repository.updateTimer(
      tankId: session.tankId,
      sessionId: session.id,
      startedAt: session.startedAt,
      pausedRemainingSeconds: remaining,
      stage: ActiveTestStage.timerPaused,
    );
    final result = await _cancelTimer(session.id);
    return TestWorkflowOperationResult(notificationResult: result);
  }

  Future<TestWorkflowOperationResult> resume(ActiveTestSession session) async {
    final remaining = session.pausedRemainingSeconds ?? 0;
    if (remaining <= 0) return complete(session);
    final now = _now().toUtc();
    final endsAt = now.add(Duration(seconds: remaining));
    await _repository.updateTimer(
      tankId: session.tankId,
      sessionId: session.id,
      startedAt: session.startedAt,
      timerEndsAt: endsAt,
      stage: ActiveTestStage.timerRunning,
    );
    return _scheduleTimer(session, endsAt);
  }

  Future<TestWorkflowOperationResult> reset(ActiveTestSession session) async {
    await _repository.updateTimer(
      tankId: session.tankId,
      sessionId: session.id,
      startedAt: _now(),
      stage: ActiveTestStage.preparation,
    );
    final result = await _cancelTimer(session.id);
    return TestWorkflowOperationResult(notificationResult: result);
  }

  Future<TestWorkflowOperationResult> complete(
    ActiveTestSession session,
  ) async {
    await _repository.updateTimer(
      tankId: session.tankId,
      sessionId: session.id,
      startedAt: session.startedAt,
      stage: ActiveTestStage.timerCompleted,
    );
    final result = await _cancelTimer(session.id);
    return TestWorkflowOperationResult(notificationResult: result);
  }

  Future<bool> completeElapsed(ActiveTestSession session) async {
    final endsAt = session.timerEndsAt;
    if (session.stage != ActiveTestStage.timerRunning.name || endsAt == null) {
      return false;
    }
    final changed = await _repository.completeElapsedTimer(
      tankId: session.tankId,
      sessionId: session.id,
      expectedEndsAt: endsAt,
      now: _now().toUtc(),
    );
    if (changed) await _cancelTimer(session.id);
    return changed;
  }

  Future<void> preparePhoto(ActiveTestSession session) async {
    await complete(session);
    return _repository.updateStage(
      tankId: session.tankId,
      sessionId: session.id,
      stage: ActiveTestStage.photoReady,
    );
  }

  Future<void> applyPhotoDraft({
    required ActiveTestSession session,
    required PhotoEstimationDraft draft,
  }) async {
    if (draft.tankId != session.tankId ||
        draft.parameterId != session.parameterId) {
      throw StateError('拍照结果与当前检测草稿不匹配');
    }
    await _repository.updatePhoto(
      tankId: session.tankId,
      sessionId: session.id,
      photoPath: draft.photoRelativePath,
    );
    final selection = draft.manualSelection;
    final match = draft.colorMatch;
    await _repository.updateReviewDraft(
      tankId: session.tankId,
      sessionId: session.id,
      capturedAt: draft.photoCapturedAtUtc,
      estimatedMinValue: match?.low,
      estimatedMaxValue: match?.high,
      estimatedInterpolation: match?.interpolation,
      confirmedInterpolation: match?.interpolation == null
          ? null
          : double.parse(match!.interpolation!.toStringAsFixed(3)),
      estimationMethod: match == null
          ? null
          : 'lab-segment-linear-uncalibrated',
      estimationVersion: match == null ? null : 'web-parity-2026-09-08',
      confirmedMinValue: match?.low ?? selection?.minimum,
      confirmedMaxValue: match != null
          ? match.high
          : selection == null || selection.maximum == selection.minimum
          ? null
          : selection.maximum,
      confirmedAt: _now(),
      failureReason: match == null
          ? _photoFailureReason(draft)
          : <dynamic>{
              ...match.nearestReasons,
              ...match.rangeReasons,
              ...match.interpolationReasons,
            }.join('；'),
    );
  }

  Future<void> useManualEntry(ActiveTestSession session) async {
    await complete(session);
    return _repository.updateReviewDraft(
      tankId: session.tankId,
      sessionId: session.id,
      confirmedAt: _now(),
      failureReason: '未运行拍照算法；本次结果由用户手动确认',
    );
  }

  Future<void> persistReview({
    required ActiveTestSession session,
    double? confirmedMinValue,
    double? confirmedMaxValue,
    double? confirmedInterpolation,
    DateTime? confirmedAt,
    String? notes,
  }) {
    return _repository.updateReviewDraft(
      tankId: session.tankId,
      sessionId: session.id,
      capturedAt: session.draftCapturedAt,
      estimatedMinValue: session.draftEstimatedMinValue,
      estimatedMaxValue: session.draftEstimatedMaxValue,
      estimatedInterpolation: session.draftEstimatedInterpolation,
      estimationMethod: session.draftEstimationMethod,
      estimationVersion: session.draftEstimationVersion,
      qualityScore: session.draftQualityScore,
      confidence: session.draftConfidence,
      failureReason: session.draftFailureReason,
      confirmedMinValue: confirmedMinValue,
      confirmedMaxValue: confirmedMaxValue,
      confirmedInterpolation: confirmedInterpolation,
      confirmedAt: confirmedAt ?? session.draftConfirmedAt,
      notes: notes,
    );
  }

  Future<String> save({
    required ActiveTestSession session,
    required double confirmedMinValue,
    double? confirmedMaxValue,
    double? confirmedInterpolation,
    DateTime? confirmedAt,
    String? notes,
  }) async {
    await _cancelTimer(session.id);
    final recordId = await _repository.saveDraftAsRecord(
      tankId: session.tankId,
      sessionId: session.id,
      confirmedMinValue: confirmedMinValue,
      confirmedMaxValue: confirmedMaxValue,
      confirmedInterpolation: confirmedInterpolation,
      confirmedAt: confirmedAt,
      notes: notes,
    );
    // Current captures never reach the draft. This only cleans a legacy draft
    // photo after its structured values have been saved successfully.
    await _photoStorage.deletePrivatePhoto(session.draftPhotoPath);
    return recordId;
  }

  /// Returns false only when the database draft was removed but its retained
  /// private photo could not be removed. That warning must remain visible.
  Future<bool> discard(ActiveTestSession session) async {
    await _cancelTimer(session.id);
    final discarded = await _repository.discardDraft(
      tankId: session.tankId,
      sessionId: session.id,
    );
    return _photoStorage.deletePrivatePhoto(discarded.draftPhotoPath);
  }

  Future<TestWorkflowOperationResult> _scheduleTimer(
    ActiveTestSession session,
    DateTime endsAt,
  ) async {
    await _notifications.initialize();
    final result = await _notifications.scheduleAtUtc(
      LocalNotificationRequest.testTimer(
        id: testTimerNotificationId(session.id),
        sessionId: session.id,
        title: '检测计时完成',
        body: '请返回 App 继续拍照或手动录入。',
      ),
      endsAt.toUtc(),
    );
    return TestWorkflowOperationResult(notificationResult: result);
  }

  Future<NotificationOperationResult> _cancelTimer(String sessionId) async {
    await _notifications.initialize();
    return _notifications.cancel(testTimerNotificationId(sessionId));
  }

  static String _photoFailureReason(PhotoEstimationDraft draft) {
    if (draft.manualSelection != null) {
      return '本次数值来自人工比色';
    }
    return switch (draft.fallbackReason) {
      PhotoFallbackReason.userChoseManual => '用户选择手动录入',
      PhotoFallbackReason.unsupportedParameter => '当前参数不支持拍照流程',
      PhotoFallbackReason.cameraPermissionDenied => '相机权限未授予',
      PhotoFallbackReason.cameraUnavailable => '相机不可用',
      PhotoFallbackReason.qualityRejected => '拍照质量检查未通过',
      null => '未产生算法估值',
    };
  }
}

/// Stable 31-bit FNV-1a id, namespaced away from the positive maintenance id
/// range. It remains identical after process restart without storing another
/// mutable field in the session row.
int testTimerNotificationId(String sessionId) {
  var hash = 0x811c9dc5;
  for (final unit in sessionId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x3fffffff;
  }
  return 0x40000000 | hash;
}
