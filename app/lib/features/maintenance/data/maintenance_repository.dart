import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database/app_database.dart';
import '../../calculators/domain/lanthanum_calculator.dart';
import '../../calculators/domain/alkalinity_calculator.dart';
import '../domain/recurrence.dart';

enum MaintenanceIntervalUnit { day, week, month }

enum MaintenanceTaskStatus { enabled, disabled, archived, completed, skipped }

enum TaskEventType { completed, skipped, snoozed }

enum MaintenanceTaskFilter { pending, completed, all }

enum MaintenanceTaskViewState {
  upcoming,
  overdue,
  snoozed,
  completed,
  skipped,
  disabled,
  archived,
}

class MaintenanceTaskItem {
  const MaintenanceTaskItem({
    required this.task,
    required this.state,
    this.latestEvent,
    this.occurrenceDate,
  });

  final MaintenanceTask task;
  final TaskEvent? latestEvent;
  final MaintenanceTaskViewState state;
  final DateTime? occurrenceDate;
}

class MaintenanceTaskHistoryEntry {
  const MaintenanceTaskHistoryEntry({required this.task, required this.event});

  final MaintenanceTask task;
  final TaskEvent event;
}

/// Time-dependent state can change without a database write (for example a
/// snooze expires). Reuse stored rows instead of invalidating SQL streams.
MaintenanceTaskItem refreshMaintenanceItem(
  MaintenanceTaskItem item,
  DateTime now,
) => MaintenanceTaskItem(
  task: item.task,
  latestEvent: item.latestEvent,
  occurrenceDate: item.occurrenceDate,
  state: _viewState(item.task, item.latestEvent, now.toUtc()),
);

class MaintenanceRepository {
  factory MaintenanceRepository(
    AppDatabase database, {
    Uuid uuid = const Uuid(),
    DateTime Function()? now,
  }) => MaintenanceRepository._(database, uuid, now ?? _systemUtcNow);

  MaintenanceRepository._(this._database, this._uuid, this._now);

  final AppDatabase _database;
  final Uuid _uuid;
  final DateTime Function() _now;

  /// Read the current per-tank target, not a cached page/provider value.
  /// Called both before showing a plan and inside the write transaction.
  Future<void> validateChemicalTarget({
    required String tankId,
    required String parameterId,
    required double targetValue,
  }) async {
    if (parameterId != AppDatabase.po4Id && parameterId != AppDatabase.khId) {
      throw ArgumentError('只支持 PO4 或 KH 计划目标');
    }
    final po4 = parameterId == AppDatabase.po4Id;
    if (!targetValue.isFinite ||
        targetValue < (po4 ? minimumTargetPo4MgL : 0)) {
      throw FormatException(po4 ? 'PO4 目标不得低于 0.03 mg/L。' : 'KH 目标必须是有效非负数。');
    }
    final range =
        await (_database.select(_database.waterQualityTargets)..where(
              (t) =>
                  t.tankId.equals(tankId) & t.parameterId.equals(parameterId),
            ))
            .getSingleOrNull();
    if (range == null) return;
    if (targetValue < range.minValue) {
      throw FormatException(
        '${po4 ? 'PO4' : 'KH'} 目标不得低于当前海缸目标下限 ${range.minValue} ${range.unit}。',
      );
    }
    if (!po4 && targetValue > range.maxValue) {
      throw FormatException(
        'KH 目标不得高于当前海缸目标上限 ${range.maxValue} ${range.unit}。',
      );
    }
  }

  Future<bool> hasChemicalPlanFromDate(
    String tankId,
    String source,
    DateTime start,
  ) async {
    return (await (_database.select(_database.maintenanceTasks)..where(
              (t) =>
                  t.tankId.equals(tankId) &
                  t.source.equals(source) &
                  t.dueAt.isBiggerOrEqualValue(localDate(start).toUtc()),
            ))
            .get())
        .isNotEmpty;
  }

  Future<void> _replacePlanFromDate(
    String tankId,
    String source,
    DateTime start,
    bool replace,
  ) async {
    final old =
        await (_database.select(_database.maintenanceTasks)..where(
              (t) =>
                  t.tankId.equals(tankId) &
                  t.source.equals(source) &
                  t.dueAt.isBiggerOrEqualValue(localDate(start).toUtc()),
            ))
            .get();
    if (old.isNotEmpty && !replace) throw StateError('当前海缸已有同类计划，请确认覆盖');
    for (final task in old) {
      await deleteTask(tankId: tankId, taskId: task.id);
    }
  }

  Future<List<String>> createAlkalinityPlanTasks({
    required String tankId,
    required AlkalinityPlan plan,
    DateTime? startDate,
    String preferredReminderTime = '09:00',
    bool replaceExisting = false,
  }) async {
    _validateReminderTime(preferredReminderTime);
    await _requireActiveTank(tankId);
    final start = localDate(startDate ?? _now());
    final time = preferredReminderTime.split(':').map(int.parse).toList();
    final ids = <String>[];
    final planId = _uuid.v4();
    await _database.transaction(() async {
      await validateChemicalTarget(
        tankId: tankId,
        parameterId: AppDatabase.khId,
        targetValue: plan.targetDkh,
      );
      await _replacePlanFromDate(
        tankId,
        'alkalinity-plan',
        start,
        replaceExisting,
      );
      for (final day in plan.dailyPlan) {
        ids.add(
          await createTask(
            tankId: tankId,
            title: '碳酸氢钠 KH 计划 · 第 ${day.day} 天',
            notes:
                '当天先复测 KH/pH 并观察生物；达到 ${plan.targetDkh} dKH、无需补充或出现异常时停止当天及后续计划。'
                '计划净升幅 ${day.netRise.toStringAsFixed(3)} dKH + 假设消耗 ${day.consumption.toStringAsFixed(3)} dKH，'
                '理论投加当量 ${day.doseDkh.toStringAsFixed(3)} dKH，取母液 ${day.stockMl.toStringAsFixed(2)} mL。'
                '母液配方：NaHCO3 纯度 ${plan.purityPercent}%，称取 ${plan.solidMassToWeighG.toStringAsFixed(4)} g，定容至 ${plan.stockFinalVolumeMl} mL。'
                '仅为理论条件提醒，每天按复测重算；完全溶解后在强水流处缓慢分次添加，勿与钙镁浓缩液混合。'
                '依据：碳酸氢钠一价碱度当量，1 meq/L = 2.8 dKH；不能替代专业诊断。',
            intervalAmount: 1,
            intervalUnit: MaintenanceIntervalUnit.day,
            dueAt: DateTime(
              start.year,
              start.month,
              start.day + day.day - 1,
              time[0],
              time[1],
            ),
            preferredReminderTime: preferredReminderTime,
            isOneOff: true,
            source: 'alkalinity-plan',
            planId: planId,
            planDayIndex: day.day,
            planTotalDays: plan.days,
          ),
        );
      }
    });
    return List.unmodifiable(ids);
  }

  Future<String> handleOccurrence({
    required String tankId,
    required String taskId,
    required DateTime date,
    required String state,
    DateTime? until,
  }) async {
    final eventId = _uuid.v4();
    await _database.transaction(() async {
      final task = await _requireEnabledTask(tankId, taskId);
      if (task.recurrenceJson == null) throw StateError('任务不是按日期重复的规则');
      final rule = Recurrence.decode(task.recurrenceJson!);
      if (!rule.occurs(task, date)) throw StateError('该日期没有此任务');
      if (!{'completed', 'skipped', 'pending', 'snoozed'}.contains(state)) {
        throw ArgumentError('无效状态');
      }
      final now = _now().toUtc();
      final key = dateKey(date);
      rule.snoozes.remove(key);
      if (state == 'snoozed') {
        if (key != dateKey(now) ||
            until == null ||
            !until.isAfter(now) ||
            rule.stateOn(date) != 'pending') {
          throw StateError('只能稍后提醒今天未完成的事项');
        }
        rule.snoozes[key] = until.toUtc().toIso8601String();
      } else {
        rule.states[key] = state;
      }
      if (state != 'pending') {
        await _database
            .into(_database.taskEvents)
            .insert(
              TaskEventsCompanion.insert(
                id: eventId,
                taskId: taskId,
                type: state,
                occurredAt: now,
                snoozedUntil: Value(state == 'snoozed' ? until!.toUtc() : null),
                note: Value('发生日期 $key'),
              ),
            );
      }
      await (_database.update(
        _database.maintenanceTasks,
      )..where((t) => t.id.equals(taskId))).write(
        MaintenanceTasksCompanion(
          recurrenceJson: Value(rule.encode()),
          updatedAt: Value(now),
        ),
      );
    });
    return eventId;
  }

  Future<void> reopen({
    required String tankId,
    required String taskId,
    DateTime? occurrenceDate,
  }) async {
    if (occurrenceDate != null) {
      await handleOccurrence(
        tankId: tankId,
        taskId: taskId,
        date: occurrenceDate,
        state: 'pending',
      );
      return;
    }
    await _database.transaction(() async {
      final task = await _requireTask(tankId, taskId);
      if (!task.isOneOff || task.status != 'completed') {
        throw StateError('只能恢复已完成的单次任务');
      }
      await (_database.update(
        _database.maintenanceTasks,
      )..where((t) => t.id.equals(taskId))).write(
        MaintenanceTasksCompanion(
          status: const Value('enabled'),
          updatedAt: Value(_now().toUtc()),
        ),
      );
    });
  }

  Future<void> stopRecurring({
    required String tankId,
    required String taskId,
    required DateTime from,
  }) async {
    await _database.transaction(() async {
      final task = await _requireEnabledTask(tankId, taskId);
      if (task.recurrenceJson == null) {
        await setEnabled(tankId: tankId, taskId: taskId, enabled: false);
        return;
      }
      final rule = Recurrence.decode(task.recurrenceJson!)
        ..stoppedAfter = dateKey(from);
      await (_database.update(
        _database.maintenanceTasks,
      )..where((t) => t.id.equals(taskId))).write(
        MaintenanceTasksCompanion(
          recurrenceJson: Value(rule.encode()),
          updatedAt: Value(_now().toUtc()),
        ),
      );
    });
  }

  Stream<List<MaintenanceTask>> watchAllTasks(String tankId) {
    final query = _database.select(_database.maintenanceTasks)
      ..where((task) => task.tankId.equals(tankId))
      ..orderBy([
        (task) => OrderingTerm.asc(task.dueAt),
        (task) => OrderingTerm.asc(task.createdAt),
      ]);
    return query.watch();
  }

  Stream<List<MaintenanceTask>> watchEnabledTasks({String? tankId}) {
    final query = _database.select(_database.maintenanceTasks)
      ..where(
        (task) =>
            task.status.equals(MaintenanceTaskStatus.enabled.name) &
            (tankId == null
                ? const Constant(true)
                : task.tankId.equals(tankId)),
      )
      ..orderBy([(task) => OrderingTerm.asc(task.dueAt)]);
    return query.watch();
  }

  Stream<List<MaintenanceTaskItem>> watchAllTaskItems({
    DateTime? referenceTime,
  }) {
    final query =
        _database.select(_database.maintenanceTasks).join([
          leftOuterJoin(
            _database.taskEvents,
            _database.taskEvents.taskId.equalsExp(
              _database.maintenanceTasks.id,
            ),
          ),
        ])..orderBy([
          OrderingTerm.asc(_database.maintenanceTasks.dueAt),
          OrderingTerm.desc(_database.taskEvents.occurredAt),
        ]);
    return query.watch().map((rows) {
      final tasks = <String, MaintenanceTask>{};
      final latestEvents = <String, TaskEvent?>{};
      for (final row in rows) {
        final task = row.readTable(_database.maintenanceTasks);
        tasks.putIfAbsent(task.id, () => task);
        latestEvents.putIfAbsent(
          task.id,
          () => row.readTableOrNull(_database.taskEvents),
        );
      }
      final now = (referenceTime ?? _now()).toUtc();
      return [
        for (final task in tasks.values)
          notificationOccurrence(
            MaintenanceTaskItem(
              task: task,
              latestEvent: latestEvents[task.id],
              state: _viewState(task, latestEvents[task.id], now),
            ),
            now,
          ),
      ];
    });
  }

  Stream<List<MaintenanceTaskItem>> watchPendingTasks(
    String tankId, {
    DateTime? referenceTime,
  }) {
    return watchTaskItems(
      tankId,
      MaintenanceTaskFilter.pending,
      referenceTime: referenceTime,
    );
  }

  Stream<List<MaintenanceTaskItem>> watchTaskItems(
    String tankId,
    MaintenanceTaskFilter filter, {
    DateTime? referenceTime,
  }) {
    final query =
        _database.select(_database.maintenanceTasks).join([
            leftOuterJoin(
              _database.taskEvents,
              _database.taskEvents.taskId.equalsExp(
                _database.maintenanceTasks.id,
              ),
            ),
          ])
          ..where(_database.maintenanceTasks.tankId.equals(tankId))
          ..orderBy([
            OrderingTerm.asc(_database.maintenanceTasks.dueAt),
            OrderingTerm.desc(_database.taskEvents.occurredAt),
          ]);

    return query.watch().map((rows) {
      final tasks = <String, MaintenanceTask>{};
      final latestEvents = <String, TaskEvent?>{};
      for (final row in rows) {
        final task = row.readTable(_database.maintenanceTasks);
        tasks.putIfAbsent(task.id, () => task);
        if (!latestEvents.containsKey(task.id)) {
          latestEvents[task.id] = row.readTableOrNull(_database.taskEvents);
        }
      }

      final now = (referenceTime ?? _now()).toUtc();
      final items = [
        for (final task in tasks.values)
          MaintenanceTaskItem(
            task: task,
            latestEvent: latestEvents[task.id],
            state: _viewState(task, latestEvents[task.id], now),
          ),
      ];
      return switch (filter) {
        MaintenanceTaskFilter.pending =>
          items
              .where(
                (item) => {
                  MaintenanceTaskViewState.upcoming,
                  MaintenanceTaskViewState.overdue,
                  MaintenanceTaskViewState.snoozed,
                }.contains(item.state),
              )
              .toList(),
        MaintenanceTaskFilter.completed =>
          items
              .where((item) => item.state == MaintenanceTaskViewState.completed)
              .toList(),
        MaintenanceTaskFilter.all => items,
      };
    });
  }

  Stream<List<MaintenanceTaskHistoryEntry>> watchCompletedEvents(
    String tankId,
  ) {
    return _watchHistory(tankId, {TaskEventType.completed});
  }

  Stream<List<MaintenanceTaskHistoryEntry>> watchHandledEvents(String tankId) {
    return _watchHistory(tankId, {
      TaskEventType.completed,
      TaskEventType.skipped,
    });
  }

  Future<String> createTask({
    required String tankId,
    required String title,
    String? notes,
    required int intervalAmount,
    required MaintenanceIntervalUnit intervalUnit,
    required DateTime dueAt,
    String preferredReminderTime = '09:00',
    int? notificationId,
    bool isOneOff = false,
    String? source,
    String? planId,
    int? planDayIndex,
    int? planTotalDays,
    bool calendarRecurrence = false,
  }) async {
    final normalizedTitle = _requireTitle(title);
    _validateInterval(intervalAmount);
    _validateReminderTime(preferredReminderTime);
    await _requireActiveTank(tankId);

    final id = _uuid.v4();
    final now = _now().toUtc();
    await _database
        .into(_database.maintenanceTasks)
        .insert(
          MaintenanceTasksCompanion.insert(
            id: id,
            tankId: tankId,
            title: normalizedTitle,
            notes: Value(_trimToNull(notes)),
            intervalAmount: intervalAmount,
            intervalUnit: intervalUnit.name,
            dueAt: dueAt.toUtc(),
            preferredReminderTime: Value(preferredReminderTime),
            isOneOff: Value(isOneOff),
            recurrenceJson: Value(
              calendarRecurrence && !isOneOff
                  ? Recurrence(
                      start: dateKey(dueAt),
                      completedBefore: dateKey(now),
                    ).encode()
                  : null,
            ),
            source: Value(_trimToNull(source)),
            planId: Value(_trimToNull(planId)),
            planDayIndex: Value(planDayIndex),
            planTotalDays: Value(planTotalDays),
            notificationId: Value(notificationId),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<List<String>> createLanthanumPlanTasks({
    required String tankId,
    required LanthanumPlan plan,
    DateTime? startDate,
    String preferredReminderTime = '09:00',
    bool replaceExisting = false,
  }) async {
    _validateReminderTime(preferredReminderTime);
    await _requireActiveTank(tankId);
    final localStart = (startDate ?? _now().toLocal()).toLocal();
    final reminderParts = preferredReminderTime.split(':');
    final reminderHour = int.parse(reminderParts[0]);
    final reminderMinute = int.parse(reminderParts[1]);
    final planId = _uuid.v4();
    final now = _now().toUtc();
    final ids = <String>[];
    await _database.transaction(() async {
      await validateChemicalTarget(
        tankId: tankId,
        parameterId: AppDatabase.po4Id,
        targetValue: plan.targetPo4MgL,
      );
      await _replacePlanFromDate(
        tankId,
        'lanthanum-plan',
        localStart,
        replaceExisting,
      );
      for (final day in plan.dailyPlan) {
        final id = _uuid.v4();
        ids.add(id);
        final dueLocal = DateTime(
          localStart.year,
          localStart.month,
          localStart.day + day.day - 1,
          reminderHour,
          reminderMinute,
        );
        final stopCondition =
            (plan.targetPo4MgL - minimumTargetPo4MgL).abs() < 0.000000001
            ? '达到 ${plan.targetPo4MgL} mg/L 或出现异常'
            : '达到 ${plan.targetPo4MgL} mg/L、达到 0.03 mg/L 或出现异常';
        final notes =
            '当天先复测 PO4、KH 并观察鱼和珊瑚；$stopCondition时停止当天及后续计划。理论上取固定母液 '
            '${day.stockToUseMl.toStringAsFixed(2)} mL，用 RO/DI 水定容至最终 500 mL。'
            '仅在复测仍需处理时执行，并使用机械过滤或蛋分捕获沉淀；不得直接加入展示缸。';
        await _database
            .into(_database.maintenanceTasks)
            .insert(
              MaintenanceTasksCompanion.insert(
                id: id,
                tankId: tankId,
                title: '氯化镧计划 · 第 ${day.day} 天',
                notes: Value(notes),
                intervalAmount: 1,
                intervalUnit: MaintenanceIntervalUnit.day.name,
                dueAt: dueLocal.toUtc(),
                preferredReminderTime: Value(preferredReminderTime),
                isOneOff: const Value(true),
                source: const Value('lanthanum-plan'),
                planId: Value(planId),
                planDayIndex: Value(day.day),
                planTotalDays: Value(plan.days),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
    });
    return List.unmodifiable(ids);
  }

  Future<void> updateTask({
    required String tankId,
    required String taskId,
    required String title,
    String? notes,
    required int intervalAmount,
    required MaintenanceIntervalUnit intervalUnit,
    required DateTime dueAt,
    required String preferredReminderTime,
    bool calendarRecurrence = false,
  }) async {
    final normalizedTitle = _requireTitle(title);
    _validateInterval(intervalAmount);
    _validateReminderTime(preferredReminderTime);
    final existing = await _requireTask(tankId, taskId, allowArchived: false);
    final previous = existing.recurrenceJson == null
        ? null
        : Recurrence.decode(existing.recurrenceJson!);

    final changed =
        await (_database.update(_database.maintenanceTasks)..where(
              (task) => task.id.equals(taskId) & task.tankId.equals(tankId),
            ))
            .write(
              MaintenanceTasksCompanion(
                title: Value(normalizedTitle),
                notes: Value(_trimToNull(notes)),
                intervalAmount: Value(intervalAmount),
                intervalUnit: Value(intervalUnit.name),
                dueAt: Value(dueAt.toUtc()),
                recurrenceJson: calendarRecurrence && !existing.isOneOff
                    ? Value(
                        Recurrence(
                          start: dateKey(dueAt),
                          completedBefore: dateKey(_now()),
                          states: previous?.states,
                          snoozes: previous?.snoozes,
                        ).encode(),
                      )
                    : const Value.absent(),
                preferredReminderTime: Value(preferredReminderTime),
                updatedAt: Value(_now().toUtc()),
              ),
            );
    if (changed != 1) throw StateError('维护任务不存在');
  }

  Future<void> setEnabled({
    required String tankId,
    required String taskId,
    required bool enabled,
  }) async {
    await _requireTask(tankId, taskId, allowArchived: false);
    final changed =
        await (_database.update(_database.maintenanceTasks)..where(
              (task) => task.id.equals(taskId) & task.tankId.equals(tankId),
            ))
            .write(
              MaintenanceTasksCompanion(
                status: Value(
                  enabled
                      ? MaintenanceTaskStatus.enabled.name
                      : MaintenanceTaskStatus.disabled.name,
                ),
                updatedAt: Value(_now().toUtc()),
              ),
            );
    if (changed != 1) throw StateError('维护任务不存在');
  }

  Future<void> archiveTask({
    required String tankId,
    required String taskId,
  }) async {
    await _requireTask(tankId, taskId);
    final changed =
        await (_database.update(_database.maintenanceTasks)..where(
              (task) => task.id.equals(taskId) & task.tankId.equals(tankId),
            ))
            .write(
              MaintenanceTasksCompanion(
                status: Value(MaintenanceTaskStatus.archived.name),
                updatedAt: Value(_now().toUtc()),
              ),
            );
    if (changed != 1) throw StateError('维护任务不存在');
  }

  Future<void> deleteTask({
    required String tankId,
    required String taskId,
  }) async {
    await _database.transaction(() async {
      // TaskEvent does not carry a tankId. Validate the task's ownership inside
      // this transaction before deleting its child rows, then keep tankId on
      // the parent delete as a second cross-tank guard.
      await _requireTask(tankId, taskId);
      await (_database.delete(
        _database.taskEvents,
      )..where((event) => event.taskId.equals(taskId))).go();
      final deleted =
          await (_database.delete(_database.maintenanceTasks)..where(
                (task) => task.id.equals(taskId) & task.tankId.equals(tankId),
              ))
              .go();
      if (deleted != 1) throw StateError('维护任务不存在');
    });
  }

  Future<void> setNotificationId({
    required String tankId,
    required String taskId,
    int? notificationId,
  }) async {
    await _requireTask(tankId, taskId, allowArchived: false);
    final changed =
        await (_database.update(_database.maintenanceTasks)..where(
              (task) => task.id.equals(taskId) & task.tankId.equals(tankId),
            ))
            .write(
              MaintenanceTasksCompanion(
                notificationId: Value(notificationId),
                updatedAt: Value(_now().toUtc()),
              ),
            );
    if (changed != 1) throw StateError('维护任务不存在');
  }

  Future<String> complete({
    required String tankId,
    required String taskId,
    String? note,
    DateTime? occurrenceDate,
  }) {
    if (occurrenceDate != null) {
      return handleOccurrence(
        tankId: tankId,
        taskId: taskId,
        date: occurrenceDate,
        state: 'completed',
      );
    }
    return _handleTask(
      tankId: tankId,
      taskId: taskId,
      type: TaskEventType.completed,
      note: note,
    );
  }

  Future<String> skip({
    required String tankId,
    required String taskId,
    String? note,
    DateTime? occurrenceDate,
  }) {
    if (occurrenceDate != null) {
      return handleOccurrence(
        tankId: tankId,
        taskId: taskId,
        date: occurrenceDate,
        state: 'skipped',
      );
    }
    return _handleTask(
      tankId: tankId,
      taskId: taskId,
      type: TaskEventType.skipped,
      note: note,
    );
  }

  Future<String> snooze({
    required String tankId,
    required String taskId,
    required DateTime until,
    String? note,
    DateTime? occurrenceDate,
  }) async {
    if (occurrenceDate != null) {
      return handleOccurrence(
        tankId: tankId,
        taskId: taskId,
        date: occurrenceDate,
        state: 'snoozed',
        until: until,
      );
    }
    final occurredAt = _now().toUtc();
    final snoozedUntil = until.toUtc();
    if (!snoozedUntil.isAfter(occurredAt)) {
      throw ArgumentError('稍后提醒时间必须晚于当前时间');
    }

    final eventId = _uuid.v4();
    await _database.transaction(() async {
      final task = await _requireEnabledTask(tankId, taskId);
      if (task.recurrenceJson != null) {
        await handleOccurrence(
          tankId: tankId,
          taskId: taskId,
          date: _now().toLocal(),
          state: 'snoozed',
          until: until,
        );
        return;
      }
      await _database
          .into(_database.taskEvents)
          .insert(
            TaskEventsCompanion.insert(
              id: eventId,
              taskId: taskId,
              type: TaskEventType.snoozed.name,
              occurredAt: occurredAt,
              snoozedUntil: Value(snoozedUntil),
              note: Value(_trimToNull(note)),
            ),
          );
    });
    return eventId;
  }

  Future<String> _handleTask({
    required String tankId,
    required String taskId,
    required TaskEventType type,
    String? note,
  }) async {
    assert(type != TaskEventType.snoozed);
    final occurredAt = _now().toUtc();
    final eventId = _uuid.v4();
    await _database.transaction(() async {
      final task = await _requireEnabledTask(tankId, taskId);
      if (task.recurrenceJson != null) {
        await handleOccurrence(
          tankId: tankId,
          taskId: taskId,
          date: _now().toLocal(),
          state: type.name,
        );
        return;
      }
      if (task.isOneOff) {
        if (type == TaskEventType.skipped &&
            isChemicalPlan(task) &&
            task.planId != null &&
            task.planDayIndex != null) {
          final remaining =
              await (_database.select(_database.maintenanceTasks)..where(
                    (row) =>
                        row.tankId.equals(tankId) &
                        row.planId.equals(task.planId!) &
                        row.planDayIndex.isBiggerOrEqualValue(
                          task.planDayIndex!,
                        ) &
                        row.status.equals(MaintenanceTaskStatus.enabled.name),
                  ))
                  .get();
          for (final plannedTask in remaining) {
            await _recordOneOffResult(
              plannedTask,
              type: TaskEventType.skipped,
              occurredAt: occurredAt,
              note: plannedTask.id == taskId ? note : '前序计划已停止',
              eventId: plannedTask.id == taskId ? eventId : _uuid.v4(),
            );
          }
        } else {
          await _recordOneOffResult(
            task,
            type: type,
            occurredAt: occurredAt,
            note: note,
            eventId: eventId,
          );
        }
        return;
      }
      final intervalUnit = _parseIntervalUnit(task.intervalUnit);
      final nextDueAt = calculateNextDueAt(
        occurredAt,
        task.intervalAmount,
        intervalUnit,
      );
      await _database
          .into(_database.taskEvents)
          .insert(
            TaskEventsCompanion.insert(
              id: eventId,
              taskId: taskId,
              type: type.name,
              occurredAt: occurredAt,
              note: Value(_trimToNull(note)),
            ),
          );
      final changed =
          await (_database.update(_database.maintenanceTasks)..where(
                (row) => row.id.equals(taskId) & row.tankId.equals(tankId),
              ))
              .write(
                MaintenanceTasksCompanion(
                  dueAt: Value(nextDueAt),
                  updatedAt: Value(occurredAt),
                ),
              );
      if (changed != 1) throw StateError('维护任务不存在');
    });
    return eventId;
  }

  Future<void> _recordOneOffResult(
    MaintenanceTask task, {
    required TaskEventType type,
    required DateTime occurredAt,
    required String eventId,
    String? note,
  }) async {
    await _database
        .into(_database.taskEvents)
        .insert(
          TaskEventsCompanion.insert(
            id: eventId,
            taskId: task.id,
            type: type.name,
            occurredAt: occurredAt,
            note: Value(_trimToNull(note)),
          ),
        );
    final status = type == TaskEventType.completed
        ? MaintenanceTaskStatus.completed
        : MaintenanceTaskStatus.skipped;
    final changed =
        await (_database.update(
          _database.maintenanceTasks,
        )..where((row) => row.id.equals(task.id))).write(
          MaintenanceTasksCompanion(
            status: Value(status.name),
            updatedAt: Value(occurredAt),
          ),
        );
    if (changed != 1) throw StateError('维护任务不存在');
  }

  Stream<List<MaintenanceTaskHistoryEntry>> _watchHistory(
    String tankId,
    Set<TaskEventType> types,
  ) {
    final query =
        _database.select(_database.taskEvents).join([
            innerJoin(
              _database.maintenanceTasks,
              _database.maintenanceTasks.id.equalsExp(
                _database.taskEvents.taskId,
              ),
            ),
          ])
          ..where(
            _database.maintenanceTasks.tankId.equals(tankId) &
                _database.taskEvents.type.isIn(
                  types.map((type) => type.name).toList(),
                ),
          )
          ..orderBy([OrderingTerm.desc(_database.taskEvents.occurredAt)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          MaintenanceTaskHistoryEntry(
            task: row.readTable(_database.maintenanceTasks),
            event: row.readTable(_database.taskEvents),
          ),
      ],
    );
  }

  Future<Tank> _requireActiveTank(String tankId) async {
    final tank = await (_database.select(
      _database.tanks,
    )..where((row) => row.id.equals(tankId))).getSingleOrNull();
    if (tank == null || tank.isArchived) {
      throw StateError('海缸不存在或已归档');
    }
    return tank;
  }

  Future<MaintenanceTask> _requireTask(
    String tankId,
    String taskId, {
    bool allowArchived = true,
  }) async {
    final task =
        await (_database.select(_database.maintenanceTasks)..where(
              (row) => row.id.equals(taskId) & row.tankId.equals(tankId),
            ))
            .getSingleOrNull();
    if (task == null ||
        (!allowArchived &&
            task.status == MaintenanceTaskStatus.archived.name)) {
      throw StateError('维护任务不存在或不可操作');
    }
    return task;
  }

  Future<MaintenanceTask> _requireEnabledTask(
    String tankId,
    String taskId,
  ) async {
    final task = await _requireTask(tankId, taskId, allowArchived: false);
    if (task.status != MaintenanceTaskStatus.enabled.name) {
      throw StateError('维护任务已停用');
    }
    return task;
  }
}

DateTime calculateNextDueAt(
  DateTime occurredAt,
  int intervalAmount,
  MaintenanceIntervalUnit intervalUnit,
) {
  if (intervalAmount <= 0) throw ArgumentError('重复间隔必须大于 0');
  final utc = occurredAt.toUtc();
  return switch (intervalUnit) {
    MaintenanceIntervalUnit.day => utc.add(Duration(days: intervalAmount)),
    MaintenanceIntervalUnit.week => utc.add(Duration(days: intervalAmount * 7)),
    MaintenanceIntervalUnit.month => _addUtcMonthsClamped(utc, intervalAmount),
  };
}

MaintenanceTaskViewState _viewState(
  MaintenanceTask task,
  TaskEvent? latestEvent,
  DateTime now,
) {
  if (task.status == MaintenanceTaskStatus.archived.name) {
    return MaintenanceTaskViewState.archived;
  }
  if (task.status == MaintenanceTaskStatus.completed.name) {
    return MaintenanceTaskViewState.completed;
  }
  if (task.status == MaintenanceTaskStatus.skipped.name) {
    return MaintenanceTaskViewState.skipped;
  }
  if (task.status == MaintenanceTaskStatus.disabled.name) {
    return MaintenanceTaskViewState.disabled;
  }
  if (task.status != MaintenanceTaskStatus.enabled.name) {
    throw StateError('未知维护任务状态：${task.status}');
  }

  if (!task.isOneOff &&
      latestEvent != null &&
      latestEvent.occurredAt.isAtSameMomentAs(task.updatedAt) &&
      now.isBefore(task.dueAt)) {
    if (latestEvent.type == TaskEventType.completed.name) {
      return MaintenanceTaskViewState.completed;
    }
    if (latestEvent.type == TaskEventType.skipped.name) {
      return MaintenanceTaskViewState.skipped;
    }
  }
  if (activeMaintenanceSnoozeUntilUtc(latestEvent, now.toUtc()) != null) {
    return MaintenanceTaskViewState.snoozed;
  }
  return task.dueAt.isAfter(now)
      ? MaintenanceTaskViewState.upcoming
      : MaintenanceTaskViewState.overdue;
}

/// Returns the latest snooze only while it is still active.
///
/// Maintenance presentation and OS notification planning share this helper so
/// an expired snooze cannot leave the two surfaces in different states.
DateTime? activeMaintenanceSnoozeUntilUtc(
  TaskEvent? latestEvent,
  DateTime nowUtc,
) {
  if (!nowUtc.isUtc) {
    throw ArgumentError.value(nowUtc, 'nowUtc', 'must be UTC');
  }
  if (latestEvent?.type != TaskEventType.snoozed.name) {
    return null;
  }
  final snoozedUntilUtc = latestEvent?.snoozedUntil?.toUtc();
  return snoozedUntilUtc != null && snoozedUntilUtc.isAfter(nowUtc)
      ? snoozedUntilUtc
      : null;
}

/// Due instant used by notification planning.
///
/// A future snooze temporarily replaces [MaintenanceTask.dueAt]. Once the
/// snooze expires, the original task due instant becomes authoritative again.
DateTime effectiveMaintenanceDueAtUtc(
  MaintenanceTask task,
  TaskEvent? latestEvent,
  DateTime nowUtc,
) {
  return activeMaintenanceSnoozeUntilUtc(latestEvent, nowUtc) ??
      task.dueAt.toUtc();
}

DateTime _addUtcMonthsClamped(DateTime value, int months) {
  final zeroBasedMonth = value.month - 1 + months;
  final year = value.year + zeroBasedMonth ~/ 12;
  final month = zeroBasedMonth % 12 + 1;
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(
    year,
    month,
    math.min(value.day, lastDay),
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
}

MaintenanceIntervalUnit _parseIntervalUnit(String value) {
  return MaintenanceIntervalUnit.values.firstWhere(
    (unit) => unit.name == value,
    orElse: () => throw StateError('未知重复间隔单位：$value'),
  );
}

String _requireTitle(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty || trimmed.length > 120) {
    throw ArgumentError('任务名称必须为 1 至 120 个字符');
  }
  return trimmed;
}

void _validateInterval(int value) {
  if (value <= 0) throw ArgumentError('重复间隔必须大于 0');
}

void _validateReminderTime(String value) {
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
  final hour = int.tryParse(match?.group(1) ?? '');
  final minute = int.tryParse(match?.group(2) ?? '');
  if (hour == null || minute == null || hour > 23 || minute > 59) {
    throw ArgumentError('提醒时间必须使用 HH:mm 格式');
  }
}

String? _trimToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

DateTime _systemUtcNow() => DateTime.now().toUtc();

bool isChemicalPlan(MaintenanceTask task) =>
    {'lanthanum-plan', 'alkalinity-plan'}.contains(task.source) &&
    task.planId != null;

MaintenanceTaskItem notificationOccurrence(
  MaintenanceTaskItem item,
  DateTime now,
) {
  final task = item.task;
  if (task.recurrenceJson == null || task.status != 'enabled') return item;
  final rule = Recurrence.decode(task.recurrenceJson!);
  var date = rule.nextDate(task, localDate(now));
  for (var i = 0; i <= rule.states.length + 1; i++) {
    if (rule.stoppedAfter != null &&
        dateKey(date).compareTo(rule.stoppedAfter!) >= 0) {
      return MaintenanceTaskItem(
        task: task.copyWith(status: 'disabled'),
        state: MaintenanceTaskViewState.disabled,
      );
    }
    if (rule.stateOn(date) == 'pending') {
      return calendarOccurrences([item], date, 1, now: now).single;
    }
    date = rule.nextDate(task, DateTime(date.year, date.month, date.day + 1));
  }
  return MaintenanceTaskItem(
    task: task.copyWith(status: 'disabled'),
    state: MaintenanceTaskViewState.disabled,
  );
}

/// Expand only a bounded visible range. No future task rows are persisted.
List<MaintenanceTaskItem> calendarOccurrences(
  List<MaintenanceTaskItem> items,
  DateTime start,
  int days, {
  DateTime? now,
}) {
  if (days < 0 || days > 366) throw ArgumentError('日历窗口须为 0–366 天');
  final result = <MaintenanceTaskItem>[];
  final clock = (now ?? DateTime.now()).toUtc();
  for (final item in items) {
    final task = item.task;
    if (task.status == 'skipped' ||
        task.status == 'archived' ||
        task.status == 'disabled') {
      continue;
    }
    if (task.recurrenceJson == null) {
      final offset = DateTime.utc(
        task.dueAt.toLocal().year,
        task.dueAt.toLocal().month,
        task.dueAt.toLocal().day,
      ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
      if (offset >= 0 && offset < days) {
        result.add(
          MaintenanceTaskItem(
            task: task,
            latestEvent: item.latestEvent,
            state: _viewState(task, item.latestEvent, clock),
          ),
        );
      }
      continue;
    }
    final rule = Recurrence.decode(task.recurrenceJson!);
    for (var i = 0; i < days; i++) {
      final date = DateTime(start.year, start.month, start.day + i);
      if (!rule.occurs(task, date)) continue;
      final state = rule.stateOn(date);
      if (state == 'skipped') continue;
      final due = rule.dueOn(task, date);
      final until = DateTime.tryParse(rule.snoozes[dateKey(date)] ?? '');
      final snoozed =
          state == 'pending' &&
          until != null &&
          until.isAfter(clock) &&
          dateKey(date) == dateKey(clock);
      result.add(
        MaintenanceTaskItem(
          task: task.copyWith(dueAt: due),
          occurrenceDate: date,
          state: state == 'completed'
              ? MaintenanceTaskViewState.completed
              : snoozed
              ? MaintenanceTaskViewState.snoozed
              : due.isAfter(clock)
              ? MaintenanceTaskViewState.upcoming
              : MaintenanceTaskViewState.overdue,
          latestEvent: snoozed
              ? TaskEvent(
                  id: 'calendar-${task.id}',
                  taskId: task.id,
                  type: 'snoozed',
                  occurredAt: clock,
                  snoozedUntil: until,
                )
              : null,
        ),
      );
    }
  }
  result.sort((a, b) => a.task.dueAt.compareTo(b.task.dueAt));
  return result;
}

List<List<MaintenanceTaskItem>> groupMaintenancePlans(
  List<MaintenanceTaskItem> items,
) {
  final groups = <String, List<MaintenanceTaskItem>>{};
  for (final item in items) {
    final task = item.task;
    final key = isChemicalPlan(task)
        ? '${task.tankId}/${task.source}/${task.planId}'
        : task.id;
    groups.putIfAbsent(key, () => []).add(item);
  }
  return groups.values.toList();
}
