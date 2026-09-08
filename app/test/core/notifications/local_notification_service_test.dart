import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/core/logging/app_logger.dart';
import 'package:lanjiao_water_quality/core/notifications/local_notification.dart';
import 'package:lanjiao_water_quality/core/notifications/local_notification_service.dart';

void main() {
  group('LocalNotificationPayload', () {
    test('round-trips both supported notification types', () {
      final task = LocalNotificationPayload.maintenanceTask('task-1');
      final timer = LocalNotificationPayload.testTimer('session-1');

      final decodedTask = LocalNotificationPayload.tryDecode(task.encode());
      final decodedTimer = LocalNotificationPayload.tryDecode(timer.encode());

      expect(decodedTask?.type, LocalNotificationType.maintenanceTask);
      expect(decodedTask?.targetId, 'task-1');
      expect(decodedTimer?.type, LocalNotificationType.testTimer);
      expect(decodedTimer?.targetId, 'session-1');
    });

    test('rejects malformed and unsupported payloads', () {
      expect(LocalNotificationPayload.tryDecode(null), isNull);
      expect(LocalNotificationPayload.tryDecode('not-json'), isNull);
      expect(
        LocalNotificationPayload.tryDecode(
          '{"version":2,"type":"testTimer","targetId":"session-1"}',
        ),
        isNull,
      );
    });
  });

  group('LocalNotificationRequest', () {
    test('uses inexact task reminders and opt-in exact timer reminders', () {
      final task = LocalNotificationRequest.maintenanceTask(
        id: 1,
        taskId: 'task-1',
        title: '换水',
        body: '维护任务已到期',
      );
      final timer = LocalNotificationRequest.testTimer(
        id: 2,
        sessionId: 'session-1',
        title: '显色完成',
        body: '可以继续检测',
      );

      expect(task.precision, NotificationDeliveryPrecision.inexact);
      expect(timer.precision, NotificationDeliveryPrecision.exactIfPermitted);
    });
  });

  group('GuardedLocalNotificationService', () {
    test('contains initialization failures', () async {
      final gateway = _FakeNotificationGateway()..throwOnInitialize = true;
      final service = _service(gateway);

      final result = await service.initialize();

      expect(result.status, NotificationOperationStatus.unavailable);
      expect(
        await service.permissionStatus(),
        NotificationPermissionStatus.unavailable,
      );
    });

    test('permission denial does not call platform scheduling', () async {
      final gateway = _FakeNotificationGateway()
        ..permission = NotificationPermissionStatus.denied;
      final service = _service(gateway);
      await service.initialize();

      final result = await service.scheduleAtUtc(
        _timerRequest(),
        DateTime.utc(2030, 1, 1),
      );

      expect(result.status, NotificationOperationStatus.permissionDenied);
      expect(gateway.scheduleCalls, 0);
    });

    test('reports whether exact scheduling was actually used', () async {
      final gateway = _FakeNotificationGateway()..usedExactScheduling = true;
      final service = _service(gateway);
      await service.initialize();

      final result = await service.scheduleAtUtc(
        _timerRequest(),
        DateTime.utc(2030, 1, 1),
      );

      expect(result.status, NotificationOperationStatus.succeeded);
      expect(result.usedExactScheduling, isTrue);
      expect(gateway.scheduleCalls, 1);
    });

    test('rejects an implicit-local value for UTC scheduling', () async {
      final gateway = _FakeNotificationGateway();
      final service = _service(gateway);
      await service.initialize();

      final result = await service.scheduleAtUtc(
        _timerRequest(),
        DateTime(2030, 1, 1),
      );

      expect(result.status, NotificationOperationStatus.invalidRequest);
      expect(gateway.scheduleCalls, 0);
    });

    test('rejects a UTC value for device wall-clock scheduling', () async {
      final gateway = _FakeNotificationGateway();
      final service = _service(gateway);
      await service.initialize();

      final result = await service.scheduleAtDeviceLocalTime(
        _timerRequest(),
        DateTime.utc(2030, 1, 1),
      );

      expect(result.status, NotificationOperationStatus.invalidRequest);
      expect(gateway.scheduleCalls, 0);
    });

    test('contains scheduling and cancellation plugin failures', () async {
      final gateway = _FakeNotificationGateway()
        ..throwOnSchedule = true
        ..throwOnCancel = true;
      final service = _service(gateway);
      await service.initialize();

      final schedule = await service.scheduleAtUtc(
        _timerRequest(),
        DateTime.utc(2030, 1, 1),
      );
      final cancel = await service.cancel(2);

      expect(schedule.status, NotificationOperationStatus.failed);
      expect(cancel.status, NotificationOperationStatus.failed);
    });

    test('reports unsupported when settings capability is absent', () async {
      final gateway = _FakeNotificationGateway();
      final LocalNotificationService service = _service(gateway);
      await service.initialize();

      final result = await service.openAppNotificationSettings();

      expect(result.status, NotificationOperationStatus.unsupported);
    });

    test('opens settings through the optional gateway capability', () async {
      final gateway = _SettingsFakeNotificationGateway();
      final LocalNotificationService service = _service(gateway);
      await service.initialize();

      final result = await service.openAppNotificationSettings();

      expect(result.status, NotificationOperationStatus.succeeded);
      expect(gateway.openSettingsCalls, 1);
    });

    test('contains settings gateway failures', () async {
      final gateway = _SettingsFakeNotificationGateway()
        ..throwOnOpenSettings = true;
      final LocalNotificationService service = _service(gateway);
      await service.initialize();

      final result = await service.openAppNotificationSettings();

      expect(result.status, NotificationOperationStatus.failed);
      expect(gateway.openSettingsCalls, 1);
    });

    test('forwards typed notification tap events', () async {
      final gateway = _FakeNotificationGateway();
      final service = _service(gateway);
      final nextTap = service.taps.first;
      await service.initialize();

      gateway.emitTap(
        LocalNotificationTap(
          payload: LocalNotificationPayload.maintenanceTask('task-7'),
        ),
      );

      final tap = await nextTap;
      expect(tap.payload.type, LocalNotificationType.maintenanceTask);
      expect(tap.payload.targetId, 'task-7');
    });
  });
}

GuardedLocalNotificationService _service(_FakeNotificationGateway gateway) =>
    GuardedLocalNotificationService(
      gateway: gateway,
      logger: const _SilentLogger(),
    );

LocalNotificationRequest _timerRequest() => LocalNotificationRequest.testTimer(
  id: 2,
  sessionId: 'session-1',
  title: '显色完成',
  body: '可以继续检测',
);

class _FakeNotificationGateway implements LocalNotificationGateway {
  final StreamController<LocalNotificationTap> _taps =
      StreamController<LocalNotificationTap>.broadcast();

  bool throwOnInitialize = false;
  bool throwOnSchedule = false;
  bool throwOnCancel = false;
  bool usedExactScheduling = false;
  int scheduleCalls = 0;
  NotificationPermissionStatus permission =
      NotificationPermissionStatus.granted;

  @override
  Stream<LocalNotificationTap> get taps => _taps.stream;

  void emitTap(LocalNotificationTap tap) => _taps.add(tap);

  @override
  Future<void> initialize() async {
    if (throwOnInitialize) {
      throw StateError('initialization failed');
    }
  }

  @override
  Future<NotificationPermissionStatus> permissionStatus() async => permission;

  @override
  Future<NotificationPermissionStatus> requestPermission() async => permission;

  @override
  Future<NotificationPermissionStatus>
  requestExactSchedulingPermission() async => permission;

  @override
  Future<bool> scheduleAtUtc(
    LocalNotificationRequest request,
    DateTime scheduledAtUtc,
  ) => _schedule();

  @override
  Future<bool> scheduleAtDeviceLocalTime(
    LocalNotificationRequest request,
    DateTime deviceLocalDateTime,
  ) => _schedule();

  @override
  Future<bool> scheduleDailyAtDeviceLocalTime(
    LocalNotificationRequest request,
    DateTime firstDeviceLocalDateTime,
  ) => _schedule();

  Future<bool> _schedule() async {
    scheduleCalls += 1;
    if (throwOnSchedule) {
      throw StateError('scheduling failed');
    }
    return usedExactScheduling;
  }

  @override
  Future<void> cancel(int id) async {
    if (throwOnCancel) {
      throw StateError('cancellation failed');
    }
  }
}

final class _SettingsFakeNotificationGateway extends _FakeNotificationGateway
    implements AppNotificationSettingsGateway {
  bool throwOnOpenSettings = false;
  bool openSettingsResult = true;
  int openSettingsCalls = 0;

  @override
  Future<bool> openAppNotificationSettings() async {
    openSettingsCalls += 1;
    if (throwOnOpenSettings) {
      throw StateError('opening settings failed');
    }
    return openSettingsResult;
  }
}

final class _SilentLogger implements AppLogger {
  const _SilentLogger();

  @override
  void error(String event, {Object? error, StackTrace? stackTrace}) {}

  @override
  void info(String event) {}
}
