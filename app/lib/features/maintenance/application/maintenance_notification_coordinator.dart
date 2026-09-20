import 'dart:async';
import 'dart:convert';

import '../../../core/logging/app_logger.dart';
import '../../../core/notifications/local_notification.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../data/maintenance_repository.dart';
import '../domain/recurrence.dart';
import '../domain/rolling_schedule.dart';
import '../../calculators/data/maintenance_cycle_repository.dart';
import '../../calculators/domain/maintenance_cycle.dart';
import 'maintenance_cycle_items.dart';

abstract interface class MaintenanceNotificationTaskStore {
  Stream<List<MaintenanceTaskItem>> watchAllTaskItems();

  Future<void> persistNotificationId({
    required String tankId,
    required String taskId,
    required int notificationId,
  });
}

final class RepositoryMaintenanceNotificationTaskStore
    implements MaintenanceNotificationTaskStore {
  const RepositoryMaintenanceNotificationTaskStore(
    this._repository, {
    this.cycles,
  });

  final MaintenanceRepository _repository;
  final MaintenanceCycleRepository? cycles;

  @override
  Stream<List<MaintenanceTaskItem>> watchAllTaskItems() {
    List<MaintenanceTaskItem>? tasks;
    List<MaintenanceCycle>? reservoirs = cycles == null ? [] : null;
    Set<String>? activeTanks;
    StreamSubscription<Set<String>>? tankSub;
    StreamSubscription<List<MaintenanceTaskItem>>? taskSub;
    StreamSubscription<List<MaintenanceCycle>>? cycleSub;
    late StreamController<List<MaintenanceTaskItem>> controller;
    void emit() {
      if (tasks != null &&
          reservoirs != null &&
          activeTanks != null &&
          !controller.isClosed) {
        controller.add([
          for (final item in [
            ...tasks!,
            ...maintenanceCycleNotificationItems(reservoirs!, DateTime.now()),
          ])
            if (activeTanks!.contains(item.task.tankId))
              item
            else
              MaintenanceTaskItem(
                task: item.task.copyWith(status: 'disabled'),
                state: MaintenanceTaskViewState.disabled,
              ),
        ]);
      }
    }

    controller = StreamController(
      onListen: () {
        taskSub = _repository.watchAllTaskItems().listen((value) {
          tasks = value;
          emit();
        }, onError: controller.addError);
        tankSub = _repository.watchActiveTankIds().listen((value) {
          activeTanks = value;
          emit();
        }, onError: controller.addError);
        cycleSub = cycles?.watchCycles().listen((value) {
          reservoirs = value;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await taskSub?.cancel();
        await cycleSub?.cancel();
        await tankSub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> persistNotificationId({
    required String tankId,
    required String taskId,
    required int notificationId,
  }) {
    if (taskId.startsWith('cycle-') && cycles != null) {
      return cycles!.setNotificationId(taskId.substring(6), notificationId);
    }
    return _repository.setNotificationId(
      tankId: tankId,
      taskId: taskId,
      notificationId: notificationId,
    );
  }
}

enum MaintenanceNotificationSyncPhase {
  idle,
  syncing,
  ready,
  permissionDenied,
  unavailable,
  failed,
}

final class MaintenanceNotificationSyncState {
  const MaintenanceNotificationSyncState({
    required this.phase,
    this.scheduledCount = 0,
    this.cancelledCount = 0,
    this.failedCount = 0,
  });

  static const idle = MaintenanceNotificationSyncState(
    phase: MaintenanceNotificationSyncPhase.idle,
  );

  final MaintenanceNotificationSyncPhase phase;
  final int scheduledCount;
  final int cancelledCount;
  final int failedCount;
}

final class MaintenanceNotificationPlan {
  const MaintenanceNotificationPlan({
    required this.dueReminderAtUtc,
    required this.dailyReminderStartsAtDeviceLocal,
  });

  /// Exact due/snooze delivery. Null once the effective due instant has passed.
  final DateTime? dueReminderAtUtc;

  /// First daily overdue delivery at the user's preferred device-local time.
  final DateTime dailyReminderStartsAtDeviceLocal;
}

/// Calculates all required OS schedules without mutating task data.
///
/// A currently active snooze overrides the task due time. A future effective
/// due instant receives both an exact one-shot reminder and a daily overdue
/// reminder beginning at the first preferred wall-clock time after it. An
/// already-overdue task only needs the daily schedule.
MaintenanceNotificationPlan buildMaintenanceNotificationPlan(
  MaintenanceTaskItem item, {
  required DateTime nowUtc,
  required DateTime nowDeviceLocal,
  DateTime Function(DateTime utc)? toDeviceLocal,
}) {
  if (!nowUtc.isUtc) {
    throw ArgumentError.value(nowUtc, 'nowUtc', 'must be UTC');
  }
  if (nowDeviceLocal.isUtc) {
    throw ArgumentError.value(
      nowDeviceLocal,
      'nowDeviceLocal',
      'must be a device-local wall-clock value',
    );
  }

  // WebView's reminder-only event does not revise the rolling schedule. It
  // still takes precedence when a task already has completion/delay revisions;
  // the legacy helper deliberately ignores ordinary snoozes in that case.
  final reminderOnlyUntil = item.latestEvent?.note == 'webview-reminder-only'
      ? activeMaintenanceSnoozeUntilUtc(item.latestEvent, nowUtc)
      : null;
  final effectiveAtUtc =
      reminderOnlyUntil ??
      effectiveMaintenanceDueAtUtc(item.task, item.latestEvent, nowUtc);
  final isFuture = effectiveAtUtc.isAfter(nowUtc);
  final dailyAnchor = isFuture
      ? (toDeviceLocal ?? _toSystemLocal)(effectiveAtUtc)
      : nowDeviceLocal;
  if (dailyAnchor.isUtc) {
    throw ArgumentError.value(
      dailyAnchor,
      'toDeviceLocal',
      'must return a device-local wall-clock value',
    );
  }
  final reminderTime = _parseReminderTime(item.task.preferredReminderTime);
  return MaintenanceNotificationPlan(
    dueReminderAtUtc: isFuture ? effectiveAtUtc : null,
    dailyReminderStartsAtDeviceLocal: _nextPreferredReminderAfter(
      dailyAnchor,
      hour: reminderTime.$1,
      minute: reminderTime.$2,
    ),
  );
}

/// Reconciles database truth into replaceable OS notifications.
///
/// Database writes are limited to tasks missing a stable notification id. The
/// applied-plan cache prevents that write's Drift emission from creating a
/// watch -> update loop or repeatedly rescheduling an unchanged notification.
final class MaintenanceNotificationCoordinator {
  factory MaintenanceNotificationCoordinator({
    required MaintenanceNotificationTaskStore taskStore,
    required LocalNotificationService notificationService,
    Stream<bool>? notificationsEnabled,
    DateTime Function()? nowUtc,
    DateTime Function()? nowDeviceLocal,
    DateTime Function(DateTime utc)? toDeviceLocal,
    AppLogger logger = const DebugAppLogger(),
  }) => MaintenanceNotificationCoordinator._(
    taskStore,
    notificationService,
    notificationsEnabled,
    nowUtc ?? _systemUtcNow,
    nowDeviceLocal ?? DateTime.now,
    toDeviceLocal ?? _toSystemLocal,
    logger,
  );

  MaintenanceNotificationCoordinator._(
    this._taskStore,
    this._notificationService,
    this._notificationsEnabledChanges,
    this._nowUtc,
    this._nowDeviceLocal,
    this._toDeviceLocal,
    this._logger,
  );

  static const int _maintenanceIdStart = 0x10000000;
  static const int _maintenanceIdEnd = 0x1fffffff;
  static const int _dailyIdOffset = 0x10000000;
  static const int _legacyMaintenanceIdEnd = 0x3fffffff;

  final MaintenanceNotificationTaskStore _taskStore;
  final LocalNotificationService _notificationService;
  final Stream<bool>? _notificationsEnabledChanges;
  final DateTime Function() _nowUtc;
  final DateTime Function() _nowDeviceLocal;
  final DateTime Function(DateTime utc) _toDeviceLocal;
  final AppLogger _logger;
  final StreamController<MaintenanceNotificationSyncState> _stateController =
      StreamController<MaintenanceNotificationSyncState>.broadcast();

  StreamSubscription<List<MaintenanceTaskItem>>? _subscription;
  StreamSubscription<bool>? _enabledSubscription;
  Future<void> _queue = Future<void>.value();
  List<MaintenanceTaskItem>? _pendingItems;
  bool _pendingForce = false;
  bool _draining = false;
  List<MaintenanceTaskItem>? _latestItems;
  final _appliedPlanSignatures =
      <String, ({String signature, String? scheduleKey})>{};
  final Map<String, int> _knownNotificationIds = <String, int>{};
  var _state = MaintenanceNotificationSyncState.idle;
  bool _started = false;
  bool _disposed = false;
  late bool _notificationsEnabled = _notificationsEnabledChanges == null;

  MaintenanceNotificationSyncState get currentState => _state;

  Stream<MaintenanceNotificationSyncState> get states =>
      _stateController.stream;

  Future<void> start() async {
    if (_started || _disposed) {
      return;
    }
    _started = true;

    _enabledSubscription = _notificationsEnabledChanges?.distinct().listen((
      enabled,
    ) {
      _notificationsEnabled = enabled;
      final items = _latestItems;
      if (items != null) unawaited(_enqueue(items, force: true));
    });

    final initialization = await _notificationService.initialize();
    if (_disposed) {
      return;
    }
    if (!initialization.succeeded) {
      _emit(
        const MaintenanceNotificationSyncState(
          phase: MaintenanceNotificationSyncPhase.unavailable,
          failedCount: 1,
        ),
      );
    }

    _subscription = _taskStore.watchAllTaskItems().listen(
      (items) {
        _latestItems = List<MaintenanceTaskItem>.unmodifiable(items);
        unawaited(_enqueue(_latestItems!, force: false));
      },
      onError: (Object error, StackTrace stackTrace) {
        _logger.error(
          'maintenance_notification_watch_failed',
          error: error,
          stackTrace: stackTrace,
        );
        _emit(
          const MaintenanceNotificationSyncState(
            phase: MaintenanceNotificationSyncPhase.failed,
            failedCount: 1,
          ),
        );
      },
    );
  }

  /// Permissions and lifecycle changes force OS schedules to be refreshed.
  /// Ordinary data saves can retain matching schedules via [force] = false.
  Future<void> reconcileNow({bool force = true}) async {
    if (_disposed) {
      return;
    }
    await _notificationService.initialize();
    final items = _latestItems;
    if (items != null) {
      await _enqueue(items, force: force);
    }
  }

  Future<void> _enqueue(
    List<MaintenanceTaskItem> items, {
    required bool force,
  }) {
    if (_disposed) return Future.value();
    _pendingItems = items;
    _pendingForce = _pendingForce || force;
    if (_draining) return _queue;
    _draining = true;
    _queue = Future<void>(() async {
      try {
        while (!_disposed && _pendingItems != null) {
          final latest = _pendingItems!, forced = _pendingForce;
          _pendingItems = null;
          _pendingForce = false;
          try {
            await _reconcile(latest, force: forced);
          } catch (error, stackTrace) {
            _logger.error(
              'maintenance_notification_reconcile_failed',
              error: error,
              stackTrace: stackTrace,
            );
            _emit(
              const MaintenanceNotificationSyncState(
                phase: MaintenanceNotificationSyncPhase.failed,
                failedCount: 1,
              ),
            );
          }
        }
      } finally {
        _draining = false;
        if (_disposed) {
          _pendingItems = null;
          _latestItems = null;
        }
      }
    });
    return _queue;
  }

  Future<void> _reconcile(
    List<MaintenanceTaskItem> items, {
    required bool force,
  }) async {
    _emit(
      const MaintenanceNotificationSyncState(
        phase: MaintenanceNotificationSyncPhase.syncing,
      ),
    );

    var scheduledCount = 0;
    var cancelledCount = 0;
    var failedCount = 0;
    var permissionDenied = false;
    var unavailable = false;

    void recordFailureStatus(NotificationOperationResult result) {
      switch (result.status) {
        case NotificationOperationStatus.permissionDenied:
          permissionDenied = true;
          break;
        case NotificationOperationStatus.unsupported:
        case NotificationOperationStatus.unavailable:
          unavailable = true;
          break;
        case NotificationOperationStatus.invalidRequest:
        case NotificationOperationStatus.failed:
        case NotificationOperationStatus.succeeded:
          break;
      }
    }

    Future<bool> cancelId(int notificationId) async {
      final result = await _notificationService.cancel(notificationId);
      if (result.succeeded) {
        cancelledCount += 1;
        return true;
      }
      failedCount += 1;
      recordFailureStatus(result);
      return false;
    }

    Future<bool> cancelPair(
      int dueNotificationId, {
      bool preserveElapsedDue = false,
    }) async {
      final dueCancelled =
          preserveElapsedDue || await cancelId(dueNotificationId);
      final dailyCancelled = await cancelId(
        maintenanceDailyNotificationId(dueNotificationId),
      );
      var finiteCancelled = true;
      for (final id in finiteMaintenanceNotificationIds(dueNotificationId)) {
        finiteCancelled = await cancelId(id) && finiteCancelled;
      }
      return dueCancelled && dailyCancelled && finiteCancelled;
    }

    final currentTaskIds = items.map((item) => item.task.id).toSet();
    for (final previous in _knownNotificationIds.entries.toList()) {
      if (currentTaskIds.contains(previous.key)) continue;
      if (await cancelPair(previous.value)) {
        _appliedPlanSignatures.remove(previous.key);
        _knownNotificationIds.remove(previous.key);
      }
    }
    _appliedPlanSignatures.removeWhere(
      (taskId, _) => !currentTaskIds.contains(taskId),
    );

    if (!_notificationsEnabled) {
      for (final item in items) {
        final notificationId = item.task.notificationId;
        if (_isValidMaintenanceBaseNotificationId(notificationId)) {
          final signature = 'notifications-disabled:$notificationId';
          if (!force &&
              _appliedPlanSignatures[item.task.id]?.signature == signature) {
            continue;
          }
          if (await cancelPair(notificationId!)) {
            _appliedPlanSignatures[item.task.id] = (
              signature: signature,
              scheduleKey: null,
            );
          } else {
            _appliedPlanSignatures.remove(item.task.id);
          }
        } else {
          _appliedPlanSignatures.remove(item.task.id);
        }
      }
      _emit(
        MaintenanceNotificationSyncState(
          phase: unavailable
              ? MaintenanceNotificationSyncPhase.unavailable
              : failedCount > 0
              ? MaintenanceNotificationSyncPhase.failed
              : MaintenanceNotificationSyncPhase.ready,
          cancelledCount: cancelledCount,
          failedCount: failedCount,
        ),
      );
      return;
    }

    bool recordScheduleResult(NotificationOperationResult result) {
      if (result.succeeded) {
        scheduledCount += 1;
        return true;
      }
      failedCount += 1;
      recordFailureStatus(result);
      return false;
    }

    final projectionNow = _nowUtc().toUtc();
    final projected = prepareMaintenanceTaskItems(
      items.where((item) => item.task.source != 'maintenance-cycle').toList(),
      projectionNow,
    );
    final chemicalHeads = <String, String>{};
    for (final item in [
      ...projected,
    ]..sort((a, b) => a.task.dueAt.compareTo(b.task.dueAt))) {
      final key = rollingChemicalKey(item.task);
      if (key != null && item.task.status == 'enabled') {
        chemicalHeads.putIfAbsent(key, () => item.task.id);
      }
    }
    final sortedItems =
        [
          for (final item in projected)
            if (rollingChemicalKey(item.task) != null &&
                item.task.status == 'enabled' &&
                chemicalHeads[rollingChemicalKey(item.task)] != item.task.id)
              MaintenanceTaskItem(
                task: item.task.copyWith(status: 'disabled'),
                state: MaintenanceTaskViewState.disabled,
              )
            else
              item,
          for (final item in items.where(
            (item) => item.task.source == 'maintenance-cycle',
          ))
            if (item.cycleOccurrence != null && item.task.status == 'enabled')
              ...maintenanceCycleNotificationItems([
                item.cycleOccurrence!.cycle,
              ], projectionNow).map(
                (projected) => MaintenanceTaskItem(
                  task: projected.task,
                  state: projected.state,
                  occurrenceDate: projected.occurrenceDate,
                  cycleOccurrence: projected.cycleOccurrence,
                  latestEvent: item.latestEvent,
                ),
              )
            else
              item,
        ]..sort((left, right) {
          final statusComparison = _statusPriority(
            left.task.status,
          ).compareTo(_statusPriority(right.task.status));
          return statusComparison != 0
              ? statusComparison
              : left.task.id.compareTo(right.task.id);
        });
    final reservedIds = <int>{
      for (final item in sortedItems)
        if (_isValidMaintenanceBaseNotificationId(item.task.notificationId))
          item.task.notificationId!,
    };
    final claimedIds = <int, String>{};
    final resolvedIds = <String, int>{};
    final legacyIds = <int>{};

    for (final item in sortedItems) {
      final task = item.task;
      final existingId =
          _isValidMaintenanceBaseNotificationId(task.notificationId)
          ? task.notificationId
          : null;
      if (existingId != null && !claimedIds.containsKey(existingId)) {
        claimedIds[existingId] = task.id;
        resolvedIds[task.id] = existingId;
        continue;
      }

      final storedId = task.notificationId;
      if (_isLegacyMaintenanceNotificationId(storedId)) {
        legacyIds.add(storedId!);
      }
      if (task.status != MaintenanceTaskStatus.enabled.name) {
        continue;
      }

      final allocatedId = stableMaintenanceNotificationId(
        task.id,
        reservedIds: reservedIds,
        finite: item.cycleOccurrence?.cycle.theory != null,
      );
      try {
        await _taskStore.persistNotificationId(
          tankId: task.tankId,
          taskId: task.id,
          notificationId: allocatedId,
        );
        reservedIds.add(allocatedId);
        claimedIds[allocatedId] = task.id;
        resolvedIds[task.id] = allocatedId;
      } catch (error, stackTrace) {
        failedCount += 1;
        _logger.error(
          'maintenance_notification_id_persist_failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    // IDs issued by the former single-notification implementation overlap the
    // new daily-ID namespace. Cancel them before scheduling any new pair.
    for (final legacyId in legacyIds) {
      await cancelId(legacyId);
    }

    final nowUtc = _nowUtc().toUtc();
    final nowDeviceLocal = _nowDeviceLocal();
    for (final rawItem in sortedItems) {
      final item = notificationOccurrence(rawItem, nowUtc);
      final task = item.task;
      final notificationId = resolvedIds[task.id];
      final previousId = _knownNotificationIds[task.id];
      if (previousId != null &&
          previousId != notificationId &&
          !claimedIds.containsKey(previousId)) {
        if (await cancelPair(previousId)) {
          _knownNotificationIds.remove(task.id);
          _appliedPlanSignatures.remove(task.id);
        }
      }
      if (notificationId == null) {
        continue;
      }
      _knownNotificationIds[task.id] = notificationId;

      if (task.status != MaintenanceTaskStatus.enabled.name) {
        final signature = 'inactive:$notificationId';
        if (!force && _appliedPlanSignatures[task.id]?.signature == signature) {
          continue;
        }
        if (await cancelPair(notificationId)) {
          _appliedPlanSignatures[task.id] = (
            signature: signature,
            scheduleKey: null,
          );
        } else {
          _appliedPlanSignatures.remove(task.id);
        }
        continue;
      }

      late final MaintenanceNotificationPlan plan;
      try {
        plan = buildMaintenanceNotificationPlan(
          item,
          nowUtc: nowUtc,
          nowDeviceLocal: nowDeviceLocal,
          toDeviceLocal: _toDeviceLocal,
        );
      } catch (error, stackTrace) {
        failedCount += 1;
        _appliedPlanSignatures.remove(task.id);
        _logger.error(
          'maintenance_notification_plan_failed',
          error: error,
          stackTrace: stackTrace,
        );
        continue;
      }
      final dailyNotificationId = maintenanceDailyNotificationId(
        notificationId,
      );
      final signature = <Object>[
        notificationId,
        dailyNotificationId,
        task.title,
        plan.dueReminderAtUtc?.microsecondsSinceEpoch ?? 'overdue',
        plan.dailyReminderStartsAtDeviceLocal.microsecondsSinceEpoch,
        task.recurrenceJson ?? 'legacy',
        task.rollingJson ?? 'legacy-schedule',
        item.cycleOccurrence?.cycle.theory?.endDate ?? 'unbounded',
        if (item.cycleOccurrence?.cycle.theory != null)
          cycleDateKey(nowDeviceLocal),
      ].join(':');
      final applied = _appliedPlanSignatures[task.id];
      if (!force && applied?.signature == signature) {
        continue;
      }

      final scheduleKey = jsonEncode([task.recurrenceJson, task.rollingJson]);
      // Android may still be delivering an inexact due/snooze alarm after its
      // deadline. Refreshing an unchanged pending task must not cancel it.
      // A changed recurrence/completion or a future due time replaces it;
      // inactive/removed tasks always cancel through the branches above.
      await cancelPair(
        notificationId,
        preserveElapsedDue:
            plan.dueReminderAtUtc == null &&
            (applied?.scheduleKey == null ||
                applied?.scheduleKey == scheduleKey),
      );

      var allScheduled = true;
      final dueReminderAtUtc = plan.dueReminderAtUtc;
      if (dueReminderAtUtc != null &&
          (item.cycleOccurrence?.cycle.theory == null ||
              cycleDateKey(
                    _toDeviceLocal(dueReminderAtUtc),
                  ).compareTo(item.cycleOccurrence!.cycle.theory!.endDate) <
                  0)) {
        final dueRequest = LocalNotificationRequest.maintenanceTask(
          id: notificationId,
          taskId: task.id,
          title: task.title,
          body: '维护任务已到计划时间。打开 App 查看并处理。',
        );
        final result = await _notificationService.scheduleAtUtc(
          dueRequest,
          dueReminderAtUtc,
        );
        allScheduled = recordScheduleResult(result) && allScheduled;
      }

      final dailyRequest = LocalNotificationRequest.maintenanceTask(
        id: dailyNotificationId,
        taskId: task.id,
        title: task.title,
        body: '维护任务仍待处理。打开 App 查看并处理。',
      );
      final theory = item.cycleOccurrence?.cycle.theory;
      if (theory != null) {
        // Finite exact alarms cannot leak beyond the course end while the app
        // is closed. Resume/reconcile replenishes a bounded 30-day window.
        final first = plan.dailyReminderStartsAtDeviceLocal;
        final windowStart = DateTime(first.year, first.month, first.day);
        final allIds = finiteMaintenanceNotificationIds(
          notificationId,
        ).toList();
        final ids = cycleNeedsRefill(item.cycleOccurrence!.cycle)
            ? allIds.take(30).toList()
            : <int>[];
        for (var offset = 0; offset < ids.length; offset++) {
          final date = DateTime(
            windowStart.year,
            windowStart.month,
            windowStart.day + offset,
            first.hour,
            first.minute,
          );
          if (date.isBefore(first) ||
              !date.isAfter(nowDeviceLocal) ||
              cycleDateKey(date).compareTo(theory.endDate) >= 0) {
            continue;
          }
          final result = await _notificationService.scheduleAtDeviceLocalTime(
            LocalNotificationRequest.maintenanceTask(
              id: ids[offset],
              taskId: task.id,
              title: task.title,
              body: '滴定液需要补充，打开 App 查看并处理。',
            ),
            date,
          );
          allScheduled = recordScheduleResult(result) && allScheduled;
        }
        final end = DateTime.parse(theory.endDate);
        var endAt = DateTime(end.year, end.month, end.day, 9);
        if (dueReminderAtUtc != null &&
            cycleDateKey(_toDeviceLocal(dueReminderAtUtc)) == theory.endDate &&
            _toDeviceLocal(dueReminderAtUtc).isAfter(endAt)) {
          endAt = _toDeviceLocal(dueReminderAtUtc);
        }
        if (endAt.isAfter(nowDeviceLocal) && allIds.length > 30) {
          final result = await _notificationService.scheduleAtDeviceLocalTime(
            LocalNotificationRequest.maintenanceTask(
              id: allIds[30],
              taskId: task.id,
              title:
                  '${item.cycleOccurrence!.cycle.chemical.name.toUpperCase()} 理论计划最后一天',
              body:
                  '复测后按末日时长执行并停止。${cycleNeedsRefill(item.cycleOccurrence!.cycle) ? '滴定液不足时先补充；' : ''}App 不控制泵。',
            ),
            endAt,
          );
          allScheduled = recordScheduleResult(result) && allScheduled;
        }
      } else if (task.recurrenceJson != null && task.rollingJson == null) {
        // Two bounded exact occurrences, never daily alerts on non-occurrence
        // dates. Opening/resuming the app or a task mutation refills this window.
        final dueDate = localDate(task.dueAt);
        final next = notificationOccurrence(
          item,
          DateTime(dueDate.year, dueDate.month, dueDate.day + 1),
        );
        if (next.task.status == 'enabled') {
          final nextResult = await _notificationService.scheduleAtUtc(
            dailyRequest,
            next.task.dueAt.toUtc(),
          );
          allScheduled = recordScheduleResult(nextResult) && allScheduled;
        }
      } else {
        final dailyResult = await _notificationService
            .scheduleDailyAtDeviceLocalTime(
              dailyRequest,
              plan.dailyReminderStartsAtDeviceLocal,
            );
        allScheduled = recordScheduleResult(dailyResult) && allScheduled;
      }
      if (allScheduled) {
        _appliedPlanSignatures[task.id] = (
          signature: signature,
          scheduleKey: scheduleKey,
        );
      } else {
        _appliedPlanSignatures.remove(task.id);
      }
    }

    final phase = permissionDenied
        ? MaintenanceNotificationSyncPhase.permissionDenied
        : unavailable
        ? MaintenanceNotificationSyncPhase.unavailable
        : failedCount > 0
        ? MaintenanceNotificationSyncPhase.failed
        : MaintenanceNotificationSyncPhase.ready;
    _emit(
      MaintenanceNotificationSyncState(
        phase: phase,
        scheduledCount: scheduledCount,
        cancelledCount: cancelledCount,
        failedCount: failedCount,
      ),
    );
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _pendingItems = null;
    _latestItems = null;
    await _subscription?.cancel();
    await _enabledSubscription?.cancel();
    await _queue;
    await _stateController.close();
  }

  void _emit(MaintenanceNotificationSyncState state) {
    if (_disposed) {
      return;
    }
    _state = state;
    _stateController.add(state);
  }
}

int stableMaintenanceNotificationId(
  String taskId, {
  Set<int> reservedIds = const <int>{},
  bool finite = false,
}) {
  if (taskId.trim().isEmpty) {
    throw ArgumentError.value(taskId, 'taskId', 'must not be empty');
  }

  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(taskId)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  final start = finite ? 0x10000000 : 0x10800000;
  final end = finite
      ? 0x107fffff
      : MaintenanceNotificationCoordinator._maintenanceIdEnd;
  final range = end - start + 1;
  var candidate = start + hash % range;
  for (var attempt = 0; attempt < range; attempt += 1) {
    if (!reservedIds.contains(candidate)) {
      return candidate;
    }
    candidate += 1;
    if (candidate > end) {
      candidate = start;
    }
  }
  throw StateError('维护任务通知 ID 空间已耗尽');
}

/// A collision-free, cancellable block allocated from a persisted finite base.
/// Stable cycles and timers use different namespaces; last slot stays reserved.
Iterable<int> finiteMaintenanceNotificationIds(int baseId) sync* {
  if (baseId < 0x10000000 || baseId > 0x107fffff) return;
  for (var slot = 0; slot < 31; slot++) {
    yield 0x30000000 | ((baseId - 0x10000000) << 5) | slot;
  }
}

/// Deterministic daily-overdue companion for a persisted due notification ID.
int maintenanceDailyNotificationId(int dueNotificationId) {
  if (!_isValidMaintenanceBaseNotificationId(dueNotificationId)) {
    throw ArgumentError.value(
      dueNotificationId,
      'dueNotificationId',
      'must be a maintenance due-notification ID',
    );
  }
  return dueNotificationId + MaintenanceNotificationCoordinator._dailyIdOffset;
}

int _statusPriority(String status) => switch (status) {
  'enabled' => 0,
  'disabled' => 1,
  'archived' => 2,
  _ => 3,
};

bool _isValidMaintenanceBaseNotificationId(int? value) =>
    value != null &&
    value >= MaintenanceNotificationCoordinator._maintenanceIdStart &&
    value <= MaintenanceNotificationCoordinator._maintenanceIdEnd;

bool _isLegacyMaintenanceNotificationId(int? value) =>
    value != null &&
    value > MaintenanceNotificationCoordinator._maintenanceIdEnd &&
    value <= MaintenanceNotificationCoordinator._legacyMaintenanceIdEnd;

(int, int) _parseReminderTime(String value) {
  if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) {
    throw FormatException('Invalid preferred reminder time: $value');
  }
  return (int.parse(value.substring(0, 2)), int.parse(value.substring(3, 5)));
}

DateTime _nextPreferredReminderAfter(
  DateTime anchorDeviceLocal, {
  required int hour,
  required int minute,
}) {
  var candidate = DateTime(
    anchorDeviceLocal.year,
    anchorDeviceLocal.month,
    anchorDeviceLocal.day,
    hour,
    minute,
  );
  if (!candidate.isAfter(anchorDeviceLocal)) {
    candidate = DateTime(
      anchorDeviceLocal.year,
      anchorDeviceLocal.month,
      anchorDeviceLocal.day + 1,
      hour,
      minute,
    );
  }
  return candidate;
}

DateTime _systemUtcNow() => DateTime.now().toUtc();

DateTime _toSystemLocal(DateTime utc) => utc.toLocal();
