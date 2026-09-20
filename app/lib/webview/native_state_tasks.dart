import 'package:drift/drift.dart';

import '../data/database/app_database.dart';
import '../features/maintenance/domain/recurrence.dart';
import '../features/maintenance/domain/rolling_schedule.dart';
import 'native_state_store.dart';

Map<String, dynamic> nativeTaskToWeb(
  MaintenanceTask task,
  List<TaskEvent> events,
) {
  events = events.where((e) => e.note != 'webview-reminder-only').toList()
    ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
  final schedule = rollingSchedule(task, events: events);
  final legacy = schedule.legacySchedule;
  final rule = legacy != null
      ? Recurrence.decode(legacy['recurrenceJson'] as String)
      : task.recurrenceJson != null
      ? Recurrence.decode(task.recurrenceJson!)
      : null;
  final completed = <String>{
    ...schedule.legacyCompletedDates,
    if (rule != null)
      ...rule.states.entries
          .where((e) => e.value == 'completed')
          .map((e) => e.key),
  }.toList()..sort();
  final skipped =
      rule?.states.entries
          .where((e) => e.value == 'skipped')
          .map((e) => e.key)
          .toList() ??
      <String>[];
  final stopped = task.status == 'disabled' || task.status == 'skipped';
  final latestSnooze = events.isNotEmpty && events.last.type == 'snoozed'
      ? events.last.snoozedUntil
      : null;
  final stoppedEvent = events.where((e) => e.type == 'skipped').lastOrNull;
  final units = {'day': '天', 'week': '周', 'month': '月'};
  return {
    'id': task.id,
    'tankId': task.tankId,
    'title': task.title,
    'detail': task.notes ?? '',
    'cycle': task.isOneOff
        ? '单次任务'
        : '每 ${task.intervalAmount} ${units[task.intervalUnit]}',
    'due': '${schedule.nextDate} ${task.preferredReminderTime}',
    'state': task.status == 'completed'
        ? 'done'
        : stopped
        ? 'skipped'
        : 'due',
    'oneOff': task.isOneOff,
    'scheduledDate': schedule.startDate,
    if (!task.isOneOff && task.intervalUnit != 'month')
      'intervalDays':
          task.intervalAmount * (task.intervalUnit == 'week' ? 7 : 1),
    'nativeIntervalUnit': task.intervalUnit,
    'nativeIntervalAmount': task.intervalAmount,
    if (task.source != null) 'source': task.source,
    if (task.planId != null) 'planId': task.planId,
    if (task.planDayIndex != null) 'dayIndex': task.planDayIndex,
    if (task.planTotalDays != null) 'totalDays': task.planTotalDays,
    'completedDates': completed,
    'skippedDates': skipped,
    'reopenedDates': schedule.reopenedDates,
    'snoozedDates': rule?.snoozes.keys.toList() ?? <String>[],
    'snoozedUntilByDate': rule?.snoozes ?? <String, String>{},
    if (latestSnooze != null)
      'snoozedUntil': latestSnooze.toUtc().toIso8601String(),
    if (rule != null) 'defaultCompletedBeforeDate': rule.completedBefore,
    if (rule?.stoppedAfter != null || stopped)
      'stoppedAfterDate':
          rule?.stoppedAfter ??
          dateKey(stoppedEvent?.occurredAt ?? task.updatedAt),
    'rolling': {
      'version': 1,
      'nextDate': schedule.nextDate,
      'revision': schedule.revision,
      'completed': [for (final c in schedule.completed) c.toJson()],
      if (rule != null)
        'legacySchedule': {
          'scheduledDate': rule.start,
          if ((legacy?['intervalUnit'] ?? task.intervalUnit) != 'month')
            'intervalDays':
                (legacy?['intervalAmount'] as int? ?? task.intervalAmount) *
                ((legacy?['intervalUnit'] ?? task.intervalUnit) == 'week'
                    ? 7
                    : 1),
          'defaultCompletedBeforeDate': rule.completedBefore,
          'nativeIntervalUnit': legacy?['intervalUnit'] ?? task.intervalUnit,
          'nativeIntervalAmount':
              legacy?['intervalAmount'] ?? task.intervalAmount,
          if (rule.stoppedAfter != null) 'stoppedAfterDate': rule.stoppedAfter,
        },
    },
  };
}

/// Existing task scheduling is mutated only by MaintenanceRepository commands;
/// the Web snapshot cannot forge completion history or overwrite native rules.
Future<void> saveNativeTasks(
  AppDatabase db,
  Map<String, dynamic> state,
  Map<String, dynamic> prior,
  Set<String> tanks,
) async {
  final rows = stateRows(state, 'tasks'), oldRows = stateRows(prior, 'tasks');
  if (nativeStateEqual(rows, oldRows)) return;
  final oldById = {for (final row in oldRows) row['id']: row};
  final allIds = (await db.select(db.maintenanceTasks).get())
      .map((t) => t.id)
      .toSet();
  for (final input in rows) {
    final row = Map<String, dynamic>.from(input)..remove('projection');
    final old = oldById[row['id']];
    if (nativeStateEqual(row, old)) continue;
    final id = stateId(row['id']), tank = stateId(row['tankId']);
    if (!tanks.contains(tank) || old != null && old['tankId'] != tank) {
      throw const FormatException('任务与海缸不匹配。');
    }
    if (old != null) throw const FormatException('任务已存在，请通过任务操作更新排期。');
    if (allIds.contains(id)) throw const FormatException('任务标识已被归档记录使用。');
    final title = stateText(row['title'], 120),
        date = stateDate(row['scheduledDate']);
    final oneOff = row['oneOff'] == true;
    final interval = row['intervalDays'] ?? 1;
    if (interval is! int || interval < 1 || interval > 3652058) {
      throw const FormatException('重复间隔无效。');
    }
    final reminder = RegExp(
      r'(\d{2}):(\d{2})',
    ).firstMatch(row['due'] is String ? row['due'] as String : '');
    final hour = reminder == null ? 9 : int.parse(reminder.group(1)!);
    final minute = reminder == null ? 0 : int.parse(reminder.group(2)!);
    if (hour > 23 || minute > 59) throw const FormatException('任务提醒时间无效。');
    final time =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    if (!{'due', 'soon'}.contains(row['state']) ||
        row['stoppedAfterDate'] != null ||
        row['hiddenFromCalendar'] == true) {
      throw const FormatException('新任务不能携带已完成或已停止状态。');
    }
    if (row['rolling'] != null) {
      final rolling = stateMap(row['rolling']);
      if (rolling['nextDate'] != date ||
          rolling['revision'] != 0 ||
          rolling['completed'] is! List ||
          (rolling['completed'] as List).isNotEmpty ||
          rolling['legacySchedule'] != null) {
        throw const FormatException('新任务排期无效。');
      }
    }
    for (final key in [
      'completedDates',
      'skippedDates',
      'reopenedDates',
      'snoozedDates',
    ]) {
      if (row[key] != null &&
          (row[key] is! List || (row[key] as List).isNotEmpty)) {
        throw const FormatException('新任务不能包含虚构历史。');
      }
    }
    final source = row['source'] as String?;
    if (source != null &&
        !{'manual', 'lanthanum-plan', 'alkalinity-plan'}.contains(source)) {
      throw const FormatException('任务来源无效。');
    }
    final planId = row['planId'] as String?,
        index = row['dayIndex'],
        total = row['totalDays'];
    if (source == 'lanthanum-plan' || source == 'alkalinity-plan') {
      if (planId == null ||
          planId.isEmpty ||
          index is! int ||
          total is! int ||
          index < 1 ||
          total < index ||
          !oneOff) {
        throw const FormatException('药剂计划信息无效。');
      }
    }
    final now = DateTime.now().toUtc();
    await db
        .into(db.maintenanceTasks)
        .insert(
          MaintenanceTasksCompanion.insert(
            id: id,
            tankId: tank,
            title: title,
            notes: Value(row['detail'] as String?),
            intervalAmount: interval,
            intervalUnit: 'day',
            dueAt: DateTime.parse('${date}T$time:00').toUtc(),
            preferredReminderTime: Value(time),
            isOneOff: Value(oneOff),
            source: Value(source),
            planId: Value(planId),
            planDayIndex: Value(index as int?),
            planTotalDays: Value(total as int?),
            rollingJson: Value(
              RollingSchedule(startDate: date, nextDate: date).encode(),
            ),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
  if (oldRows.any((old) => !rows.any((r) => r['id'] == old['id']))) {
    throw const FormatException('停止任务请使用任务操作，不能删除历史计划。');
  }
}
