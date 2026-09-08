import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_clock.dart';
import 'package:lanjiao_water_quality/features/maintenance/data/maintenance_repository.dart';
import 'package:lanjiao_water_quality/features/maintenance/domain/recurrence.dart';

MaintenanceTaskItem item(
  DateTime now, {
  DateTime? snooze,
  String? recurrence,
}) => MaintenanceTaskItem(
  task: MaintenanceTask(
    id: 't',
    tankId: 'tank',
    title: 'task',
    intervalAmount: 1,
    intervalUnit: 'day',
    dueAt: now.subtract(const Duration(hours: 1)),
    preferredReminderTime: '09:00',
    status: 'enabled',
    isOneOff: false,
    recurrenceJson: recurrence,
    createdAt: now,
    updatedAt: now,
  ),
  state: MaintenanceTaskViewState.snoozed,
  latestEvent: snooze == null
      ? null
      : TaskEvent(
          id: 'e',
          taskId: 't',
          type: 'snoozed',
          occurredAt: now,
          snoozedUntil: snooze,
        ),
);

void main() {
  test(
    'refresh uses minute/day boundary and exact legacy/calendar snooze deadline',
    () {
      final now = DateTime(2026, 9, 8, 10, 0, 10);
      final deadline = now.add(const Duration(seconds: 7));
      expect(nextMaintenanceRefresh(now, []), DateTime(2026, 9, 8, 10, 1));
      expect(
        nextMaintenanceRefresh(now, [item(now, snooze: deadline)]),
        deadline,
      );
      final rule = Recurrence(
        start: dateKey(now),
        completedBefore: dateKey(now),
        snoozes: {dateKey(now): deadline.toUtc().toIso8601String()},
      );
      expect(
        nextMaintenanceRefresh(now, [item(now, recurrence: rule.encode())]),
        deadline.toUtc(),
      );
      expect(
        nextMaintenanceRefresh(deadline, [item(now, snooze: deadline)]),
        DateTime(2026, 9, 8, 10, 1),
      );
      expect(
        refreshMaintenanceItem(item(now, snooze: deadline), now).state,
        MaintenanceTaskViewState.snoozed,
      );
      expect(
        refreshMaintenanceItem(item(now, snooze: deadline), deadline).state,
        MaintenanceTaskViewState.overdue,
      );
      expect(
        nextMaintenanceRefresh(DateTime(2026, 9, 8, 23, 59, 59), []),
        DateTime(2026, 9, 9),
      );
    },
  );

  testWidgets(
    'no second ticks; pause cancels timer and resume immediately updates date',
    (tester) async {
      var now = DateTime(2026, 9, 8, 23, 59, 10);
      final clock = MaintenanceClock(now: () => now);
      final events = <DateTime>[];
      final subscription = clock.stream.listen(events.add);
      await tester.pump();
      expect(events, [now]);
      now = now.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      expect(events, hasLength(1));
      clock.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = DateTime(2026, 9, 9, 8);
      await tester.pump(const Duration(hours: 8));
      expect(events, hasLength(1));
      clock.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(events.last, now);
      clock.dispose();
      unawaited(subscription.cancel());
      await tester.pump();
    },
  );
}
