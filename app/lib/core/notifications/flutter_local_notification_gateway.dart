import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

import '../logging/app_logger.dart';
import 'local_notification.dart';
import 'local_notification_service.dart';

final class FlutterLocalNotificationGateway
    implements LocalNotificationGateway, AppNotificationSettingsGateway {
  factory FlutterLocalNotificationGateway({
    FlutterLocalNotificationsPlugin? plugin,
    AppLogger logger = const DebugAppLogger(),
  }) => FlutterLocalNotificationGateway._(
    plugin ?? FlutterLocalNotificationsPlugin(),
    logger,
  );

  FlutterLocalNotificationGateway._(this._plugin, this._logger);

  static const _maintenanceChannelId = 'maintenance_reminders';
  static const _timerChannelId = 'test_timers';

  final FlutterLocalNotificationsPlugin _plugin;
  final AppLogger _logger;
  final StreamController<LocalNotificationTap> _tapController =
      StreamController<LocalNotificationTap>.broadcast();

  time_zone.Location? _deviceLocation;
  LocalNotificationTap? _initialTap;
  bool _initialized = false;

  @override
  Stream<LocalNotificationTap> get taps async* {
    final initialTap = _initialTap;
    if (initialTap != null) {
      yield initialTap;
    }
    yield* _tapController.stream;
  }

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    time_zone_data.initializeTimeZones();
    await _resolveDeviceTimeZone();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_lanjiao'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
      ),
    );
    final initialized = await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
    if (initialized != true) {
      throw StateError('Local notification plugin did not initialize.');
    }

    _initialized = true;
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final response = launchDetails?.notificationResponse;
      if (response != null) {
        final tap = _parseTap(response);
        _initialTap = tap;
        if (tap != null) {
          // A tap listener can already be active while initialization is in
          // flight. Broadcast it for that listener; later listeners replay
          // [_initialTap] from the stream getter.
          _tapController.add(tap);
        }
      }
    }
  }

  Future<void> _resolveDeviceTimeZone() async {
    try {
      final localTimeZone = await FlutterTimezone.getLocalTimezone();
      final location = time_zone.getLocation(localTimeZone.identifier);
      time_zone.setLocalLocation(location);
      _deviceLocation = location;
    } catch (error, stackTrace) {
      // Absolute UTC scheduling remains correct. Wall-clock scheduling reports
      // unavailable instead of silently substituting UTC.
      _deviceLocation = null;
      _logger.error(
        'notification_timezone_initialize_failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<NotificationPermissionStatus> permissionStatus() async {
    _ensureInitialized();
    if (kIsWeb) {
      return NotificationPermissionStatus.unsupported;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final enabled = await android?.areNotificationsEnabled();
        return _permissionFromNullableBool(enabled);
      case TargetPlatform.iOS:
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final options = await ios?.checkPermissions();
        if (options == null) {
          return NotificationPermissionStatus.unavailable;
        }
        return options.isEnabled
            ? NotificationPermissionStatus.granted
            : NotificationPermissionStatus.denied;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return NotificationPermissionStatus.unsupported;
    }
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    _ensureInitialized();
    if (kIsWeb) {
      return NotificationPermissionStatus.unsupported;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted = await android?.requestNotificationsPermission();
        return _permissionFromNullableBool(granted);
      case TargetPlatform.iOS:
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final granted = await ios?.requestPermissions(alert: true, sound: true);
        return _permissionFromNullableBool(granted);
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return NotificationPermissionStatus.unsupported;
    }
  }

  @override
  Future<NotificationPermissionStatus>
  requestExactSchedulingPermission() async {
    _ensureInitialized();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return NotificationPermissionStatus.unsupported;
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestExactAlarmsPermission();
    return _permissionFromNullableBool(granted);
  }

  @override
  Future<bool> openAppNotificationSettings() async {
    _ensureInitialized();
    if (kIsWeb) {
      return false;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return await _plugin.openAppNotificationSettings() ?? false;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return false;
    }
  }

  @override
  Future<bool> scheduleAtUtc(
    LocalNotificationRequest request,
    DateTime scheduledAtUtc,
  ) async {
    _ensureInitialized();
    if (!scheduledAtUtc.isUtc) {
      throw ArgumentError.value(
        scheduledAtUtc,
        'scheduledAtUtc',
        'must be UTC',
      );
    }
    final location = _deviceLocation ?? time_zone.UTC;
    final scheduledDate = time_zone.TZDateTime.from(scheduledAtUtc, location);
    return _schedule(request, scheduledDate);
  }

  @override
  Future<bool> scheduleAtDeviceLocalTime(
    LocalNotificationRequest request,
    DateTime deviceLocalDateTime,
  ) async {
    _ensureInitialized();
    if (deviceLocalDateTime.isUtc) {
      throw ArgumentError.value(
        deviceLocalDateTime,
        'deviceLocalDateTime',
        'must be a device-local wall-clock time',
      );
    }
    final location = _deviceLocation;
    if (location == null) {
      throw StateError('Device time zone is unavailable.');
    }

    final scheduledDate = _wallClockDateTime(location, deviceLocalDateTime);
    return _schedule(request, scheduledDate);
  }

  @override
  Future<bool> scheduleDailyAtDeviceLocalTime(
    LocalNotificationRequest request,
    DateTime firstDeviceLocalDateTime,
  ) async {
    _ensureInitialized();
    if (firstDeviceLocalDateTime.isUtc) {
      throw ArgumentError.value(
        firstDeviceLocalDateTime,
        'firstDeviceLocalDateTime',
        'must be a device-local wall-clock time',
      );
    }
    final location = _deviceLocation;
    if (location == null) {
      throw StateError('Device time zone is unavailable.');
    }

    final scheduledDate = _wallClockDateTime(
      location,
      firstDeviceLocalDateTime,
    );
    return _schedule(
      request,
      scheduledDate,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<bool> _schedule(
    LocalNotificationRequest request,
    time_zone.TZDateTime scheduledDate, {
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    final usedExactScheduling = await _canUseExactScheduling(request);
    if (usedExactScheduling) {
      try {
        await _scheduleWithMode(
          request,
          scheduledDate,
          AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: matchDateTimeComponents,
        );
        return true;
      } catch (error, stackTrace) {
        // Special access can be revoked between the capability check and the
        // platform call. A timer still gets an inexact reminder in that case.
        _logger.error(
          'notification_exact_schedule_fallback',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    await _scheduleWithMode(
      request,
      scheduledDate,
      AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: matchDateTimeComponents,
    );
    return false;
  }

  Future<void> _scheduleWithMode(
    LocalNotificationRequest request,
    time_zone.TZDateTime scheduledDate,
    AndroidScheduleMode scheduleMode, {
    DateTimeComponents? matchDateTimeComponents,
  }) {
    return _plugin.zonedSchedule(
      id: request.id,
      title: request.title,
      body: request.body,
      scheduledDate: scheduledDate,
      notificationDetails: _notificationDetails(request.payload.type),
      androidScheduleMode: scheduleMode,
      payload: request.payload.encode(),
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }

  time_zone.TZDateTime _wallClockDateTime(
    time_zone.Location location,
    DateTime value,
  ) {
    return time_zone.TZDateTime(
      location,
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  Future<bool> _canUseExactScheduling(LocalNotificationRequest request) async {
    if (request.precision != NotificationDeliveryPrecision.exactIfPermitted ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.canScheduleExactNotifications() ?? false;
  }

  NotificationDetails _notificationDetails(LocalNotificationType type) {
    return switch (type) {
      LocalNotificationType.maintenanceTask => const NotificationDetails(
        android: AndroidNotificationDetails(
          _maintenanceChannelId,
          '维护任务提醒',
          channelDescription: '海缸周期性维护任务到期提醒',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: DarwinNotificationDetails(threadIdentifier: _maintenanceChannelId),
      ),
      LocalNotificationType.testTimer => const NotificationDetails(
        android: AndroidNotificationDetails(
          _timerChannelId,
          '水质检测计时器',
          channelDescription: '一次水质检测等待时间结束提醒',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: DarwinNotificationDetails(threadIdentifier: _timerChannelId),
      ),
    };
  }

  @override
  Future<void> cancel(int id) async {
    _ensureInitialized();
    await _plugin.cancel(id: id);
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final tap = _parseTap(response);
    if (tap != null) {
      _tapController.add(tap);
    }
  }

  LocalNotificationTap? _parseTap(NotificationResponse response) {
    final payload = LocalNotificationPayload.tryDecode(response.payload);
    if (payload == null) {
      _logger.info('notification_payload_ignored');
      return null;
    }
    return LocalNotificationTap(payload: payload, actionId: response.actionId);
  }

  NotificationPermissionStatus _permissionFromNullableBool(bool? value) =>
      switch (value) {
        true => NotificationPermissionStatus.granted,
        false => NotificationPermissionStatus.denied,
        null => NotificationPermissionStatus.unavailable,
      };

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('Local notification gateway is not initialized.');
    }
  }
}

LocalNotificationService createLocalNotificationService({
  AppLogger logger = const DebugAppLogger(),
}) {
  final gateway = FlutterLocalNotificationGateway(logger: logger);
  return GuardedLocalNotificationService(gateway: gateway, logger: logger);
}
