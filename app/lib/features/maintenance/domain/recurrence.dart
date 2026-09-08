import 'dart:convert';

import '../../../data/database/app_database.dart';

String dateKey(DateTime value) {
  final d = value.toLocal();
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

DateTime localDate(DateTime value) {
  final d = value.toLocal();
  return DateTime(d.year, d.month, d.day);
}

/// Calendar dates, not elapsed 24-hour durations, keep DST from shifting rules.
int _ordinal(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

class Recurrence {
  Recurrence({
    required this.start,
    required this.completedBefore,
    Map<String, String>? states,
    Map<String, String>? snoozes,
    this.stoppedAfter,
  }) : states = states ?? {},
       snoozes = snoozes ?? {};

  final String start;
  final String completedBefore;
  final Map<String, String> states;
  final Map<String, String> snoozes;
  String? stoppedAfter;

  factory Recurrence.decode(String source) {
    final j = jsonDecode(source) as Map<String, dynamic>;
    final result = Recurrence(
      start: j['start'] as String,
      completedBefore: j['completedBefore'] as String,
      states: Map<String, String>.from(j['states'] as Map),
      snoozes: Map<String, String>.from(j['snoozes'] as Map),
      stoppedAfter: j['stoppedAfter'] as String?,
    );
    bool validDate(String s) =>
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s) &&
        dateKey(DateTime.parse(s)) == s;
    if (!validDate(result.start) ||
        !validDate(result.completedBefore) ||
        (result.stoppedAfter != null && !validDate(result.stoppedAfter!)) ||
        result.states.entries.any(
          (e) =>
              !validDate(e.key) ||
              !{'completed', 'skipped', 'pending'}.contains(e.value),
        ) ||
        result.snoozes.entries.any(
          (e) => !validDate(e.key) || DateTime.tryParse(e.value) == null,
        )) {
      throw const FormatException('周期任务日期或逐日状态无效');
    }
    return result;
  }

  String encode() => jsonEncode({
    'start': start,
    'completedBefore': completedBefore,
    'states': states,
    'snoozes': snoozes,
    'stoppedAfter': stoppedAfter,
  });

  bool occurs(MaintenanceTask task, DateTime date) {
    final key = dateKey(date);
    if (key.compareTo(start) < 0 ||
        (stoppedAfter != null && key.compareTo(stoppedAfter!) >= 0)) {
      return false;
    }
    final anchor = DateTime.parse(start);
    if (task.intervalUnit == 'month') {
      final months = (date.year - anchor.year) * 12 + date.month - anchor.month;
      final lastDay = DateTime(date.year, date.month + 1, 0).day;
      return months % task.intervalAmount == 0 &&
          date.day == (anchor.day > lastDay ? lastDay : anchor.day);
    }
    final interval =
        task.intervalAmount * (task.intervalUnit == 'week' ? 7 : 1);
    return (_ordinal(date) - _ordinal(anchor)) % interval == 0;
  }

  String stateOn(DateTime date) =>
      states[dateKey(date)] ??
      (dateKey(date).compareTo(completedBefore) < 0 ? 'completed' : 'pending');

  DateTime dueOn(MaintenanceTask task, DateTime date) {
    final parts = task.preferredReminderTime.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    ).toUtc();
  }

  DateTime nextDate(MaintenanceTask task, DateTime from) {
    final anchor = DateTime.parse(start);
    if (from.isBefore(anchor)) return anchor;
    if (task.intervalUnit != 'month') {
      final interval =
          task.intervalAmount * (task.intervalUnit == 'week' ? 7 : 1);
      final step = ((_ordinal(from) - _ordinal(anchor)) / interval).ceil();
      return DateTime(anchor.year, anchor.month, anchor.day + step * interval);
    }
    final months = (from.year - anchor.year) * 12 + from.month - anchor.month;
    var step = (months / task.intervalAmount).floor();
    DateTime candidate() {
      final month = DateTime(
        anchor.year,
        anchor.month + step * task.intervalAmount,
      );
      final last = DateTime(month.year, month.month + 1, 0).day;
      return DateTime(
        month.year,
        month.month,
        anchor.day > last ? last : anchor.day,
      );
    }

    if (candidate().isBefore(from)) step++;
    return candidate();
  }
}

bool validRecurrence(String? value) {
  if (value == null) return true;
  try {
    Recurrence.decode(value);
    return true;
  } catch (_) {
    return false;
  }
}
