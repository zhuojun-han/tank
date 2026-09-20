import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/notifications/flutter_local_notification_gateway.dart';
import '../core/notifications/local_notification.dart';
import '../core/notifications/local_notification_service.dart';
import '../data/backup/backup_transfer_gateway.dart';
import '../data/backup/complete_backup_service.dart';
import '../data/backup/local_backup_service.dart';
import '../data/backup/test_record_csv_export_service.dart';
import '../data/database/app_database.dart';
import '../features/calculators/data/maintenance_cycle_repository.dart';
import '../features/maintenance/application/maintenance_notification_coordinator.dart';
import '../features/maintenance/data/maintenance_repository.dart';
import '../features/tanks/data/tank_repository.dart';
import '../features/test_timer/application/test_workflow_controller.dart';
import '../features/test_timer/data/test_session_repository.dart';
import '../features/test_timer/domain/test_timer.dart';
import 'native_photo_draft_storage.dart';
import 'native_data_removal.dart';
import 'native_export_storage.dart';

typedef NativePageEmitter = Future<void> Function(String name, Object? detail);

/// Reuses the existing backup format and OS reminder engine. UI drafts are
/// disposable; tasks, snoozes and running timers are persisted in SQLite.
class NativePlatformServices {
  NativePlatformServices(this.database, {required this.emit})
    : backup = CompleteBackupService(LocalBackupService(database)),
      notifications = createLocalNotificationService(),
      tasks = MaintenanceRepository(database),
      cycles = MaintenanceCycleRepository(database),
      sessions = TestSessionRepository(database);

  final AppDatabase database;
  final NativePageEmitter emit;
  final CompleteBackupService backup;
  final LocalNotificationService notifications;
  final MaintenanceRepository tasks;
  final MaintenanceCycleRepository cycles;
  final TestSessionRepository sessions;
  final BackupTransferGateway transfer = const FlutterBackupTransferGateway();
  final NativePhotoDraftStorage _photoDrafts = NativePhotoDraftStorage();
  final NativeExportStorage _exports = NativeExportStorage();
  MaintenanceNotificationCoordinator? _coordinator;
  StreamSubscription<LocalNotificationTap>? _tapSubscription;
  _RestoreCandidate? _restoreCandidate;
  bool _initialized = false;
  bool _fileOperation = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await notifications.initialize();
    _tapSubscription = notifications.taps.listen((tap) {
      unawaited(_openNotification(tap));
    });
    _coordinator = MaintenanceNotificationCoordinator(
      taskStore: _WebViewNotificationStore(
        database,
        RepositoryMaintenanceNotificationTaskStore(tasks, cycles: cycles),
      ),
      notificationService: notifications,
      notificationsEnabled: TankRepository(
        database,
      ).watchMaintenanceNotificationsEnabled(),
    );
    await _coordinator!.start();
    await _restoreTimers();
  }

  Future<void> onResume() async {
    await _coordinator?.reconcileNow();
    await _restoreTimers();
  }

  Future<void> reconcile({bool force = true}) async =>
      _coordinator?.reconcileNow(force: force);

  Future<Map<String, dynamic>> handle(
    String method,
    Map<String, dynamic> params,
  ) async {
    switch (method) {
      case 'data.deleteTank':
      case 'data.reset':
        return _exclusiveFileOperation(
          () => _removeData(params, reset: method == 'data.reset'),
        );
      case 'backup.export':
        return _exclusiveFileOperation(() async {
          final report = await CompleteBackupService(
            LocalBackupService(database),
            supportDirectory: _exports.directory,
          ).exportToPrivateFile();
          await _exports.retainRecent(report.file);
          final status = await transfer.shareCompleteBackup(report.file);
          return {
            'status': status.name,
            'fileName': p.basename(report.file.path),
          };
        });
      case 'backup.pick':
        return _exclusiveFileOperation(_pickBackup);
      case 'backup.cancel':
        await _clearCandidate();
        return {'cancelled': true};
      case 'backup.restore':
        return _exclusiveFileOperation(() => _restoreBackup(params));
      case 'backup.csv':
        return _exclusiveFileOperation(() async {
          final tankId = await _requireTank(params);
          final file = await TestRecordCsvExportService(
            database,
            supportDirectory: _exports.directory,
          ).exportToPrivateFile(tankId);
          await _exports.retainRecent(file);
          final status = await transfer.shareCsv(file);
          return {'status': status.name, 'fileName': p.basename(file.path)};
        });
      case 'notifications.status':
        final preferences = await database
            .select(database.appPreferences)
            .getSingle();
        return {
          'permission': (await notifications.permissionStatus()).name,
          'enabled': preferences.maintenanceNotificationsEnabled,
          'sync': _coordinator?.currentState.phase.name,
        };
      case 'notifications.permission':
        final permission = await notifications.requestPermission();
        await reconcile();
        return {'permission': permission.name};
      case 'notifications.enabled':
        if (params['enabled'] is! bool) throw const FormatException('请确认提醒开关。');
        await TankRepository(
          database,
        ).setMaintenanceNotificationsEnabled(params['enabled'] as bool);
        await reconcile();
        return {'enabled': params['enabled']};
      case 'notifications.settings':
        final result = await notifications.openAppNotificationSettings();
        return {'status': result.status.name};
      case 'notifications.snooze':
        return _snooze(params);
      case 'timer.read':
        final tankId = await _requireTank(params);
        final drafts = await (database.select(
          database.activeTestSessions,
        )..where((row) => row.tankId.equals(tankId))).get();
        return {'sessions': drafts.map(_timerJson).toList()};
      case 'timer.schedule':
        return _scheduleTimer(params);
      case 'timer.cancel':
        return _cancelTimer(params);
      case 'photoDraft.save':
        final tankId = await _requireTank(params);
        return _photoDrafts.save(tankId: tankId, dataUrl: params['dataUrl']);
      case 'photoDraft.remove':
        final tankId = await _requireTank(params);
        await _photoDrafts.remove(tankId: tankId, token: params['photoToken']);
        return {'removed': true};
      case 'draft.read':
        final file = await _draftFile();
        if (!await file.exists()) return {'draft': null};
        if (await file.length() > 65536) return {'draft': null};
        try {
          return {'draft': jsonDecode(await file.readAsString())};
        } on FormatException {
          return {'draft': null};
        }
      case 'draft.save':
        final draft = params['draft'];
        _validateDraft(draft);
        final json = jsonEncode(draft);
        if (utf8.encode(json).length > 65536) {
          throw const FormatException('草稿过大，请减少输入。');
        }
        final file = await _draftFile();
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(json, flush: true);
        await temporary.rename(file.path);
        return {'saved': true};
      default:
        throw PlatformException(
          code: 'unsupported_method',
          message: '当前版本不支持此操作。',
        );
    }
  }

  Future<Map<String, dynamic>> _exclusiveFileOperation(
    Future<Map<String, dynamic>> Function() operation,
  ) async {
    if (_fileOperation) {
      throw PlatformException(code: 'busy', message: '正在处理文件，请稍后重试。');
    }
    _fileOperation = true;
    try {
      return await operation();
    } finally {
      _fileOperation = false;
    }
  }

  Future<Map<String, dynamic>> _pickBackup() async {
    await _clearCandidate();
    final selected = await transfer.pickCompleteBackup();
    if (selected == null) return {'cancelled': true};
    if (await selected.length() >
        CompleteBackupService.defaultMaximumArchiveBytes) {
      throw const FormatException('备份文件过大。');
    }
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'webview-restore'));
    await directory.create(recursive: true);
    final token = const Uuid().v4();
    // A fixed private staging slot also bounds disk use after a process kill.
    final file = await selected.copy(p.join(directory.path, 'candidate.zip'));
    try {
      final preview = await backup.validateFile(file);
      final digest = (await sha256.bind(file.openRead()).first).toString();
      _restoreCandidate = _RestoreCandidate(
        token,
        file,
        digest,
        DateTime.now(),
      );
      return {
        'cancelled': false,
        'token': token,
        'createdAt': preview.createdAtUtc.toIso8601String(),
        'formatVersion': preview.databaseFormatVersion,
      };
    } catch (_) {
      await file.delete();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _restoreBackup(
    Map<String, dynamic> params,
  ) async {
    final candidate = _restoreCandidate;
    if (params['confirmed'] != true ||
        candidate == null ||
        params['token'] != candidate.token ||
        DateTime.now().difference(candidate.createdAt) >
            const Duration(minutes: 10)) {
      throw const FormatException('请重新选择备份并确认恢复。');
    }
    final digest = (await sha256.bind(candidate.file.openRead()).first)
        .toString();
    if (digest != candidate.digest) {
      throw const FormatException('备份文件已变化，请重新选择。');
    }
    // Keep a recovery archive before replacing business data. Validation and
    // replacement remain the original service's single-transaction boundary.
    final previous = await backup.exportToPrivateFile();
    final oldTimers = await database.select(database.activeTestSessions).get();
    final report = await backup.restoreReplaceFromFile(candidate.file);

    // SQLite has committed. Device services and disposable files must not make
    // this successful replacement appear to have failed or invite a retry.
    final warnings = <String>{};
    var notificationWarning = false;
    Future<void> afterCommit(
      Future<void> Function() operation,
      String warning, {
      bool notification = false,
    }) async {
      try {
        await operation();
      } catch (_) {
        warnings.add(warning);
        notificationWarning |= notification;
      }
    }

    await afterCommit(_clearCandidate, '临时备份未清理，下次选择时会替换。');
    for (final session in oldTimers) {
      await afterCommit(
        () => notifications.cancel(testTimerNotificationId(session.id)),
        '数据已恢复，部分系统提醒未更新，请重新打开 App。',
        notification: true,
      );
    }
    await afterCommit(() async {
      final draft = await _draftFile();
      if (await draft.exists()) {
        await draft.writeAsString('null', flush: true);
      }
    }, '旧草稿未清理，请取消未提交的表单。');
    await afterCommit(
      reconcile,
      '数据已恢复，部分系统提醒未更新，请重新打开 App。',
      notification: true,
    );
    await afterCommit(
      _restoreTimers,
      '数据已恢复，部分系统提醒未更新，请重新打开 App。',
      notification: true,
    );
    return {
      'restored': true,
      'tankCount': report.result.insertedTankCount,
      'recordCount': report.result.insertedRecordCount,
      'taskCount': report.result.insertedTaskCount,
      'previousBackup': p.basename(previous.file.path),
      if (warnings.isNotEmpty) 'warnings': warnings.toList(),
      if (notificationWarning)
        'notificationWarning': '数据已恢复，部分系统提醒未更新，请重新打开 App。',
    };
  }

  Future<Map<String, dynamic>> _removeData(
    Map<String, dynamic> params, {
    required bool reset,
  }) async {
    final reminders = await NativeDataRemoval(
      database,
    ).execute(params, reset: reset);
    // The DB transaction committed. Cleanup failures cannot be reported as a
    // failed deletion: that would invite a destructive retry of newer data.
    final warnings = <String>{};
    for (final id in reminders) {
      final result = await notifications.cancel(id);
      if (!result.succeeded) warnings.add('数据已删除，部分系统提醒未取消，请检查系统通知设置。');
    }
    try {
      final file = await _draftFile();
      if (await file.exists()) {
        if (reset) {
          await file.writeAsString('null', flush: true);
        } else {
          final draft = jsonDecode(await file.readAsString());
          if (draft is Map && draft['sections'] is Map) {
            final sections = draft['sections'] as Map;
            sections.removeWhere(
              (key, value) =>
                  value is Map && value['tankId'] == params['tankId'],
            );
            final main = sections['main'];
            if (main is Map) main['tankModal'] = null;
            await file.writeAsString(jsonEncode(draft), flush: true);
          }
        }
      }
      await _photoDrafts.clear(
        tankId: reset ? null : params['tankId'] as String,
      );
      await _clearCandidate();
      if (reset) {
        final support = await getApplicationSupportDirectory();
        final temporary = await getTemporaryDirectory();
        final camera = Directory(p.join(temporary.path, 'webview-camera'));
        if (await camera.exists()) {
          await for (final entry in camera.list(followLinks: false)) {
            if (entry is File) await entry.delete();
          }
        }
        // Only app-owned generated exports; never touch files saved externally.
        for (final name in [
          'backups',
          'exports',
          p.join('webview-share-cache', 'backups'),
          p.join('webview-share-cache', 'exports'),
        ]) {
          final directory = Directory(p.join(support.path, name));
          if (await directory.exists()) {
            await for (final entry in directory.list(followLinks: false)) {
              if (entry is File) await entry.delete();
            }
          }
        }
      }
    } catch (_) {
      warnings.add('数据已删除，部分临时文件未清理，请重新打开 App。');
    }
    try {
      await reconcile();
    } catch (_) {
      warnings.add('数据已删除，请重新打开 App 更新系统提醒。');
    }
    return {
      'removed': true,
      if (warnings.isNotEmpty) 'warnings': warnings.toList(),
    };
  }

  Future<Map<String, dynamic>> _snooze(Map<String, dynamic> params) async {
    final tankId = await _requireTank(params);
    final minutes = _integer(
      params['minutes'],
      1,
      10080,
      '稍后提醒时间应为 1 分钟至 7 天。',
    );
    final now = DateTime.now(),
        until = DateTime.now().toUtc().add(Duration(minutes: minutes));
    final date = DateTime(now.year, now.month, now.day);
    final tomorrow = date.add(const Duration(days: 1));
    final items = await RepositoryMaintenanceNotificationTaskStore(
      tasks,
      cycles: cycles,
    ).watchAllTaskItems().first;
    final due = items
        .where(
          (item) =>
              item.task.tankId == tankId &&
              item.task.status == 'enabled' &&
              item.task.dueAt.toLocal().isBefore(tomorrow) &&
              !{
                MaintenanceTaskViewState.completed,
                MaintenanceTaskViewState.skipped,
                MaintenanceTaskViewState.archived,
                MaintenanceTaskViewState.disabled,
              }.contains(item.state),
        )
        .toList();
    await database.transaction(() async {
      for (final item in due) {
        if (item.task.source == 'maintenance-cycle') {
          final cycleId = item.task.id.substring('cycle-'.length);
          final row =
              await (database.select(database.maintenanceCycles)..where(
                    (row) => row.id.equals(cycleId) & row.tankId.equals(tankId),
                  ))
                  .getSingle();
          if (row.closedOnDate != null) continue;
          final input = jsonDecode(row.inputJson) as Map<String, dynamic>;
          input['webviewSnoozedUntil'] = until.toIso8601String();
          await (database.update(
            database.maintenanceCycles,
          )..where((row) => row.id.equals(cycleId))).write(
            MaintenanceCyclesCompanion(
              inputJson: Value(jsonEncode(input)),
              updatedAt: Value(now.toUtc()),
            ),
          );
        } else {
          // A reminder-only snooze must not mutate recurrence/rolling dates.
          // The OS coordinator consumes the deadline from this event while
          // the WebView adapter keeps it out of the task's date projection.
          await database
              .into(database.taskEvents)
              .insert(
                TaskEventsCompanion.insert(
                  id: const Uuid().v4(),
                  taskId: item.task.id,
                  type: TaskEventType.snoozed.name,
                  occurredAt: now.toUtc(),
                  snoozedUntil: Value(until),
                  note: const Value('webview-reminder-only'),
                ),
              );
        }
      }
    });
    await reconcile();
    return {'count': due.length, 'until': until.toIso8601String()};
  }

  Future<Map<String, dynamic>> _scheduleTimer(
    Map<String, dynamic> params,
  ) async {
    final tankId = await _requireTank(params);
    final parameterId = _parameterId(params['parameterId']);
    final seconds = _integer(
      params['durationSeconds'],
      TestTimerSnapshot.minimumDurationSeconds,
      TestTimerSnapshot.maximumDurationSeconds,
      '计时应为 10 秒至 60 分钟。',
    );
    final now = DateTime.now().toUtc();
    final endsAt = params['endsAt'] is String
        ? DateTime.tryParse(params['endsAt'] as String)?.toUtc()
        : now.add(Duration(seconds: seconds));
    if (endsAt == null ||
        !endsAt.isAfter(now) ||
        endsAt.difference(now).inSeconds > seconds + 2) {
      throw const FormatException('请核对计时结束时间。');
    }
    var session = await sessions.readDraft(
      tankId: tankId,
      parameterId: parameterId,
    );
    if (session == null) {
      await sessions.setDefaultDurationSeconds(
        tankId: tankId,
        parameterId: parameterId,
        durationSeconds: seconds,
      );
      final id = await sessions.createDraft(
        tankId: tankId,
        parameterId: parameterId,
      );
      session = await sessions.readDraftById(id);
    } else {
      await sessions.updateTimer(
        tankId: tankId,
        sessionId: session.id,
        startedAt: now,
        stage: ActiveTestStage.preparation,
      );
      await sessions.setPreparationDurationSeconds(
        tankId: tankId,
        sessionId: session.id,
        durationSeconds: seconds,
      );
    }
    await sessions.updateTimer(
      tankId: tankId,
      sessionId: session!.id,
      startedAt: now,
      timerEndsAt: endsAt,
      stage: ActiveTestStage.timerRunning,
    );
    final result = await _notifyTimer(session.id, endsAt);
    return {
      'sessionId': session.id,
      'endsAt': endsAt.toIso8601String(),
      'notification': result.status.name,
    };
  }

  Future<Map<String, dynamic>> _cancelTimer(Map<String, dynamic> params) async {
    final tankId = await _requireTank(params);
    final session = params['sessionId'] is String
        ? await sessions.readDraftByIdForTank(
            tankId: tankId,
            sessionId: params['sessionId'] as String,
          )
        : await sessions.readDraft(
            tankId: tankId,
            parameterId: _parameterId(params['parameterId']),
          );
    if (session == null) return {'cancelled': true};
    final paused = params['pausedRemainingSeconds'];
    await sessions.updateTimer(
      tankId: tankId,
      sessionId: session.id,
      startedAt: session.startedAt,
      pausedRemainingSeconds: paused == null
          ? null
          : _integer(paused, 1, session.timerDurationSeconds, '剩余计时无效。'),
      stage: paused == null
          ? params['completed'] == true
                ? ActiveTestStage.timerCompleted
                : ActiveTestStage.preparation
          : ActiveTestStage.timerPaused,
    );
    final result = await notifications.cancel(
      testTimerNotificationId(session.id),
    );
    return {'cancelled': result.succeeded, 'notification': result.status.name};
  }

  Future<NotificationOperationResult> _notifyTimer(
    String id,
    DateTime endsAt,
  ) => notifications.scheduleAtUtc(
    LocalNotificationRequest.testTimer(
      id: testTimerNotificationId(id),
      sessionId: id,
      title: '检测计时完成',
      body: '请返回 App 继续拍照或手动录入。',
    ),
    endsAt,
  );

  Future<void> _restoreTimers() async {
    final running =
        await (database.select(database.activeTestSessions)..where(
              (row) => row.stage.equals(ActiveTestStage.timerRunning.name),
            ))
            .get();
    final now = DateTime.now().toUtc();
    for (final session in running) {
      final endsAt = session.timerEndsAt;
      if (endsAt == null) continue;
      if (endsAt.isAfter(now)) {
        await _notifyTimer(session.id, endsAt.toUtc());
      } else {
        await sessions.completeElapsedTimer(
          tankId: session.tankId,
          sessionId: session.id,
          expectedEndsAt: endsAt,
          now: now,
        );
      }
    }
  }

  Future<void> _openNotification(LocalNotificationTap tap) async {
    final id = tap.payload.targetId;
    String? tankId;
    ActiveTestSession? timer;
    if (tap.payload.type == LocalNotificationType.testTimer) {
      timer = await sessions.readDraftById(id);
      tankId = timer?.tankId;
    } else if (id.startsWith('cycle-')) {
      tankId =
          (await (database.select(database.maintenanceCycles)
                    ..where((row) => row.id.equals(id.substring(6))))
                  .getSingleOrNull())
              ?.tankId;
    } else {
      tankId = (await (database.select(
        database.maintenanceTasks,
      )..where((row) => row.id.equals(id))).getSingleOrNull())?.tankId;
    }
    if (tankId == null) return;
    await emit('lanjiao:notification', {
      'type': tap.payload.type.name,
      'targetId': id,
      'tankId': tankId,
      if (timer != null) 'parameterId': _webParameterId(timer.parameterId),
      if (timer != null) 'session': _timerJson(timer),
    });
  }

  Future<String> _requireTank(Map<String, dynamic> params) async {
    final id = params['tankId'];
    if (id is! String || id.isEmpty) throw const FormatException('请先选择海缸。');
    final row =
        await (database.select(
              database.tanks,
            )..where((row) => row.id.equals(id) & row.isArchived.equals(false)))
            .getSingleOrNull();
    if (row == null) throw const FormatException('海缸不存在或已归档。');
    return id;
  }

  Future<File> _draftFile() async {
    final support = await getApplicationSupportDirectory();
    return File(p.join(support.path, 'webview-ui-draft.json'));
  }

  Future<void> _clearCandidate() async {
    final candidate = _restoreCandidate;
    _restoreCandidate = null;
    if (candidate != null && await candidate.file.exists()) {
      try {
        await candidate.file.delete();
      } on FileSystemException {
        // A disposable picker copy cannot turn a committed restore into an
        // apparent failure. The next pick can still replace the candidate.
      }
    }
  }

  Future<void> dispose() async {
    await _tapSubscription?.cancel();
    await _coordinator?.dispose();
    await _clearCandidate();
  }

  static int _integer(Object? value, int min, int max, String message) {
    if (value is! num ||
        !value.isFinite ||
        value != value.roundToDouble() ||
        value < min ||
        value > max) {
      throw FormatException(message);
    }
    return value.toInt();
  }

  static String _parameterId(Object? id) => switch (id) {
    'no3' => AppDatabase.no3Id,
    'po4' => AppDatabase.po4Id,
    'kh' => AppDatabase.khId,
    'ca' => AppDatabase.caId,
    'mg' => AppDatabase.mgId,
    'k' => AppDatabase.potassiumId,
    final String value when value.isNotEmpty => value,
    _ => throw const FormatException('请选择检测参数。'),
  };

  static Map<String, dynamic> _timerJson(ActiveTestSession session) => {
    'sessionId': session.id,
    'tankId': session.tankId,
    'parameterId': _webParameterId(session.parameterId),
    'durationSeconds': session.timerDurationSeconds,
    'endsAt': session.timerEndsAt?.toUtc().toIso8601String(),
    'pausedRemainingSeconds': session.pausedRemainingSeconds,
    'stage': session.stage,
  };

  static String _webParameterId(String id) => switch (id) {
    AppDatabase.no3Id => 'no3',
    AppDatabase.po4Id => 'po4',
    AppDatabase.khId => 'kh',
    AppDatabase.caId => 'ca',
    AppDatabase.mgId => 'mg',
    AppDatabase.potassiumId => 'k',
    _ => id,
  };

  static void _validateDraft(Object? value, [int depth = 0]) {
    if (depth > 8) throw const FormatException('草稿结构过深。');
    if (value == null || value is bool || value is num && value.isFinite) {
      return;
    }
    if (value is String && value.length <= 2048 && !value.startsWith('data:')) {
      return;
    }
    if (value is List && value.length <= 100) {
      for (final item in value) {
        _validateDraft(item, depth + 1);
      }
      return;
    }
    if (value is Map && value.length <= 100) {
      for (final entry in value.entries) {
        if (entry.key is! String || (entry.key as String).length > 100) {
          throw const FormatException('草稿字段无效。');
        }
        _validateDraft(entry.value, depth + 1);
      }
      return;
    }
    throw const FormatException('草稿包含不支持的数据。');
  }
}

class _RestoreCandidate {
  const _RestoreCandidate(this.token, this.file, this.digest, this.createdAt);
  final String token, digest;
  final File file;
  final DateTime createdAt;
}

class _WebViewNotificationStore implements MaintenanceNotificationTaskStore {
  const _WebViewNotificationStore(this.database, this.delegate);
  final AppDatabase database;
  final MaintenanceNotificationTaskStore delegate;

  @override
  Future<void> persistNotificationId({
    required String tankId,
    required String taskId,
    required int notificationId,
  }) => delegate.persistNotificationId(
    tankId: tankId,
    taskId: taskId,
    notificationId: notificationId,
  );

  @override
  Stream<List<MaintenanceTaskItem>> watchAllTaskItems() =>
      delegate.watchAllTaskItems().asyncMap((items) async {
        final cycles = await database.select(database.maintenanceCycles).get();
        final snoozes = <String, DateTime>{};
        for (final row in cycles) {
          if (row.closedOnDate != null) continue;
          final value =
              (jsonDecode(row.inputJson)
                  as Map<String, dynamic>)['webviewSnoozedUntil'];
          final until = value is String
              ? DateTime.tryParse(value)?.toUtc()
              : null;
          if (until != null && until.isAfter(DateTime.now().toUtc())) {
            snoozes['cycle-${row.id}'] = until;
          }
        }
        return [
          for (final item in items)
            if (snoozes[item.task.id] case final DateTime until)
              MaintenanceTaskItem(
                task: item.task,
                state: item.state,
                occurrenceDate: item.occurrenceDate,
                cycleOccurrence: item.cycleOccurrence,
                latestEvent: TaskEvent(
                  id: 'webview-snooze-${item.task.id}',
                  taskId: item.task.id,
                  type: 'snoozed',
                  occurredAt: item.task.updatedAt,
                  snoozedUntil: until,
                ),
              )
            else
              item,
        ];
      });
}
