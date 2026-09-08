import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database/app_database.dart';
import '../../calculators/domain/lanthanum_calculator.dart';
import '../../calculators/domain/alkalinity_calculator.dart';
import '../../calculators/domain/maintenance_cycle.dart';
import '../domain/recurrence.dart';
import '../domain/rolling_schedule.dart';

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
    this.canEditCompletion = false,
    this.canReopen = false,
    this.cycleOccurrence,
  });

  final MaintenanceTask task;
  final TaskEvent? latestEvent;
  final MaintenanceTaskViewState state;
  final DateTime? occurrenceDate;
  final bool canEditCompletion, canReopen;
  final MaintenanceCycleOccurrence? cycleOccurrence;
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
  canEditCompletion: item.canEditCompletion,
  canReopen: item.canReopen,
  cycleOccurrence: item.cycleOccurrence,
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

  Future<List<MaintenanceTask>> _rollingTasks(String tankId) async {
    final tasks = await (_database.select(
      _database.maintenanceTasks,
    )..where((t) => t.tankId.equals(tankId))).get();
    final query = _database.select(_database.taskEvents).join([
      innerJoin(
        _database.maintenanceTasks,
        _database.maintenanceTasks.id.equalsExp(_database.taskEvents.taskId),
      ),
    ])..where(_database.maintenanceTasks.tankId.equals(tankId));
    final events = <String, List<TaskEvent>>{};
    for (final row in await query.get()) {
      final event = row.readTable(_database.taskEvents);
      events.putIfAbsent(event.taskId, () => []).add(event);
    }
    return [
      for (final task in tasks)
        initializeRollingTask(task, events: events[task.id] ?? []),
    ];
  }

  Future<String> _changeRolling({
    required String tankId,
    required String taskId,
    required List<MaintenanceTask> Function(List<MaintenanceTask>, DateTime)
    change,
    String? eventType,
    String? note,
  }) async {
    final eventId = _uuid.v4();
    await _database.transaction(() async {
      await _requireActiveTank(tankId);
      await _requireTask(tankId, taskId, allowArchived: false);
      final now = _now().toUtc(), before = await _rollingTasks(tankId);
      final after = change(before, now);
      final originals = {for (final task in before) task.id: task};
      for (final task in after) {
        if (identical(task, originals[task.id])) continue;
        await (_database.update(
          _database.maintenanceTasks,
        )..where((t) => t.id.equals(task.id) & t.tankId.equals(tankId))).write(
          MaintenanceTasksCompanion(
            rollingJson: Value(task.rollingJson),
            status: Value(task.status),
            updatedAt: Value(now),
          ),
        );
      }
      if (eventType != null) {
        final eventTasks = eventType == 'skipped'
            ? after.where(
                (task) =>
                    !identical(task, originals[task.id]) &&
                    task.status == 'skipped',
              )
            : after.where((task) => task.id == taskId);
        for (final eventTask in eventTasks) {
          await _database
              .into(_database.taskEvents)
              .insert(
                TaskEventsCompanion.insert(
                  id: eventTask.id == taskId ? eventId : _uuid.v4(),
                  taskId: eventTask.id,
                  type: eventType,
                  occurredAt: now,
                  note: Value(note),
                ),
              );
        }
      }
    });
    return eventId;
  }

  Future<void> delayTask({
    required String tankId,
    required String taskId,
    required int days,
    int? expectedRevision,
  }) async {
    await _changeRolling(
      tankId: tankId,
      taskId: taskId,
      change: (tasks, now) => delayRollingTasks(
        tasks,
        taskId,
        days,
        now,
        expectedRevision: expectedRevision,
      ),
    );
  }

  Future<void> correctCompletion({
    required String tankId,
    required String taskId,
    required DateTime completedDate,
    required DateTime newDate,
    int? expectedRevision,
  }) async {
    await _changeRolling(
      tankId: tankId,
      taskId: taskId,
      change: (tasks, now) => correctRollingTasks(
        tasks,
        taskId,
        dateKey(completedDate),
        dateKey(newDate),
        now,
        expectedRevision: expectedRevision,
      ),
    );
  }

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
    if (range.minValue != null && targetValue < range.minValue!) {
      throw FormatException(
        '${po4 ? 'PO4' : 'KH'} 目标不得低于当前海缸目标下限 ${range.minValue} ${range.unit}。',
      );
    }
    if (!po4 && range.maxValue != null && targetValue > range.maxValue!) {
      throw FormatException(
        'KH 目标不得高于当前海缸目标上限 ${range.maxValue} ${range.unit}。',
      );
    }
  }

  Future<bool> hasChemicalPlanFromDate(
    String tankId,
    String source,
    DateTime start,
  ) async => (await _replaceablePlanTasks(tankId, source, start)).isNotEmpty;

  Future<List<MaintenanceTask>> _replaceablePlanTasks(
    String tankId,
    String source,
    DateTime start,
  ) async {
    final tasks = await _rollingTasks(tankId);
    final dates = projectRollingDates(tasks, _now());
    return tasks
        .where(
          (t) =>
              t.source == source &&
              t.status == 'enabled' &&
              dates[t.id]!.compareTo(dateKey(start)) >= 0,
        )
        .toList();
  }

  Future<void> _replacePlanFromDate(
    String tankId,
    String source,
    DateTime start,
    bool replace,
  ) async {
    final old = await _replaceablePlanTasks(tankId, source, start);
    if (old.isNotEmpty && !replace) throw StateError('当前海缸已有同类计划，请确认覆盖');
    for (final task in old) {
      await (_database.update(
        _database.maintenanceTasks,
      )..where((t) => t.id.equals(task.id) & t.tankId.equals(tankId))).write(
        MaintenanceTasksCompanion(
          status: const Value('archived'),
          rollingJson: Value(task.rollingJson),
          updatedAt: Value(_now().toUtc()),
        ),
      );
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
    if (state == 'completed') {
      return complete(tankId: tankId, taskId: taskId, completedDate: date);
    }
    if (state == 'pending') {
      await reopen(tankId: tankId, taskId: taskId, occurrenceDate: date);
      return taskId;
    }
    if (state == 'skipped') {
      return skip(tankId: tankId, taskId: taskId, occurrenceDate: date);
    }
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
    int? expectedRevision,
  }) async {
    await _changeRolling(
      tankId: tankId,
      taskId: taskId,
      change: (tasks, now) {
        final task = tasks.firstWhere((t) => t.id == taskId),
            schedule = rollingSchedule(tasks.firstWhere((t) => t.id == taskId));
        final date = occurrenceDate == null
            ? schedule.completed.lastOrNull?.completedDate ??
                  schedule.legacyCompletedDates.lastOrNull ??
                  schedule.startDate
            : dateKey(occurrenceDate);
        return reopenRollingTasks(
          tasks,
          task.id,
          date,
          now,
          expectedRevision: expectedRevision,
        );
      },
    );
  }

  Future<void> stopRecurring({
    required String tankId,
    required String taskId,
    required DateTime from,
  }) async {
    await _changeRolling(
      tankId: tankId,
      taskId: taskId,
      change: (tasks, now) => stopRollingTasks(tasks, taskId, now),
      eventType: 'skipped',
    );
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

  Stream<Set<String>> watchActiveTankIds() =>
      (_database.select(_database.tanks)
            ..where((t) => t.isArchived.equals(false)))
          .watch()
          .map((tanks) => tanks.map((tank) => tank.id).toSet());

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
      final history = <String, List<TaskEvent>>{};
      for (final row in rows) {
        final task = row.readTable(_database.maintenanceTasks);
        tasks.putIfAbsent(task.id, () => task);
        final event = row.readTableOrNull(_database.taskEvents);
        if (event != null) history.putIfAbsent(task.id, () => []).add(event);
        latestEvents.putIfAbsent(
          task.id,
          () => row.readTableOrNull(_database.taskEvents),
        );
      }
      final now = (referenceTime ?? _now()).toUtc();
      return prepareMaintenanceTaskItems([
        for (final task in tasks.values)
          MaintenanceTaskItem(
            task: initializeRollingTask(task, events: history[task.id] ?? []),
            latestEvent: latestEvents[task.id],
            state: _viewState(task, latestEvents[task.id], now),
          ),
      ], now);
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
      final history = <String, List<TaskEvent>>{};
      for (final row in rows) {
        final task = row.readTable(_database.maintenanceTasks);
        tasks.putIfAbsent(task.id, () => task);
        final event = row.readTableOrNull(_database.taskEvents);
        if (event != null) history.putIfAbsent(task.id, () => []).add(event);
        if (!latestEvents.containsKey(task.id)) {
          latestEvents[task.id] = row.readTableOrNull(_database.taskEvents);
        }
      }

      final now = (referenceTime ?? _now()).toUtc();
      final items = prepareMaintenanceTaskItems([
        for (final task in tasks.values)
          MaintenanceTaskItem(
            task: initializeRollingTask(task, events: history[task.id] ?? []),
            latestEvent: latestEvents[task.id],
            state: _viewState(task, latestEvents[task.id], now),
          ),
      ], now);
      return switch (filter) {
        MaintenanceTaskFilter.pending =>
          calendarOccurrences(items, localDate(now), 1, now: now)
              .where(
                (item) => {
                  MaintenanceTaskViewState.upcoming,
                  MaintenanceTaskViewState.overdue,
                  MaintenanceTaskViewState.snoozed,
                }.contains(item.state),
              )
              .toList(),
        MaintenanceTaskFilter.completed =>
          calendarOccurrences(items, localDate(now), 1, now: now)
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
            rollingJson: Value(
              RollingSchedule(
                startDate: dateKey(dueAt),
                nextDate: dateKey(dueAt),
              ).encode(),
            ),
            recurrenceJson: Value(
              calendarRecurrence && !isOneOff
                  ? Recurrence(
                      start: dateKey(dueAt),
                      completedBefore: dateKey(dueAt),
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
                rollingJson: Value(
                  RollingSchedule(
                    startDate: dateKey(dueLocal),
                    nextDate: dateKey(dueLocal),
                  ).encode(),
                ),
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
    await _requireTask(tankId, taskId, allowArchived: false);
    final stored = (await _rollingTasks(
      tankId,
    )).firstWhere((t) => t.id == taskId);
    final rolling = rollingSchedule(stored);

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
                // The original date and old rule remain historical evidence.
                rollingJson: Value(
                  rolling
                      .copyWith(
                        nextDate: dateKey(dueAt),
                        revision: rolling.revision + 1,
                      )
                      .encode(),
                ),
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
    DateTime? completedDate,
    int? expectedRevision,
  }) {
    return _changeRolling(
      tankId: tankId,
      taskId: taskId,
      change: (tasks, now) => completeRollingTasks(
        tasks,
        taskId,
        dateKey(completedDate ?? now),
        now,
        expectedRevision: expectedRevision,
      ),
      eventType: 'completed',
      note: note ?? '实际完成日期 ${dateKey(completedDate ?? _now())}',
    );
  }

  Future<String> skip({
    required String tankId,
    required String taskId,
    String? note,
    DateTime? occurrenceDate,
    int? expectedRevision,
  }) {
    return _changeRolling(
      tankId: tankId,
      taskId: taskId,
      change: (tasks, now) => stopRollingTasks(
        tasks,
        taskId,
        now,
        expectedRevision: expectedRevision,
      ),
      eventType: 'skipped',
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

  if (task.rollingJson == null &&
      !task.isOneOff &&
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
  if ((task.rollingJson == null || rollingSchedule(task).revision == 0) &&
      activeMaintenanceSnoozeUntilUtc(latestEvent, now.toUtc()) != null) {
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
  if (task.rollingJson != null && rollingSchedule(task).revision > 0) {
    return task.dueAt.toUtc();
  }
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

List<MaintenanceTaskItem> prepareMaintenanceTaskItems(
  List<MaintenanceTaskItem> items,
  DateTime now,
) {
  final tasks = [
    for (final item in items)
      initializeRollingTask(
        item.task,
        events: item.latestEvent == null ? [] : [item.latestEvent!],
      ),
  ];
  final dates = projectRollingDates(tasks, now);
  return [
    for (var i = 0; i < tasks.length; i++)
      MaintenanceTaskItem(
        task: tasks[i].copyWith(
          dueAt: rollingDueOn(tasks[i], dates[tasks[i].id]!),
        ),
        latestEvent: items[i].latestEvent,
        state: _viewState(
          tasks[i].copyWith(dueAt: rollingDueOn(tasks[i], dates[tasks[i].id]!)),
          items[i].latestEvent,
          now.toUtc(),
        ),
      ),
  ];
}

MaintenanceTaskItem notificationOccurrence(
  MaintenanceTaskItem item,
  DateTime now,
) {
  if (item.task.source == 'maintenance-cycle') return item;
  if (item.task.status != 'enabled') return item;
  final task = initializeRollingTask(
    item.task,
    events: item.latestEvent == null ? [] : [item.latestEvent!],
  );
  // A chemical queue is projected together by its caller. Do not independently
  // move its later members back to their stored base dates.
  final date = rollingChemicalKey(task) == null
      ? projectRollingDates([task], now)[task.id]!
      : dateKey(task.dueAt);
  if (!rollingPendingOnDate(task, date, date)) {
    return MaintenanceTaskItem(
      task: task.copyWith(status: 'disabled'),
      state: MaintenanceTaskViewState.disabled,
    );
  }
  final due = rollingDueOn(task, date);
  return MaintenanceTaskItem(
    task: task.copyWith(dueAt: due),
    latestEvent: item.latestEvent,
    occurrenceDate: DateTime.parse(date),
    state: _viewState(task.copyWith(dueAt: due), item.latestEvent, now.toUtc()),
  );
}

/// Expand only the visible date window, with a single completion-driven head.
List<MaintenanceTaskItem> calendarOccurrences(
  List<MaintenanceTaskItem> items,
  DateTime start,
  int days, {
  DateTime? now,
}) {
  if (days < 0 || days > 366) throw ArgumentError('日历窗口须为 0–366 天');
  final clock = now ?? DateTime.now(), result = <MaintenanceTaskItem>[];
  final tasks = [
    for (final item in items)
      initializeRollingTask(
        item.task,
        events: item.latestEvent == null ? [] : [item.latestEvent!],
      ),
  ];
  final dates = projectRollingDates(tasks, clock);
  final related = <String, List<MaintenanceTask>>{};
  String groupKey(MaintenanceTask task) {
    final chemical = rollingChemicalKey(task);
    return chemical == null ? 'task:${task.id}' : 'chemical:$chemical';
  }

  for (final task in tasks) {
    related.putIfAbsent(groupKey(task), () => []).add(task);
  }
  for (var index = 0; index < tasks.length; index++) {
    final task = tasks[index], item = items[index];
    if (task.status == 'archived') continue;
    final schedule = rollingSchedule(task);
    final latest = schedule.completed.lastOrNull?.completedDate;
    final editableDate =
        latest != null &&
            canEditRollingCompletion(related[groupKey(task)]!, task, latest)
        ? latest
        : null;
    for (var i = 0; i < days; i++) {
      final date = DateTime(start.year, start.month, start.day + i),
          key = dateKey(date);
      final pending = rollingPendingOnDate(task, key, dates[task.id]!);
      final history = rollingHistoryState(task, key);
      if (!pending && history != 'completed') continue;
      final due = rollingDueOn(task, key);
      // A pending head may land on an existing historical date after editing.
      // Keep both facts, just as Web's separate pending/completed selectors do.
      for (final done in [
        if (history == 'completed') true,
        if (pending) false,
      ]) {
        final snoozed =
            !done &&
            dateKey(clock) == key &&
            activeMaintenanceSnoozeUntilUtc(item.latestEvent, clock.toUtc()) !=
                null &&
            schedule.revision == 0;
        result.add(
          MaintenanceTaskItem(
            task: task.copyWith(dueAt: due),
            occurrenceDate: date,
            latestEvent: snoozed ? item.latestEvent : null,
            state: done
                ? MaintenanceTaskViewState.completed
                : snoozed
                ? MaintenanceTaskViewState.snoozed
                : due.isAfter(clock)
                ? MaintenanceTaskViewState.upcoming
                : MaintenanceTaskViewState.overdue,
            canEditCompletion: done && editableDate == key,
            canReopen:
                done &&
                (editableDate == key ||
                    (schedule.completed.isEmpty &&
                        schedule.legacyCompletedDates.every(
                          (d) => d.compareTo(key) <= 0,
                        ))),
          ),
        );
      }
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
