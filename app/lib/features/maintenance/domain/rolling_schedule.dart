import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../data/database/app_database.dart';
import 'recurrence.dart';

bool _validDate(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return false;
  }
  final parsed = DateTime.tryParse(value);
  return parsed != null && parsed.year >= 1 && dateKey(parsed) == value;
}

DateTime _date(String value) {
  if (!_validDate(value)) throw const FormatException('任务日期无效');
  return DateTime.parse(value);
}

int calendarDayDifference(String a, String b) {
  final x = _date(a), y = _date(b);
  return DateTime.utc(
    x.year,
    x.month,
    x.day,
  ).difference(DateTime.utc(y.year, y.month, y.day)).inDays;
}

String addRollingDays(String date, int days) {
  final start = _date(date);
  // Check before constructing a DateTime with an unbounded user-supplied day.
  if (days.abs() > 3652058) throw const FormatException('延迟日期超出支持范围');
  final result = DateTime(start.year, start.month, start.day + days);
  final key = dateKey(result);
  if (!_validDate(key)) throw const FormatException('任务日期超出支持范围');
  return key;
}

String nextRollingDate(MaintenanceTask task, String from) {
  if (task.intervalAmount <= 0) throw const FormatException('重复间隔必须大于0');
  if (task.intervalUnit != 'month') {
    return addRollingDays(
      from,
      task.intervalAmount * (task.intervalUnit == 'week' ? 7 : 1),
    );
  }
  final date = _date(from);
  if (task.intervalAmount > 119987) throw const FormatException('重复日期超出支持范围');
  final month = DateTime(date.year, date.month + task.intervalAmount);
  final last = DateTime(month.year, month.month + 1, 0).day;
  final result = dateKey(
    DateTime(month.year, month.month, date.day > last ? last : date.day),
  );
  if (!_validDate(result)) throw const FormatException('重复日期超出支持范围');
  return result;
}

class RollingCompletion {
  const RollingCompletion(this.dueDate, this.completedDate);
  final String dueDate, completedDate;
  Map<String, Object> toJson() => {
    'dueDate': dueDate,
    'completedDate': completedDate,
  };
}

/// Only this state is persisted. Calendar projection never rewrites dates.
class RollingSchedule {
  RollingSchedule({
    required this.startDate,
    required this.nextDate,
    this.revision = 0,
    List<RollingCompletion>? completed,
    this.legacySchedule,
    List<String>? legacyCompletedDates,
    List<String>? reopenedDates,
  }) : completed = completed ?? [],
       legacyCompletedDates = legacyCompletedDates ?? [],
       reopenedDates = reopenedDates ?? [];

  final String startDate, nextDate;
  final int revision;
  final List<RollingCompletion> completed;
  final Map<String, dynamic>? legacySchedule;
  final List<String> legacyCompletedDates, reopenedDates;

  RollingSchedule copyWith({
    String? nextDate,
    int? revision,
    List<RollingCompletion>? completed,
    List<String>? reopenedDates,
  }) => RollingSchedule(
    startDate: startDate,
    nextDate: nextDate ?? this.nextDate,
    revision: revision ?? this.revision,
    completed: completed ?? this.completed,
    legacySchedule: legacySchedule,
    legacyCompletedDates: legacyCompletedDates,
    reopenedDates: reopenedDates ?? this.reopenedDates,
  );

  String encode() => jsonEncode({
    'version': 1,
    'startDate': startDate,
    'nextDate': nextDate,
    'revision': revision,
    'completed': completed.map((entry) => entry.toJson()).toList(),
    if (legacySchedule != null) 'legacySchedule': legacySchedule,
    if (legacyCompletedDates.isNotEmpty)
      'legacyCompletedDates': legacyCompletedDates,
    if (reopenedDates.isNotEmpty) 'reopenedDates': reopenedDates,
  });

  factory RollingSchedule.decode(String source) {
    final j = jsonDecode(source);
    if (j is! Map<String, dynamic> ||
        j['version'] != 1 ||
        !_validDate(j['startDate']) ||
        !_validDate(j['nextDate']) ||
        j['revision'] is! int ||
        (j['revision'] as int) < 0 ||
        (j['revision'] as int) > 9007199254740991 ||
        j['completed'] is! List) {
      throw const FormatException('任务滚动排期无效');
    }
    final completed = <RollingCompletion>[];
    for (final entry in j['completed'] as List) {
      if (entry is! Map ||
          !_validDate(entry['dueDate']) ||
          !_validDate(entry['completedDate']) ||
          (completed.isNotEmpty &&
              (entry['completedDate'] as String).compareTo(
                    completed.last.completedDate,
                  ) <=
                  0)) {
        throw const FormatException('实际完成日期必须有序且有效');
      }
      completed.add(
        RollingCompletion(
          entry['dueDate'] as String,
          entry['completedDate'] as String,
        ),
      );
    }
    List<String> dates(String key) {
      final value = j[key];
      if (value == null) return [];
      if (value is! List || value.any((date) => !_validDate(date))) {
        throw const FormatException('任务历史日期无效');
      }
      return List<String>.from(value);
    }

    final legacy = j['legacySchedule'];
    if (legacy != null &&
        (legacy is! Map<String, dynamic> ||
            legacy['recurrenceJson'] is! String ||
            !validRecurrence(legacy['recurrenceJson'] as String) ||
            legacy['intervalAmount'] is! int ||
            (legacy['intervalAmount'] as int) <= 0 ||
            !{'day', 'week', 'month'}.contains(legacy['intervalUnit']))) {
      throw const FormatException('旧任务排期无效');
    }
    return RollingSchedule(
      startDate: j['startDate'] as String,
      nextDate: j['nextDate'] as String,
      revision: j['revision'] as int,
      completed: completed,
      legacySchedule: legacy as Map<String, dynamic>?,
      legacyCompletedDates: dates('legacyCompletedDates'),
      reopenedDates: dates('reopenedDates'),
    );
  }
}

bool validRollingSchedule(String? source) {
  if (source == null) return true;
  try {
    RollingSchedule.decode(source);
    return true;
  } catch (_) {
    return false;
  }
}

RollingSchedule rollingSchedule(
  MaintenanceTask task, {
  Iterable<TaskEvent> events = const [],
}) {
  if (task.rollingJson != null) {
    return RollingSchedule.decode(task.rollingJson!);
  }
  final legacyCompleted =
      events
          .where((e) => e.type == 'completed')
          .map((e) => dateKey(e.occurredAt))
          .toSet()
          .toList()
        ..sort();
  var start = dateKey(task.dueAt), next = start;
  Map<String, dynamic>? legacy;
  if (task.recurrenceJson != null) {
    final rule = Recurrence.decode(task.recurrenceJson!);
    start = rule.start;
    legacy = {
      'recurrenceJson': task.recurrenceJson!,
      'intervalAmount': task.intervalAmount,
      'intervalUnit': task.intervalUnit,
    };
    final handled =
        rule.states.entries
            .where(
              (e) => e.value != 'pending' && rule.occurs(task, _date(e.key)),
            )
            .map((e) => e.key)
            .toList()
          ..sort();
    next = handled.isEmpty
        ? start
        : dateKey(rule.nextDate(task, _date(addRollingDays(handled.last, 1))));
    if (next.compareTo(rule.completedBefore) < 0) {
      next = dateKey(rule.nextDate(task, _date(rule.completedBefore)));
    }
    final reopened =
        rule.states.entries
            .where(
              (e) => e.value == 'pending' && rule.occurs(task, _date(e.key)),
            )
            .map((e) => e.key)
            .toList()
          ..sort();
    if (reopened.isNotEmpty && reopened.first.compareTo(next) < 0) {
      next = reopened.first;
    }
  }
  return RollingSchedule(
    startDate: start,
    nextDate: next,
    legacySchedule: legacy,
    legacyCompletedDates: legacyCompleted,
  );
}

MaintenanceTask initializeRollingTask(
  MaintenanceTask task, {
  Iterable<TaskEvent> events = const [],
}) => task.rollingJson != null
    ? task
    : task.copyWith(
        rollingJson: Value(rollingSchedule(task, events: events).encode()),
      );

String? rollingChemicalKey(MaintenanceTask task) =>
    task.planId != null &&
        {'lanthanum-plan', 'alkalinity-plan'}.contains(task.source)
    ? jsonEncode([task.tankId, task.source, task.planId])
    : null;

bool rollingTaskActive(MaintenanceTask task) => task.status == 'enabled';

int _compare(MaintenanceTask a, MaintenanceTask b) {
  final byDate = rollingSchedule(
    a,
  ).nextDate.compareTo(rollingSchedule(b).nextDate);
  if (byDate != 0) return byDate;
  final byDay = (a.planDayIndex ?? 0).compareTo(b.planDayIndex ?? 0);
  return byDay != 0 ? byDay : a.id.compareTo(b.id);
}

/// One pass over groups; no date range or duplicate future rows are expanded.
Map<String, String> projectRollingDates(
  List<MaintenanceTask> tasks,
  DateTime now,
) {
  final today = dateKey(now), heads = <String, MaintenanceTask>{};
  final schedules = {for (final task in tasks) task.id: rollingSchedule(task)};
  for (final task in tasks) {
    final key = rollingChemicalKey(task);
    if (key == null || !rollingTaskActive(task)) continue;
    final head = heads[key];
    if (head == null || _compare(task, head) < 0) heads[key] = task;
  }
  final shifts = {
    for (final entry in heads.entries)
      entry.key: calendarDayDifference(
        today,
        schedules[entry.value.id]!.nextDate,
      ).clamp(0, 3652058).toInt(),
  };
  final result = <String, String>{};
  for (final task in tasks) {
    final schedule = schedules[task.id]!, key = rollingChemicalKey(task);
    result[task.id] = !rollingTaskActive(task)
        ? schedule.completed.lastOrNull?.completedDate ?? schedule.nextDate
        : key != null
        ? addRollingDays(schedule.nextDate, shifts[key] ?? 0)
        : schedule.nextDate.compareTo(today) < 0
        ? today
        : schedule.nextDate;
  }
  return result;
}

DateTime rollingDueOn(MaintenanceTask task, String date) {
  final d = _date(date), parts = task.preferredReminderTime.split(':');
  return DateTime(
    d.year,
    d.month,
    d.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  ).toUtc();
}

String? rollingHistoryState(MaintenanceTask task, String date) {
  final schedule = rollingSchedule(task);
  if (schedule.completed.any((e) => e.completedDate == date)) {
    return 'completed';
  }
  if (schedule.reopenedDates.contains(date)) return null;
  if (schedule.legacyCompletedDates.contains(date)) return 'completed';
  final legacy = schedule.legacySchedule;
  if (legacy != null) {
    final rule = Recurrence.decode(legacy['recurrenceJson'] as String);
    final oldTask = task.copyWith(
      intervalAmount: legacy['intervalAmount'] as int,
      intervalUnit: legacy['intervalUnit'] as String,
    );
    if (rule.occurs(oldTask, _date(date))) {
      final state = rule.stateOn(_date(date));
      if (state != 'pending') return state;
    }
  }
  if (schedule.revision == 0 &&
      schedule.legacyCompletedDates.isEmpty &&
      task.isOneOff &&
      task.status == 'completed' &&
      date == schedule.startDate) {
    return 'completed';
  }
  return null;
}

bool rollingPendingOnDate(
  MaintenanceTask task,
  String date,
  String effectiveDate,
) {
  if (!rollingTaskActive(task) || date.compareTo(effectiveDate) < 0) {
    return false;
  }
  final legacy = rollingSchedule(task).legacySchedule;
  if (legacy != null) {
    final stopped = Recurrence.decode(
      legacy['recurrenceJson'] as String,
    ).stoppedAfter;
    if (stopped != null && date.compareTo(stopped) >= 0) return false;
  }
  if (task.isOneOff) return date == effectiveDate;
  final rule = Recurrence(start: effectiveDate, completedBefore: effectiveDate);
  return rule.occurs(task, _date(date));
}

MaintenanceTask _select(
  List<MaintenanceTask> tasks,
  String id,
  int? revision, {
  bool active = true,
}) {
  final task = tasks.where((e) => e.id == id).firstOrNull;
  if (task == null ||
      (active && !rollingTaskActive(task)) ||
      (revision != null && rollingSchedule(task).revision != revision)) {
    throw StateError('该任务已更新，请重新打开');
  }
  return task;
}

List<MaintenanceTask> _members(
  List<MaintenanceTask> tasks,
  MaintenanceTask selected,
) {
  final key = rollingChemicalKey(selected);
  final result =
      key == null
            ? [selected]
            : tasks
                  .where(
                    (task) =>
                        rollingChemicalKey(task) == key &&
                        rollingTaskActive(task),
                  )
                  .toList()
        ..sort(_compare);
  if (result.isEmpty || result.first.id != selected.id) {
    throw StateError('请先处理本计划较早的任务');
  }
  return result;
}

String? _previous(
  List<MaintenanceTask> tasks,
  MaintenanceTask selected, {
  bool excludingLatest = false,
}) {
  final key = rollingChemicalKey(selected);
  String? latest;
  for (final task in tasks.where(
    (t) => key == null ? t.id == selected.id : rollingChemicalKey(t) == key,
  )) {
    final schedule = rollingSchedule(task);
    final entries = excludingLatest && task.id == selected.id
        ? schedule.completed.take(schedule.completed.length - 1)
        : schedule.completed;
    for (final date in [
      ...entries.map((e) => e.completedDate),
      ...schedule.legacyCompletedDates.where(
        (d) => !schedule.reopenedDates.contains(d),
      ),
    ]) {
      if (latest == null || date.compareTo(latest) > 0) latest = date;
    }
    final legacy = schedule.legacySchedule;
    if (legacy != null) {
      for (final entry in Recurrence.decode(
        legacy['recurrenceJson'] as String,
      ).states.entries) {
        if (entry.value == 'completed' &&
            !schedule.reopenedDates.contains(entry.key) &&
            (latest == null || entry.key.compareTo(latest) > 0)) {
          latest = entry.key;
        }
      }
    }
  }
  return latest;
}

void _validateCompletion(
  List<MaintenanceTask> tasks,
  MaintenanceTask task,
  String actual,
  DateTime now, {
  bool excludingLatest = false,
}) {
  _date(actual);
  if (actual.compareTo(dateKey(now)) > 0) throw StateError('完成日期不能晚于今天');
  final key = rollingChemicalKey(task);
  final origins =
      tasks
          .where(
            (t) => key == null ? t.id == task.id : rollingChemicalKey(t) == key,
          )
          .map((t) => rollingSchedule(t).startDate)
          .toList()
        ..sort();
  if (actual.compareTo(origins.first) < 0) throw StateError('完成日期不能早于计划开始日期');
  final previous = _previous(tasks, task, excludingLatest: excludingLatest);
  if (previous != null && actual.compareTo(previous) <= 0) {
    throw StateError('完成日期必须晚于上一次实际完成日期');
  }
}

MaintenanceTask _changed(
  MaintenanceTask task,
  RollingSchedule schedule,
  DateTime now, {
  String? status,
}) => task.copyWith(
  rollingJson: Value(schedule.encode()),
  status: status ?? task.status,
  updatedAt: now.toUtc(),
);

List<MaintenanceTask> delayRollingTasks(
  List<MaintenanceTask> tasks,
  String id,
  int days,
  DateTime now, {
  int? expectedRevision,
}) {
  if (days <= 0) throw ArgumentError('延迟天数必须是大于0的整数');
  final task = _select(tasks, id, expectedRevision),
      members = _members(
        tasks,
        _select(tasks, id, expectedRevision),
      ).map((e) => e.id).toSet();
  final next = addRollingDays(projectRollingDates(tasks, now)[id]!, days);
  final shift = calendarDayDifference(next, rollingSchedule(task).nextDate);
  return [
    for (final item in tasks)
      if (members.contains(item.id))
        _changed(
          item,
          rollingSchedule(item).copyWith(
            nextDate: addRollingDays(rollingSchedule(item).nextDate, shift),
            revision: rollingSchedule(item).revision + 1,
          ),
          now,
        )
      else
        item,
  ];
}

List<MaintenanceTask> completeRollingTasks(
  List<MaintenanceTask> tasks,
  String id,
  String actual,
  DateTime now, {
  int? expectedRevision,
}) {
  final task = _select(tasks, id, expectedRevision),
      schedule = rollingSchedule(task);
  final affected = _members(tasks, task).map((e) => e.id).toSet();
  _validateCompletion(tasks, task, actual, now);
  final due = projectRollingDates(tasks, now)[id]!;
  final shift = calendarDayDifference(actual, schedule.nextDate);
  return [
    for (final item in tasks)
      if (item.id == id)
        _changed(
          item,
          schedule.copyWith(
            completed: [...schedule.completed, RollingCompletion(due, actual)],
            nextDate: task.isOneOff
                ? schedule.nextDate
                : nextRollingDate(task, actual),
            revision: schedule.revision + 1,
          ),
          now,
          status: task.isOneOff ? 'completed' : 'enabled',
        )
      else if (affected.contains(item.id))
        _changed(
          item,
          rollingSchedule(item).copyWith(
            nextDate: addRollingDays(rollingSchedule(item).nextDate, shift),
            revision: rollingSchedule(item).revision + 1,
          ),
          now,
        )
      else
        item,
  ];
}

RollingCompletion _latest(
  List<MaintenanceTask> tasks,
  MaintenanceTask task,
  String date,
) {
  final latest = rollingSchedule(task).completed.lastOrNull;
  if (latest == null ||
      latest.completedDate != date ||
      _previous(tasks, task) != date) {
    throw StateError('只能修改最近一次实际完成记录');
  }
  return latest;
}

List<MaintenanceTask> correctRollingTasks(
  List<MaintenanceTask> tasks,
  String id,
  String date,
  String actual,
  DateTime now, {
  int? expectedRevision,
}) {
  final task = _select(tasks, id, expectedRevision, active: false),
      schedule = rollingSchedule(task);
  final latest = _latest(tasks, task, date);
  _validateCompletion(tasks, task, actual, now, excludingLatest: true);
  final shift = calendarDayDifference(actual, date),
      key = rollingChemicalKey(task);
  return [
    for (final item in tasks)
      if (item.id == id)
        _changed(
          item,
          schedule.copyWith(
            completed: [
              ...schedule.completed.take(schedule.completed.length - 1),
              RollingCompletion(latest.dueDate, actual),
            ],
            nextDate: task.isOneOff
                ? schedule.nextDate
                : nextRollingDate(task, actual),
            revision: schedule.revision + 1,
          ),
          now,
        )
      else if (key != null &&
          rollingChemicalKey(item) == key &&
          rollingTaskActive(item))
        _changed(
          item,
          rollingSchedule(item).copyWith(
            nextDate: addRollingDays(rollingSchedule(item).nextDate, shift),
            revision: rollingSchedule(item).revision + 1,
          ),
          now,
        )
      else
        item,
  ];
}

List<MaintenanceTask> reopenRollingTasks(
  List<MaintenanceTask> tasks,
  String id,
  String date,
  DateTime now, {
  int? expectedRevision,
}) {
  final task = _select(tasks, id, expectedRevision, active: false),
      schedule = rollingSchedule(task);
  final latest = schedule.completed.lastOrNull;
  final next = latest != null ? _latest(tasks, task, date).dueDate : date;
  if (latest == null &&
      (rollingHistoryState(task, date) != 'completed' ||
          (_previous(tasks, task) ?? '').compareTo(date) > 0)) {
    throw StateError('只能重开最近可修改的完成记录');
  }
  final key = rollingChemicalKey(task);
  return [
    for (final item in tasks)
      if (item.id == id)
        _changed(
          item,
          schedule.copyWith(
            nextDate: next,
            completed: latest == null
                ? schedule.completed
                : schedule.completed
                      .take(schedule.completed.length - 1)
                      .toList(),
            reopenedDates: latest == null
                ? {...schedule.reopenedDates, date}.toList()
                : schedule.reopenedDates,
            revision: schedule.revision + 1,
          ),
          now,
          status: 'enabled',
        )
      else if (key != null &&
          rollingChemicalKey(item) == key &&
          rollingTaskActive(item))
        _changed(
          item,
          rollingSchedule(item).copyWith(
            nextDate: addRollingDays(
              next,
              calendarDayDifference(
                rollingSchedule(item).startDate,
                schedule.startDate,
              ),
            ),
            revision: rollingSchedule(item).revision + 1,
          ),
          now,
        )
      else
        item,
  ];
}

List<MaintenanceTask> stopRollingTasks(
  List<MaintenanceTask> tasks,
  String id,
  DateTime now, {
  int? expectedRevision,
}) {
  final task = _select(tasks, id, expectedRevision);
  final ids = _members(tasks, task).map((e) => e.id).toSet();
  return [
    for (final item in tasks)
      if (ids.contains(item.id))
        _changed(
          item,
          rollingSchedule(
            item,
          ).copyWith(revision: rollingSchedule(item).revision + 1),
          now,
          status: 'skipped',
        )
      else
        item,
  ];
}

bool canEditRollingCompletion(
  List<MaintenanceTask> tasks,
  MaintenanceTask task,
  String date,
) {
  try {
    _latest(tasks, task, date);
    return true;
  } catch (_) {
    return false;
  }
}
