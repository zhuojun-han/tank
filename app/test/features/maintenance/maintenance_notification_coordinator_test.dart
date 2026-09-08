import 'dart:async';
import 'package:drift/drift.dart' show Value;

import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/core/notifications/local_notification.dart';
import 'package:lanjiao_water_quality/core/notifications/local_notification_service.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_notification_coordinator.dart';
import 'package:lanjiao_water_quality/features/maintenance/data/maintenance_repository.dart';
import 'package:lanjiao_water_quality/features/maintenance/domain/recurrence.dart';

void main() {
  test('日期周期只安排实际发生日，完成和停止后重排取消', () async {
    final store = _FakeTaskStore();
    final notifications = _FakeNotificationService();
    final clock = DateTime(2026, 9, 5, 8);
    final coordinator = MaintenanceNotificationCoordinator(
      taskStore: store,
      notificationService: notifications,
      nowUtc: () => clock.toUtc(),
      nowDeviceLocal: () => clock,
    );
    addTearDown(coordinator.dispose);
    addTearDown(store.close);
    await coordinator.start();
    final rule = Recurrence(start: '2026-09-05', completedBefore: '2026-09-05');
    final base = _item(dueAt: DateTime(2026, 9, 5, 9).toUtc());
    MaintenanceTaskItem item() => MaintenanceTaskItem(
      task: base.task.copyWith(
        recurrenceJson: Value(rule.encode()),
        intervalUnit: 'day',
        intervalAmount: 2,
      ),
      state: MaintenanceTaskViewState.upcoming,
    );
    var ready = coordinator.states.firstWhere(
      (s) => s.phase == MaintenanceNotificationSyncPhase.ready,
    );
    store.emit([item()]);
    await ready;
    expect(notifications.dailySchedules, isEmpty);
    expect(notifications.oneShots.map((r) => dateKey(r.atUtc)), [
      '2026-09-05',
      '2026-09-07',
    ]);
    notifications.oneShots.clear();
    rule.states['2026-09-05'] = 'completed';
    ready = coordinator.states.firstWhere(
      (s) => s.phase == MaintenanceNotificationSyncPhase.ready,
    );
    store.emit([item()]);
    await ready;
    expect(notifications.oneShots.map((r) => dateKey(r.atUtc)), [
      '2026-09-07',
      '2026-09-09',
    ]);
    notifications.oneShots.clear();
    notifications.cancelledIds.clear();
    rule.stoppedAfter = '2026-09-05';
    ready = coordinator.states.firstWhere(
      (s) => s.phase == MaintenanceNotificationSyncPhase.ready,
    );
    store.emit([item()]);
    await ready;
    expect(notifications.oneShots, isEmpty);
    expect(notifications.cancelledIds, hasLength(2));
  });
  group('buildMaintenanceNotificationPlan', () {
    final nowUtc = DateTime.utc(2026, 8, 12, 2);

    test('plans exact snooze and preferred-time daily overdue reminders', () {
      final snoozedUntil = DateTime.utc(2026, 8, 13, 4, 30);
      final plan = buildMaintenanceNotificationPlan(
        _item(
          dueAt: DateTime.utc(2026, 8, 11),
          preferredReminderTime: '07:45',
          latestEvent: TaskEvent(
            id: 'event-1',
            taskId: 'task-1',
            type: TaskEventType.snoozed.name,
            occurredAt: nowUtc,
            snoozedUntil: snoozedUntil,
          ),
        ),
        nowUtc: nowUtc,
        nowDeviceLocal: DateTime(2026, 8, 12, 10),
        toDeviceLocal: _toUtcPlusEight,
      );

      expect(plan.dueReminderAtUtc, snoozedUntil);
      expect(
        plan.dailyReminderStartsAtDeviceLocal,
        DateTime(2026, 8, 14, 7, 45),
      );
    });

    test('expired snooze falls back to the original task due instant', () {
      final originalDue = DateTime.utc(2026, 8, 13, 4);
      final plan = buildMaintenanceNotificationPlan(
        _item(
          dueAt: originalDue,
          preferredReminderTime: '08:15',
          latestEvent: TaskEvent(
            id: 'event-1',
            taskId: 'task-1',
            type: TaskEventType.snoozed.name,
            occurredAt: DateTime.utc(2026, 8, 12),
            snoozedUntil: DateTime.utc(2026, 8, 12, 1),
          ),
        ),
        nowUtc: nowUtc,
        nowDeviceLocal: DateTime(2026, 8, 12, 10),
        toDeviceLocal: _toUtcPlusEight,
      );

      expect(plan.dueReminderAtUtc, originalDue);
      expect(
        plan.dailyReminderStartsAtDeviceLocal,
        DateTime(2026, 8, 14, 8, 15),
      );
    });

    test('overdue reminders use the next preferred device-local time', () {
      final beforePreferred = buildMaintenanceNotificationPlan(
        _item(dueAt: DateTime.utc(2026, 8, 11), preferredReminderTime: '08:45'),
        nowUtc: nowUtc,
        nowDeviceLocal: DateTime(2026, 8, 12, 8, 30),
      );
      final afterPreferred = buildMaintenanceNotificationPlan(
        _item(dueAt: DateTime.utc(2026, 8, 11), preferredReminderTime: '08:45'),
        nowUtc: nowUtc,
        nowDeviceLocal: DateTime(2026, 8, 12, 9, 30),
      );

      expect(beforePreferred.dueReminderAtUtc, isNull);
      expect(
        beforePreferred.dailyReminderStartsAtDeviceLocal,
        DateTime(2026, 8, 12, 8, 45),
      );
      expect(
        afterPreferred.dailyReminderStartsAtDeviceLocal,
        DateTime(2026, 8, 13, 8, 45),
      );
    });
  });

  test('stable due and daily IDs are deterministic and disjoint', () {
    final first = stableMaintenanceNotificationId('task-1');
    final daily = maintenanceDailyNotificationId(first);

    expect(stableMaintenanceNotificationId('task-1'), first);
    expect(first, inInclusiveRange(0x10000000, 0x1fffffff));
    expect(daily, inInclusiveRange(0x20000000, 0x2fffffff));
    expect(
      stableMaintenanceNotificationId('task-1', reservedIds: {first}),
      isNot(first),
    );
  });

  test(
    'persists a missing ID and schedules exact plus daily only once',
    () async {
      final store = _FakeTaskStore();
      final notifications = _FakeNotificationService();
      final coordinator = _coordinator(store, notifications);
      await coordinator.start();

      var ready = coordinator.states.firstWhere(
        (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit([
        _item(dueAt: DateTime.utc(2026, 8, 13), preferredReminderTime: '09:30'),
      ]);
      await ready;
      expect(store.persistedIds, hasLength(1));
      expect(notifications.oneShots, hasLength(1));
      expect(notifications.dailySchedules, hasLength(1));
      expect(
        notifications.dailySchedules.single.atDeviceLocal,
        DateTime(2026, 8, 13, 9, 30),
      );
      expect(
        notifications.dailySchedules.single.request.id,
        maintenanceDailyNotificationId(store.persistedIds.single),
      );

      notifications.cancelledIds.clear();
      final persistedId = store.persistedIds.single;
      ready = coordinator.states.firstWhere(
        (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit([
        _item(
          dueAt: DateTime.utc(2026, 8, 13),
          preferredReminderTime: '09:30',
          notificationId: persistedId,
        ),
      ]);
      await ready;
      expect(store.persistedIds, hasLength(1));
      expect(notifications.oneShots, hasLength(1));
      expect(notifications.dailySchedules, hasLength(1));
      expect(notifications.cancelledIds, isEmpty);

      await coordinator.dispose();
      await store.close();
    },
  );

  test('disabled and removed tasks cancel both notification IDs', () async {
    final store = _FakeTaskStore();
    final notifications = _FakeNotificationService();
    final coordinator = _coordinator(store, notifications);
    final notificationId = stableMaintenanceNotificationId('task-1');
    await coordinator.start();

    var ready = coordinator.states.firstWhere(
      (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
    );
    store.emit([
      _item(dueAt: DateTime.utc(2026, 8, 13), notificationId: notificationId),
    ]);
    await ready;
    notifications.cancelledIds.clear();

    ready = coordinator.states.firstWhere(
      (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
    );
    store.emit([
      _item(
        dueAt: DateTime.utc(2026, 8, 13),
        notificationId: notificationId,
        status: MaintenanceTaskStatus.disabled.name,
      ),
    ]);
    await ready;
    expect(
      notifications.cancelledIds,
      containsAll([
        notificationId,
        maintenanceDailyNotificationId(notificationId),
      ]),
    );

    notifications.cancelledIds.clear();
    ready = coordinator.states.firstWhere(
      (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
    );
    store.emit(const []);
    await ready;
    expect(
      notifications.cancelledIds,
      containsAll([
        notificationId,
        maintenanceDailyNotificationId(notificationId),
      ]),
    );

    await coordinator.dispose();
    await store.close();
  });

  test(
    'notification preference cancels schedules and can enable them again',
    () async {
      final store = _FakeTaskStore();
      final notifications = _FakeNotificationService();
      final enabled = StreamController<bool>.broadcast();
      final coordinator = MaintenanceNotificationCoordinator(
        taskStore: store,
        notificationService: notifications,
        notificationsEnabled: enabled.stream,
        nowUtc: () => DateTime.utc(2026, 8, 12, 2),
        nowDeviceLocal: () => DateTime(2026, 8, 12, 10),
        toDeviceLocal: _toUtcPlusEight,
      );
      final notificationId = stableMaintenanceNotificationId('task-1');
      await coordinator.start();

      var ready = coordinator.states.firstWhere(
        (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit([
        _item(dueAt: DateTime.utc(2026, 8, 13), notificationId: notificationId),
      ]);
      await ready;
      expect(notifications.oneShots, isEmpty);
      expect(notifications.dailySchedules, isEmpty);
      expect(
        notifications.cancelledIds,
        containsAll([
          notificationId,
          maintenanceDailyNotificationId(notificationId),
        ]),
      );

      notifications.cancelledIds.clear();
      ready = coordinator.states.firstWhere(
        (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
      );
      enabled.add(true);
      await ready;
      expect(notifications.oneShots, hasLength(1));
      expect(notifications.dailySchedules, hasLength(1));

      ready = coordinator.states.firstWhere(
        (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
      );
      enabled.add(false);
      await ready;
      expect(
        notifications.cancelledIds,
        containsAll([
          notificationId,
          maintenanceDailyNotificationId(notificationId),
        ]),
      );

      await coordinator.dispose();
      await enabled.close();
      await store.close();
    },
  );

  test(
    'cycle advance cancels both old IDs before applying the next plan',
    () async {
      final store = _FakeTaskStore();
      final notifications = _FakeNotificationService();
      final coordinator = _coordinator(store, notifications);
      final notificationId = stableMaintenanceNotificationId('task-1');
      await coordinator.start();

      var ready = coordinator.states.firstWhere(
        (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit([
        _item(dueAt: DateTime.utc(2026, 8, 13), notificationId: notificationId),
      ]);
      await ready;
      notifications.cancelledIds.clear();

      ready = coordinator.states.firstWhere(
        (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit([
        _item(dueAt: DateTime.utc(2026, 8, 20), notificationId: notificationId),
      ]);
      await ready;

      expect(
        notifications.cancelledIds,
        containsAll([
          notificationId,
          maintenanceDailyNotificationId(notificationId),
        ]),
      );
      expect(notifications.oneShots, hasLength(2));
      expect(notifications.dailySchedules, hasLength(2));

      await coordinator.dispose();
      await store.close();
    },
  );
}

MaintenanceNotificationCoordinator _coordinator(
  _FakeTaskStore store,
  _FakeNotificationService notifications,
) {
  return MaintenanceNotificationCoordinator(
    taskStore: store,
    notificationService: notifications,
    nowUtc: () => DateTime.utc(2026, 8, 12, 2),
    nowDeviceLocal: () => DateTime(2026, 8, 12, 10),
    toDeviceLocal: _toUtcPlusEight,
  );
}

DateTime _toUtcPlusEight(DateTime utc) => DateTime(
  utc.year,
  utc.month,
  utc.day,
  utc.hour + 8,
  utc.minute,
  utc.second,
  utc.millisecond,
  utc.microsecond,
);

MaintenanceTaskItem _item({
  required DateTime dueAt,
  TaskEvent? latestEvent,
  int? notificationId,
  String preferredReminderTime = '09:00',
  String status = 'enabled',
}) {
  return MaintenanceTaskItem(
    task: MaintenanceTask(
      isOneOff: false,
      id: 'task-1',
      tankId: 'tank-1',
      title: '换水',
      intervalAmount: 1,
      intervalUnit: MaintenanceIntervalUnit.week.name,
      dueAt: dueAt,
      preferredReminderTime: preferredReminderTime,
      status: status,
      notificationId: notificationId,
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
    ),
    latestEvent: latestEvent,
    state: MaintenanceTaskViewState.upcoming,
  );
}

final class _FakeTaskStore implements MaintenanceNotificationTaskStore {
  final _controller = StreamController<List<MaintenanceTaskItem>>.broadcast();
  final persistedIds = <int>[];

  void emit(List<MaintenanceTaskItem> items) => _controller.add(items);

  Future<void> close() => _controller.close();

  @override
  Stream<List<MaintenanceTaskItem>> watchAllTaskItems() => _controller.stream;

  @override
  Future<void> persistNotificationId({
    required String tankId,
    required String taskId,
    required int notificationId,
  }) async {
    persistedIds.add(notificationId);
  }
}

final class _FakeNotificationService implements LocalNotificationService {
  final oneShots = <({LocalNotificationRequest request, DateTime atUtc})>[];
  final dailySchedules =
      <({LocalNotificationRequest request, DateTime atDeviceLocal})>[];
  final cancelledIds = <int>[];

  @override
  Stream<LocalNotificationTap> get taps => const Stream.empty();

  @override
  Future<NotificationOperationResult> initialize() async =>
      const NotificationOperationResult.succeeded();

  @override
  Future<NotificationPermissionStatus> permissionStatus() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<NotificationPermissionStatus>
  requestExactSchedulingPermission() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<NotificationOperationResult> scheduleAtUtc(
    LocalNotificationRequest request,
    DateTime scheduledAtUtc,
  ) async {
    oneShots.add((request: request, atUtc: scheduledAtUtc));
    return const NotificationOperationResult.succeeded();
  }

  @override
  Future<NotificationOperationResult> scheduleAtDeviceLocalTime(
    LocalNotificationRequest request,
    DateTime deviceLocalDateTime,
  ) async => const NotificationOperationResult.succeeded();

  @override
  Future<NotificationOperationResult> scheduleDailyAtDeviceLocalTime(
    LocalNotificationRequest request,
    DateTime firstDeviceLocalDateTime,
  ) async {
    dailySchedules.add((
      request: request,
      atDeviceLocal: firstDeviceLocalDateTime,
    ));
    return const NotificationOperationResult.succeeded();
  }

  @override
  Future<NotificationOperationResult> cancel(int id) async {
    cancelledIds.add(id);
    return const NotificationOperationResult.succeeded();
  }
}
