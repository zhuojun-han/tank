import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart';
import '../features/calculators/data/maintenance_cycle_repository.dart';
import '../features/calculators/domain/maintenance_cycle.dart';
import '../features/maintenance/data/maintenance_repository.dart';
import '../features/maintenance/domain/recurrence.dart';
import '../features/maintenance/domain/rolling_schedule.dart';
import 'native_state_store.dart';

/// Native commands return canonical state; Web never writes completion history.
class NativeTaskActions {
  NativeTaskActions(this.db, this.store, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final AppDatabase db;
  final NativeStateStore store;
  final DateTime Function() _now;

  Future<Map<String, dynamic>> handle(Map<String, dynamic> args) =>
      db.transaction(() async {
        await _apply(args);
        return store.readState();
      });

  Future<void> apply(Map<String, dynamic> args) =>
      db.transaction(() => _apply(args));

  Future<void> _apply(Map<String, dynamic> args) async {
    final before = await store.readState();
    if (args['expectedRevision'] is! int ||
        args['expectedRevision'] != before['revision']) {
      throw const NativeStateConflict('数据已变化，请重新打开任务。');
    }
    final tankId = stateId(args['tankId']),
        action = stateText(args['action'], 80);
    final tank =
        await (db.select(db.tanks)
              ..where((t) => t.id.equals(tankId) & t.isArchived.equals(false)))
            .getSingleOrNull();
    if (tank == null) throw const FormatException('当前海缸不存在或已归档。');
    final repository = MaintenanceRepository(db, now: _now);
    final cycles = MaintenanceCycleRepository(db, now: _now);
    final now = _now();
    if (action == 'cycle.stop') {
      final cycleId = stateId(args['cycleId'] ?? args['taskId']);
      final owned = (await cycles.getCycles(tankId: tankId))
          .where(
            (c) =>
                c.id == cycleId && c.closedOnDate == null && c.theory != null,
          )
          .firstOrNull;
      if (owned == null) throw const FormatException('当前海缸没有该理论配液周期。');
      await (db.update(
        db.maintenanceCycles,
      )..where((c) => c.id.equals(cycleId))).write(
        MaintenanceCyclesCompanion(
          closedOnDate: Value(cycleDateKey(now)),
          updatedAt: Value(now.toUtc()),
        ),
      );
      return;
    }
    if (action == 'cycle.delay') {
      final cycleId = stateId(args['cycleId']);
      final owned = (await cycles.getCycles(
        tankId: tankId,
      )).where((c) => c.id == cycleId && c.closedOnDate == null).firstOrNull;
      if (owned == null) throw const FormatException('当前海缸没有该补液周期。');
      final due = maintenanceReminderDate(owned, cycleDateKey(now));
      if (due != cycleDateKey(now) ||
          args['occurrenceDate'] != null &&
              stateDate(args['occurrenceDate']) != due) {
        throw const FormatException('仅能延迟今天需处理的补液提醒。');
      }
      await cycles.delay(
        cycleId,
        _positive(args['value']),
        expectedDeferredUntil: args['deferredUntil'] == null
            ? null
            : stateDate(args['deferredUntil']),
      );
      final row = await (db.select(
        db.maintenanceCycles,
      )..where((c) => c.id.equals(cycleId))).getSingle();
      final input = stateMap(jsonDecode(row.inputJson));
      if (input.remove('webviewSnoozedUntil') != null) {
        await (db.update(
          db.maintenanceCycles,
        )..where((c) => c.id.equals(cycleId))).write(
          MaintenanceCyclesCompanion(inputJson: Value(jsonEncode(input))),
        );
      }
      return;
    }
    if (action == 'plan.create' || action == 'plan.replace') {
      await _savePlan(args, tankId, now, replace: action == 'plan.replace');
      return;
    }
    if (action == 'create') {
      final interval = _interval(args),
          reminder = _reminder(args['reminderTime'] ?? '09:00');
      await repository.createTask(
        tankId: tankId,
        title: stateText(args['title'], 120),
        notes: _notes(args['notes']),
        intervalAmount: interval.$1,
        intervalUnit: interval.$2,
        dueAt: _dueAt(args['scheduledDate'], reminder),
        preferredReminderTime: reminder,
        isOneOff: args['oneOff'] == true,
        source: 'manual',
        calendarRecurrence: false,
      );
      return;
    }
    final taskId = stateId(args['taskId']);
    final originalTasks = {
      for (final t in await (db.select(
        db.maintenanceTasks,
      )..where((t) => t.tankId.equals(tankId))).get())
        t.id: t,
    };
    final stored =
        await (db.select(db.maintenanceTasks)..where(
              (t) =>
                  t.id.equals(taskId) &
                  t.tankId.equals(tankId) &
                  t.status.isNotIn(['archived']),
            ))
            .getSingleOrNull();
    if (stored == null) throw const FormatException('任务与当前海缸不匹配。');
    final revision = args['taskRevision'];
    if (revision != null &&
        (revision is! int || revision != rollingSchedule(stored).revision)) {
      throw const NativeStateConflict('任务排期已变化，请重新打开。');
    }
    if ({'complete', 'delay'}.contains(action) ||
        action == 'skip' && !isChemicalPlan(stored)) {
      final effective = projectRollingDates(
        await _rollingTasks(tankId),
        now,
      )[taskId];
      if (stored.status != 'enabled' ||
          effective != dateKey(now) ||
          args['occurrenceDate'] != null &&
              stateDate(args['occurrenceDate']) != effective) {
        throw const FormatException('仅能处理今天到期的任务，请重新打开任务列表。');
      }
    }
    switch (action) {
      case 'complete':
        await repository.complete(
          tankId: tankId,
          taskId: taskId,
          completedDate: _date(args['value']),
          expectedRevision: revision as int?,
        );
      case 'delay':
        await repository.delayTask(
          tankId: tankId,
          taskId: taskId,
          days: _positive(args['value']),
          expectedRevision: revision as int?,
        );
      case 'correct':
        await repository.correctCompletion(
          tankId: tankId,
          taskId: taskId,
          completedDate: _date(args['occurrenceDate']),
          newDate: _date(args['value']),
          expectedRevision: revision as int?,
        );
      case 'reopen':
        try {
          await repository.reopen(
            tankId: tankId,
            taskId: taskId,
            occurrenceDate: _date(args['occurrenceDate']),
            expectedRevision: revision as int?,
          );
        } on StateError catch (error) {
          if (error.message == '只能重开最近可修改的完成记录') {
            throw const FormatException('该记录不能重新标记，请选择最近一次可修改的完成记录。');
          }
          rethrow;
        }
      case 'stop':
      case 'skip':
        if (isChemicalPlan(stored)) {
          await _stopPlan(stored, now, revision as int?);
        } else {
          await repository.skip(
            tankId: tankId,
            taskId: taskId,
            expectedRevision: revision as int?,
          );
        }
      case 'plan.stop':
        if (!isChemicalPlan(stored)) throw const FormatException('该任务不是药剂计划。');
        await _stopPlan(stored, now, revision as int?);
      case 'update':
        final interval = _interval(args, stored: stored),
            reminder = _reminder(
              args['reminderTime'] ?? stored.preferredReminderTime,
            );
        await repository.updateTask(
          tankId: tankId,
          taskId: taskId,
          title: stateText(args['title'] ?? stored.title, 120),
          notes: args.containsKey('notes')
              ? _notes(args['notes'])
              : stored.notes,
          intervalAmount: interval.$1,
          intervalUnit: interval.$2,
          dueAt: _dueAt(
            args['scheduledDate'] ?? rollingSchedule(stored).nextDate,
            reminder,
          ),
          preferredReminderTime: reminder,
        );
      default:
        throw const FormatException('不支持的任务操作。');
    }
    final changedIds = <String>{taskId};
    for (final task in await (db.select(
      db.maintenanceTasks,
    )..where((t) => t.tankId.equals(tankId))).get()) {
      if (task != originalTasks[task.id]) changedIds.add(task.id);
    }
    await _clearReminders(changedIds);
  }

  Future<void> _clearReminders(Set<String> ids) async {
    await (db.delete(db.taskEvents)..where(
          (e) => e.taskId.isIn(ids) & e.note.equals('webview-reminder-only'),
        ))
        .go();
  }

  Future<List<MaintenanceTask>> _rollingTasks(String tankId) async {
    final rows = await (db.select(
      db.maintenanceTasks,
    )..where((t) => t.tankId.equals(tankId))).get();
    final ids = rows.map((t) => t.id).toSet();
    final events = await (db.select(
      db.taskEvents,
    )..where((e) => e.taskId.isIn(ids))).get();
    final byTask = <String, List<TaskEvent>>{};
    for (final event in events) {
      byTask.putIfAbsent(event.taskId, () => []).add(event);
    }
    return [
      for (final row in rows)
        initializeRollingTask(row, events: byTask[row.id] ?? []),
    ];
  }

  Future<void> _stopPlan(
    MaintenanceTask selected,
    DateTime now,
    int? revision,
  ) async {
    final all = await _rollingTasks(selected.tankId);
    final candidates = all
        .where(
          (t) =>
              t.source == selected.source &&
              t.planId == selected.planId &&
              t.status == 'enabled' &&
              (t.planDayIndex ?? 0) >= (selected.planDayIndex ?? 0),
        )
        .toList();
    // A suffix has its own head; earlier pending and completed days stay intact.
    final changed = stopRollingTasks(
      candidates,
      selected.id,
      now,
      expectedRevision: revision,
    );
    for (final task in changed) {
      await (db.update(db.maintenanceTasks)..where(
            (t) => t.id.equals(task.id) & t.tankId.equals(selected.tankId),
          ))
          .write(
            MaintenanceTasksCompanion(
              status: Value(task.status),
              rollingJson: Value(task.rollingJson),
              updatedAt: Value(now.toUtc()),
            ),
          );
      await db
          .into(db.taskEvents)
          .insert(
            TaskEventsCompanion.insert(
              id: const Uuid().v4(),
              taskId: task.id,
              type: 'skipped',
              occurredAt: now.toUtc(),
              note: const Value('已停止所选日及后续药剂计划'),
            ),
          );
    }
    await _clearReminders(changed.map((t) => t.id).toSet());
  }

  Future<void> _savePlan(
    Map<String, dynamic> args,
    String tankId,
    DateTime now, {
    required bool replace,
  }) async {
    final source = stateText(args['source'], 80),
        from = stateDate(args['fromDate']);
    if (!{'lanthanum-plan', 'alkalinity-plan'}.contains(source) ||
        from.compareTo(dateKey(now)) < 0) {
      throw const FormatException('药剂来源或计划开始日期无效。');
    }
    final incoming = stateRows({'tasks': args['tasks']}, 'tasks');
    if (incoming.isEmpty || incoming.length > 366) {
      throw const FormatException('药剂计划须为 1–366 天。');
    }
    final planIds = <String>{}, dayIndexes = <int>{};
    for (final task in incoming) {
      if (task['tankId'] != tankId ||
          task['source'] != source ||
          stateDate(task['scheduledDate']).compareTo(from) < 0) {
        throw const FormatException('新计划的海缸、药剂或日期不匹配。');
      }
      planIds.add(stateId(task['planId']));
      if (task['dayIndex'] is! int ||
          !dayIndexes.add(task['dayIndex'] as int)) {
        throw const FormatException('药剂计划日期编号重复。');
      }
    }
    if (planIds.length != 1) throw const FormatException('一次只能保存一个药剂计划。');
    final existing = await _rollingTasks(tankId),
        heads = <String, MaintenanceTask>{};
    final dates = projectRollingDates(existing, now);
    if (existing.any((t) => t.planId == planIds.single)) {
      throw const FormatException('新计划标识已被使用。');
    }
    for (final task in existing.where(
      (t) =>
          t.source == source &&
          t.planId != null &&
          t.status == 'enabled' &&
          dates[t.id]!.compareTo(from) >= 0,
    )) {
      final old = heads[task.planId];
      if (old == null || (task.planDayIndex ?? 0) < (old.planDayIndex ?? 0)) {
        heads[task.planId!] = task;
      }
    }
    if (!replace && heads.isNotEmpty) {
      throw const FormatException('已有后续药剂计划，请选择替换或仅计算。');
    }
    for (final task in heads.values) {
      await _stopPlan(task, now, null);
    }
    final current = await store.readState();
    final snapshot = stateMap(current['state']);
    snapshot['tasks'] = [...stateRows(snapshot, 'tasks'), ...incoming];
    await store.commitState(
      snapshot,
      expectedRevision: current['revision'] as int,
    );
  }

  static (int, MaintenanceIntervalUnit) _interval(
    Map<String, dynamic> args, {
    MaintenanceTask? stored,
  }) {
    if (args.containsKey('intervalUnit') ||
        args.containsKey('intervalAmount')) {
      final unit = MaintenanceIntervalUnit.values
          .where((u) => u.name == args['intervalUnit'])
          .firstOrNull;
      if (unit == null) throw const FormatException('重复单位须为 day、week 或 month。');
      final amount = _positive(args['intervalAmount']);
      if (unit == MaintenanceIntervalUnit.month && amount > 119987) {
        throw const FormatException('重复月份超出范围。');
      }
      return (amount, unit);
    }
    if (args.containsKey('intervalDays')) {
      if (stored?.intervalUnit == 'month') {
        throw const FormatException('月度任务请保留月份单位，不可按天数改写。');
      }
      final days = _positive(args['intervalDays']);
      if (stored?.intervalUnit == 'week' &&
          days == stored!.intervalAmount * 7) {
        return (stored.intervalAmount, MaintenanceIntervalUnit.week);
      }
      return (days, MaintenanceIntervalUnit.day);
    }
    if (stored != null) {
      return (
        stored.intervalAmount,
        MaintenanceIntervalUnit.values.singleWhere(
          (u) => u.name == stored.intervalUnit,
        ),
      );
    }
    return (1, MaintenanceIntervalUnit.day);
  }

  static String? _notes(Object? value) {
    if (value == null) return null;
    if (value is! String || value.length > 100000) {
      throw const FormatException('任务备注无效。');
    }
    return value.trim().isEmpty ? null : value.trim();
  }

  static int _positive(Object? value) {
    if (value is! int || value < 1 || value > 365000) {
      throw const FormatException('间隔须为正整数。');
    }
    return value;
  }

  static DateTime _date(Object? value) =>
      DateTime.parse('${stateDate(value)}T12:00:00');
  static String _reminder(Object? value) {
    final text = stateText(value, 5),
        match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(text);
    if (match == null ||
        int.parse(match.group(1)!) > 23 ||
        int.parse(match.group(2)!) > 59) {
      throw const FormatException('提醒时间须为 HH:mm。');
    }
    return text;
  }

  static DateTime _dueAt(Object? date, String time) =>
      DateTime.parse('${stateDate(date)}T$time:00');
}
