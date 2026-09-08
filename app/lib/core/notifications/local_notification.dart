import 'dart:convert';

enum LocalNotificationType { maintenanceTask, testTimer }

enum NotificationDeliveryPrecision { inexact, exactIfPermitted }

enum NotificationPermissionStatus { granted, denied, unsupported, unavailable }

enum NotificationOperationStatus {
  succeeded,
  permissionDenied,
  unsupported,
  unavailable,
  invalidRequest,
  failed,
}

final class LocalNotificationPayload {
  const LocalNotificationPayload._({
    required this.type,
    required this.targetId,
  });

  factory LocalNotificationPayload.maintenanceTask(String taskId) =>
      LocalNotificationPayload._(
        type: LocalNotificationType.maintenanceTask,
        targetId: _requireTargetId(taskId),
      );

  factory LocalNotificationPayload.testTimer(String sessionId) =>
      LocalNotificationPayload._(
        type: LocalNotificationType.testTimer,
        targetId: _requireTargetId(sessionId),
      );

  final LocalNotificationType type;
  final String targetId;

  String encode() => jsonEncode(<String, Object>{
    'version': 1,
    'type': type.name,
    'targetId': targetId,
  });

  static LocalNotificationPayload? tryDecode(String? encoded) {
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
        return null;
      }

      final typeName = decoded['type'];
      final targetId = decoded['targetId'];
      if (typeName is! String || targetId is! String || targetId.isEmpty) {
        return null;
      }

      LocalNotificationType? type;
      for (final candidate in LocalNotificationType.values) {
        if (candidate.name == typeName) {
          type = candidate;
          break;
        }
      }
      if (type == null) {
        return null;
      }

      return LocalNotificationPayload._(type: type, targetId: targetId);
    } on FormatException {
      return null;
    }
  }

  static String _requireTargetId(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'targetId', 'must not be empty');
    }
    return normalized;
  }
}

final class LocalNotificationRequest {
  const LocalNotificationRequest._({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
    required this.precision,
  });

  factory LocalNotificationRequest.maintenanceTask({
    required int id,
    required String taskId,
    required String title,
    required String body,
  }) => LocalNotificationRequest._(
    id: _requireId(id),
    title: _requireText(title, 'title'),
    body: _requireText(body, 'body'),
    payload: LocalNotificationPayload.maintenanceTask(taskId),
    precision: NotificationDeliveryPrecision.inexact,
  );

  factory LocalNotificationRequest.testTimer({
    required int id,
    required String sessionId,
    required String title,
    required String body,
  }) => LocalNotificationRequest._(
    id: _requireId(id),
    title: _requireText(title, 'title'),
    body: _requireText(body, 'body'),
    payload: LocalNotificationPayload.testTimer(sessionId),
    precision: NotificationDeliveryPrecision.exactIfPermitted,
  );

  final int id;
  final String title;
  final String body;
  final LocalNotificationPayload payload;
  final NotificationDeliveryPrecision precision;

  static int _requireId(int value) {
    if (value < 0 || value > 0x7fffffff) {
      throw RangeError.range(value, 0, 0x7fffffff, 'id');
    }
    return value;
  }

  static String _requireText(String value, String name) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, name, 'must not be empty');
    }
    return normalized;
  }
}

final class LocalNotificationTap {
  const LocalNotificationTap({required this.payload, this.actionId});

  final LocalNotificationPayload payload;
  final String? actionId;
}

final class NotificationOperationResult {
  const NotificationOperationResult._({
    required this.status,
    this.usedExactScheduling = false,
  });

  const NotificationOperationResult.succeeded({
    bool usedExactScheduling = false,
  }) : this._(
         status: NotificationOperationStatus.succeeded,
         usedExactScheduling: usedExactScheduling,
       );

  const NotificationOperationResult.permissionDenied()
    : this._(status: NotificationOperationStatus.permissionDenied);

  const NotificationOperationResult.unsupported()
    : this._(status: NotificationOperationStatus.unsupported);

  const NotificationOperationResult.unavailable()
    : this._(status: NotificationOperationStatus.unavailable);

  const NotificationOperationResult.invalidRequest()
    : this._(status: NotificationOperationStatus.invalidRequest);

  const NotificationOperationResult.failed()
    : this._(status: NotificationOperationStatus.failed);

  final NotificationOperationStatus status;
  final bool usedExactScheduling;

  bool get succeeded => status == NotificationOperationStatus.succeeded;
}
