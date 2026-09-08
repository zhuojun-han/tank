import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/core/notifications/local_notification.dart';
import 'package:lanjiao_water_quality/core/notifications/local_notification_service.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/test_records/data/local_photo_storage.dart';
import 'package:lanjiao_water_quality/features/test_timer/application/test_workflow_controller.dart';
import 'package:lanjiao_water_quality/features/test_timer/data/test_session_repository.dart';

void main() {
  late AppDatabase database;
  late DateTime clock;
  late TestSessionRepository repository;
  late _FakeNotifications notifications;
  late _FakePhotoStorage photos;
  late TestWorkflowController controller;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    clock = DateTime.utc(2026, 8, 12, 2);
    repository = TestSessionRepository(database, now: () => clock);
    notifications = _FakeNotifications();
    photos = _FakePhotoStorage();
    controller = TestWorkflowController(
      repository: repository,
      notifications: notifications,
      photoStorage: photos,
      now: () => clock,
    );
  });

  tearDown(() async {
    await notifications.dispose();
    await database.close();
  });

  test('计时状态先持久化，通知拒绝不破坏计时', () async {
    notifications.scheduleResult =
        const NotificationOperationResult.permissionDenied();
    final sessionId = await controller.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
      reagentProfileId: AppDatabase.ealNo3ReagentId,
    );
    final session = (await repository.readDraftById(sessionId))!;

    final result = await controller.start(session);

    final running = (await repository.readDraftById(sessionId))!;
    expect(running.stage, ActiveTestStage.timerRunning.name);
    expect(
      running.timerEndsAt?.isAtSameMomentAs(
        clock.add(const Duration(minutes: 5)),
      ),
      isTrue,
    );
    expect(result.notificationUnavailable, isTrue);
    expect(notifications.lastRequest?.payload.targetId, sessionId);
    expect(notifications.lastScheduledAt?.isUtc, isTrue);
    expect(notifications.lastRequest?.id, testTimerNotificationId(sessionId));
    expect(
      testTimerNotificationId(sessionId),
      inInclusiveRange(0x40000000, 0x7fffffff),
    );
    expect(
      testTimerNotificationId('$sessionId-other'),
      isNot(testTimerNotificationId(sessionId)),
    );
  });

  test('暂停、继续和完成均使用持久化 UTC 状态', () async {
    final sessionId = await controller.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
    );
    await controller.start((await repository.readDraftById(sessionId))!);
    clock = clock.add(const Duration(seconds: 40));

    await controller.pause((await repository.readDraftById(sessionId))!);
    var session = (await repository.readDraftById(sessionId))!;
    expect(session.stage, ActiveTestStage.timerPaused.name);
    expect(session.pausedRemainingSeconds, 260);
    expect(session.timerEndsAt, isNull);

    clock = clock.add(const Duration(minutes: 2));
    await controller.resume(session);
    session = (await repository.readDraftById(sessionId))!;
    expect(
      session.timerEndsAt?.isAtSameMomentAs(
        clock.add(const Duration(seconds: 260)),
      ),
      isTrue,
    );

    await controller.complete(session);
    session = (await repository.readDraftById(sessionId))!;
    expect(session.stage, ActiveTestStage.timerCompleted.name);
    expect(session.timerEndsAt, isNull);
    expect(
      notifications.cancelledIds,
      contains(testTimerNotificationId(sessionId)),
    );
  });

  test('明确放弃才删草稿并尝试清理草稿照片', () async {
    final sessionId = await controller.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
    );
    await repository.updatePhoto(
      tankId: AppDatabase.defaultTankId,
      sessionId: sessionId,
      photoPath: 'water_quality_photos/draft.jpg',
    );

    final deleted = await controller.discard(
      (await repository.readDraftById(sessionId))!,
    );

    expect(deleted, isTrue);
    expect(await repository.readDraftById(sessionId), isNull);
    expect(photos.deletedPath, 'water_quality_photos/draft.jpg');
  });

  test('到期完成只更新一次，旧快照和并发回调不重复取消通知', () async {
    final sessionId = await controller.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
    );
    await controller.start((await repository.readDraftById(sessionId))!);
    final running = (await repository.readDraftById(sessionId))!;
    expect(await controller.completeElapsed(running), isFalse);
    expect(notifications.cancelledIds, isEmpty);

    clock = running.timerEndsAt!;
    final completed = await Future.wait([
      controller.completeElapsed(running),
      controller.completeElapsed(running),
      controller.completeElapsed(running),
    ]);
    expect(completed.where((changed) => changed), hasLength(1));
    final saved = (await repository.readDraftById(sessionId))!;
    expect(saved.stage, ActiveTestStage.timerCompleted.name);
    expect(saved.timerEndsAt, isNull);
    expect(notifications.cancelledIds, [testTimerNotificationId(sessionId)]);

    clock = clock.add(const Duration(seconds: 10));
    expect(await controller.completeElapsed(running), isFalse);
    expect(
      (await repository.readDraftById(sessionId))!.updatedAt,
      saved.updatedAt,
    );
    expect(notifications.cancelledIds, hasLength(1));
  });

  test('旧到期快照不能完成重启后的计时或覆盖复核草稿', () async {
    final sessionId = await controller.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
    );
    await controller.start((await repository.readDraftById(sessionId))!);
    final previous = (await repository.readDraftById(sessionId))!;
    clock = previous.timerEndsAt!;
    await controller.reset(previous);
    await controller.start((await repository.readDraftById(sessionId))!);
    final restarted = (await repository.readDraftById(sessionId))!;
    final cancellations = notifications.cancelledIds.length;
    expect(await controller.completeElapsed(previous), isFalse);
    expect(
      (await repository.readDraftById(sessionId))!.timerEndsAt,
      restarted.timerEndsAt,
    );
    expect(notifications.cancelledIds, hasLength(cancellations));

    await controller.useManualEntry(restarted);
    final review = (await repository.readDraftById(sessionId))!;
    clock = restarted.timerEndsAt!;
    expect(await controller.completeElapsed(restarted), isFalse);
    expect((await repository.readDraftById(sessionId))!.stage, review.stage);
  });

  test('复核保存使用用户选择的确认时间', () async {
    final sessionId = await controller.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
    );
    final session = (await repository.readDraftById(sessionId))!;
    await controller.useManualEntry(session);
    final confirmedAt = DateTime.utc(2026, 8, 11, 18, 30);
    await controller.persistReview(
      session: (await repository.readDraftById(sessionId))!,
      confirmedMinValue: 10,
      confirmedAt: confirmedAt,
      notes: '用户复核',
    );
    final persisted = await repository.readDraftById(sessionId);
    expect(persisted?.draftConfirmedAt?.isAtSameMomentAs(confirmedAt), isTrue);

    final recordId = await controller.save(
      session: persisted!,
      confirmedMinValue: 10,
      notes: '用户复核',
    );

    final record = await database.select(database.testRecords).getSingle();
    expect(record.id, recordId);
    expect(record.confirmedAt?.isAtSameMomentAs(confirmedAt), isTrue);
    expect(record.measuredAt.isAtSameMomentAs(confirmedAt), isTrue);
    expect(record.confirmedMinValue, 10);
    expect(await repository.readDraftById(sessionId), isNull);
  });
}

class _FakeNotifications implements LocalNotificationService {
  final _tapController = StreamController<LocalNotificationTap>.broadcast();
  NotificationOperationResult scheduleResult =
      const NotificationOperationResult.succeeded();
  LocalNotificationRequest? lastRequest;
  DateTime? lastScheduledAt;
  final cancelledIds = <int>[];

  @override
  Stream<LocalNotificationTap> get taps => _tapController.stream;

  @override
  Future<NotificationOperationResult> initialize() async =>
      const NotificationOperationResult.succeeded();

  @override
  Future<NotificationPermissionStatus> permissionStatus() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<NotificationPermissionStatus>
  requestExactSchedulingPermission() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<NotificationOperationResult> scheduleAtUtc(
    LocalNotificationRequest request,
    DateTime scheduledAtUtc,
  ) async {
    lastRequest = request;
    lastScheduledAt = scheduledAtUtc;
    return scheduleResult;
  }

  @override
  Future<NotificationOperationResult> scheduleAtDeviceLocalTime(
    LocalNotificationRequest request,
    DateTime deviceLocalDateTime,
  ) async => scheduleResult;

  @override
  Future<NotificationOperationResult> scheduleDailyAtDeviceLocalTime(
    LocalNotificationRequest request,
    DateTime firstDeviceLocalDateTime,
  ) async => scheduleResult;

  @override
  Future<NotificationOperationResult> cancel(int id) async {
    cancelledIds.add(id);
    return const NotificationOperationResult.succeeded();
  }

  Future<void> dispose() => _tapController.close();
}

class _FakePhotoStorage extends LocalPhotoStorage {
  String? deletedPath;

  @override
  Future<bool> deletePrivatePhoto(String? storedPath) async {
    deletedPath = storedPath;
    return true;
  }
}
