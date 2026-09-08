import 'dart:async';

import '../logging/app_logger.dart';
import 'local_notification.dart';

abstract interface class LocalNotificationGateway {
  Stream<LocalNotificationTap> get taps;

  Future<void> initialize();

  Future<NotificationPermissionStatus> permissionStatus();

  Future<NotificationPermissionStatus> requestPermission();

  Future<NotificationPermissionStatus> requestExactSchedulingPermission();

  Future<bool> scheduleAtUtc(
    LocalNotificationRequest request,
    DateTime scheduledAtUtc,
  );

  Future<bool> scheduleAtDeviceLocalTime(
    LocalNotificationRequest request,
    DateTime deviceLocalDateTime,
  );

  Future<bool> scheduleDailyAtDeviceLocalTime(
    LocalNotificationRequest request,
    DateTime firstDeviceLocalDateTime,
  );

  Future<void> cancel(int id);
}

/// Optional platform capability for opening this app's notification settings.
///
/// Kept separate from [LocalNotificationGateway] so non-mobile adapters and
/// test doubles do not have to claim a system-settings capability they lack.
abstract interface class AppNotificationSettingsGateway {
  Future<bool> openAppNotificationSettings();
}

abstract interface class LocalNotificationService {
  Stream<LocalNotificationTap> get taps;

  Future<NotificationOperationResult> initialize();

  Future<NotificationPermissionStatus> permissionStatus();

  Future<NotificationPermissionStatus> requestPermission();

  Future<NotificationPermissionStatus> requestExactSchedulingPermission();

  /// Schedules an absolute instant. The value must be explicitly UTC.
  Future<NotificationOperationResult> scheduleAtUtc(
    LocalNotificationRequest request,
    DateTime scheduledAtUtc,
  );

  /// Schedules a wall-clock time in the device's current IANA time zone.
  Future<NotificationOperationResult> scheduleAtDeviceLocalTime(
    LocalNotificationRequest request,
    DateTime deviceLocalDateTime,
  );

  /// Starts at the supplied device-local wall-clock time and repeats daily at
  /// the same local time until the notification id is cancelled or replaced.
  Future<NotificationOperationResult> scheduleDailyAtDeviceLocalTime(
    LocalNotificationRequest request,
    DateTime firstDeviceLocalDateTime,
  );

  Future<NotificationOperationResult> cancel(int id);
}

/// Optional service capability exposed by the production notification stack.
abstract interface class AppNotificationSettingsService {
  Future<NotificationOperationResult> openAppNotificationSettings();
}

/// Safely exposes the optional notification-settings capability through the
/// base service type without requiring every adapter or test double to
/// implement it.
extension LocalNotificationSettingsAccess on LocalNotificationService {
  Future<NotificationOperationResult> openAppNotificationSettings() {
    final settingsService = this is AppNotificationSettingsService
        ? this as AppNotificationSettingsService
        : null;
    if (settingsService == null) {
      return Future.value(const NotificationOperationResult.unsupported());
    }
    return settingsService.openAppNotificationSettings();
  }
}

/// Prevents notification permission or plugin failures from escaping into
/// task/timer business operations. Callers can persist business state first and
/// use the returned status to show a non-blocking notification warning.
final class GuardedLocalNotificationService
    implements LocalNotificationService, AppNotificationSettingsService {
  factory GuardedLocalNotificationService({
    required LocalNotificationGateway gateway,
    AppLogger logger = const DebugAppLogger(),
  }) => GuardedLocalNotificationService._(gateway, logger);

  GuardedLocalNotificationService._(this._gateway, this._logger) {
    _taps = _gateway.taps.transform(
      StreamTransformer<
        LocalNotificationTap,
        LocalNotificationTap
      >.fromHandlers(
        handleError:
            (
              Object error,
              StackTrace stackTrace,
              EventSink<LocalNotificationTap> sink,
            ) {
              _logger.error(
                'notification_tap_stream_failed',
                error: error,
                stackTrace: stackTrace,
              );
            },
      ),
    );
  }

  final LocalNotificationGateway _gateway;
  final AppLogger _logger;
  late final Stream<LocalNotificationTap> _taps;
  bool _initialized = false;
  Future<NotificationOperationResult>? _initializing;

  @override
  Stream<LocalNotificationTap> get taps => _taps;

  @override
  Future<NotificationOperationResult> initialize() {
    if (_initialized) {
      return Future.value(const NotificationOperationResult.succeeded());
    }
    final inProgress = _initializing;
    if (inProgress != null) {
      return inProgress;
    }

    final operation = _initializeOnce();
    _initializing = operation;
    operation.whenComplete(() {
      if (identical(_initializing, operation)) {
        _initializing = null;
      }
    });
    return operation;
  }

  Future<NotificationOperationResult> _initializeOnce() async {
    try {
      await _gateway.initialize();
      _initialized = true;
      return const NotificationOperationResult.succeeded();
    } catch (error, stackTrace) {
      _logger.error(
        'notification_initialize_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const NotificationOperationResult.unavailable();
    }
  }

  @override
  Future<NotificationPermissionStatus> permissionStatus() async {
    if (!_initialized) {
      return NotificationPermissionStatus.unavailable;
    }

    try {
      return await _gateway.permissionStatus();
    } catch (error, stackTrace) {
      _logger.error(
        'notification_permission_query_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return NotificationPermissionStatus.unavailable;
    }
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    if (!_initialized) {
      return NotificationPermissionStatus.unavailable;
    }

    try {
      return await _gateway.requestPermission();
    } catch (error, stackTrace) {
      _logger.error(
        'notification_permission_request_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return NotificationPermissionStatus.unavailable;
    }
  }

  @override
  Future<NotificationPermissionStatus>
  requestExactSchedulingPermission() async {
    if (!_initialized) {
      return NotificationPermissionStatus.unavailable;
    }

    try {
      return await _gateway.requestExactSchedulingPermission();
    } catch (error, stackTrace) {
      _logger.error(
        'notification_exact_permission_request_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return NotificationPermissionStatus.unavailable;
    }
  }

  @override
  Future<NotificationOperationResult> openAppNotificationSettings() async {
    if (!_initialized) {
      return const NotificationOperationResult.unavailable();
    }
    final settingsGateway = _gateway is AppNotificationSettingsGateway
        ? _gateway as AppNotificationSettingsGateway
        : null;
    if (settingsGateway == null) {
      return const NotificationOperationResult.unsupported();
    }

    try {
      final opened = await settingsGateway.openAppNotificationSettings();
      return opened
          ? const NotificationOperationResult.succeeded()
          : const NotificationOperationResult.unavailable();
    } catch (error, stackTrace) {
      _logger.error(
        'notification_settings_open_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const NotificationOperationResult.failed();
    }
  }

  @override
  Future<NotificationOperationResult> scheduleAtUtc(
    LocalNotificationRequest request,
    DateTime scheduledAtUtc,
  ) {
    if (!scheduledAtUtc.isUtc) {
      return Future.value(const NotificationOperationResult.invalidRequest());
    }
    return _schedule(() => _gateway.scheduleAtUtc(request, scheduledAtUtc));
  }

  @override
  Future<NotificationOperationResult> scheduleAtDeviceLocalTime(
    LocalNotificationRequest request,
    DateTime deviceLocalDateTime,
  ) {
    if (deviceLocalDateTime.isUtc) {
      return Future.value(const NotificationOperationResult.invalidRequest());
    }
    return _schedule(
      () => _gateway.scheduleAtDeviceLocalTime(request, deviceLocalDateTime),
    );
  }

  @override
  Future<NotificationOperationResult> scheduleDailyAtDeviceLocalTime(
    LocalNotificationRequest request,
    DateTime firstDeviceLocalDateTime,
  ) {
    if (firstDeviceLocalDateTime.isUtc) {
      return Future.value(const NotificationOperationResult.invalidRequest());
    }
    return _schedule(
      () => _gateway.scheduleDailyAtDeviceLocalTime(
        request,
        firstDeviceLocalDateTime,
      ),
    );
  }

  Future<NotificationOperationResult> _schedule(
    Future<bool> Function() operation,
  ) async {
    if (!_initialized) {
      return const NotificationOperationResult.unavailable();
    }

    final permission = await permissionStatus();
    switch (permission) {
      case NotificationPermissionStatus.denied:
        return const NotificationOperationResult.permissionDenied();
      case NotificationPermissionStatus.unsupported:
        return const NotificationOperationResult.unsupported();
      case NotificationPermissionStatus.unavailable:
        return const NotificationOperationResult.unavailable();
      case NotificationPermissionStatus.granted:
        break;
    }

    try {
      final usedExactScheduling = await operation();
      return NotificationOperationResult.succeeded(
        usedExactScheduling: usedExactScheduling,
      );
    } catch (error, stackTrace) {
      _logger.error(
        'notification_schedule_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const NotificationOperationResult.failed();
    }
  }

  @override
  Future<NotificationOperationResult> cancel(int id) async {
    if (!_initialized) {
      return const NotificationOperationResult.unavailable();
    }
    if (id < 0 || id > 0x7fffffff) {
      return const NotificationOperationResult.invalidRequest();
    }

    try {
      await _gateway.cancel(id);
      return const NotificationOperationResult.succeeded();
    } catch (error, stackTrace) {
      _logger.error(
        'notification_cancel_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const NotificationOperationResult.failed();
    }
  }
}
