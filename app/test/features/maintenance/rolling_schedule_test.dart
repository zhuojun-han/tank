import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/maintenance/domain/recurrence.dart';
import 'package:lanjiao_water_quality/features/maintenance/domain/rolling_schedule.dart';
import 'package:lanjiao_water_quality/features/maintenance/data/maintenance_repository.dart';

MaintenanceTask task(
  String id, {
  String date = '2026-09-01',
  bool chemical = false,
  int day = 1,
  String tank = 'one',
  String? plan,
}) => MaintenanceTask(
  id: id,
  tankId: tank,
  title: '任务 $id',
  notes: '原剂量 $id',
  intervalAmount: chemical ? 1 : 7,
  intervalUnit: 'day',
  dueAt: DateTime.parse(date).toUtc(),
  preferredReminderTime: '09:00',
  status: 'enabled',
  isOneOff: chemical,
  source: chemical ? 'alkalinity-plan' : null,
  planId: chemical ? plan ?? 'kh-plan' : null,
  planDayIndex: chemical ? day : null,
  createdAt: DateTime(2026).toUtc(),
  updatedAt: DateTime(2026).toUtc(),
  rollingJson: RollingSchedule(startDate: date, nextDate: date).encode(),
);

void main() {
  test(
    'calendar preserves real history when an edited head falls on the same date',
    () {
      final original = task('one').copyWith(
        rollingJson: Value(
          RollingSchedule(
            startDate: '2026-09-01',
            nextDate: '2026-09-08',
            revision: 2,
            completed: const [RollingCompletion('2026-09-01', '2026-09-08')],
          ).encode(),
        ),
      );
      final items = calendarOccurrences(
        [
          MaintenanceTaskItem(
            task: original,
            state: MaintenanceTaskViewState.upcoming,
          ),
        ],
        DateTime(2026, 9, 8),
        1,
        now: DateTime(2026, 9, 8, 12),
      );
      expect(items, hasLength(2));
      expect(
        items.map((item) => item.state),
        containsAll([
          MaintenanceTaskViewState.completed,
          MaintenanceTaskViewState.overdue,
        ]),
      );
      expect(rollingSchedule(original).completed, hasLength(1));
    },
  );

  test(
    'overdue recurrence rolls without inventing completion or persisting projection',
    () {
      final tasks = [task('one')], before = tasks.single.rollingJson;
      for (final today in [
        DateTime(2026, 9, 8),
        DateTime(2026, 9, 9),
        DateTime(2028, 2, 29),
      ]) {
        final date = projectRollingDates(tasks, today)['one']!;
        expect(date, dateKey(today));
        expect(rollingPendingOnDate(tasks.single, date, date), isTrue);
        expect(
          rollingPendingOnDate(tasks.single, addRollingDays(date, 7), date),
          isTrue,
        );
        expect(
          rollingHistoryState(tasks.single, addRollingDays(date, -1)),
          isNull,
        );
      }
      expect(tasks.single.rollingJson, before);
    },
  );

  test(
    'delay, actual completion, latest correction and undo preserve history and reject stale drafts',
    () {
      final original = [task('one')], now = DateTime(2026, 9, 10);
      var tasks = delayRollingTasks(
        original,
        'one',
        2,
        now,
        expectedRevision: 0,
      );
      expect(rollingSchedule(tasks.single).nextDate, '2026-09-12');
      expect(
        () => completeRollingTasks(
          tasks,
          'one',
          '2026-09-09',
          now,
          expectedRevision: 0,
        ),
        throwsStateError,
      );
      tasks = completeRollingTasks(
        tasks,
        'one',
        '2026-09-09',
        now,
        expectedRevision: 1,
      );
      expect(rollingSchedule(tasks.single).nextDate, '2026-09-16');
      expect(rollingSchedule(tasks.single).completed.single.toJson(), {
        'dueDate': '2026-09-12',
        'completedDate': '2026-09-09',
      });
      tasks = correctRollingTasks(
        tasks,
        'one',
        '2026-09-09',
        '2026-09-08',
        now,
      );
      expect(rollingSchedule(tasks.single).nextDate, '2026-09-15');
      tasks = reopenRollingTasks(tasks, 'one', '2026-09-08', now);
      expect(rollingSchedule(tasks.single).nextDate, '2026-09-12');
      expect(rollingSchedule(tasks.single).completed, isEmpty);
      expect(rollingSchedule(original.single).revision, 0);
      expect(
        () => completeRollingTasks(tasks, 'one', '2026-09-11', now),
        throwsStateError,
      );
      expect(
        () => delayRollingTasks(tasks, 'one', 0, now),
        throwsArgumentError,
      );
      expect(
        () => delayRollingTasks(tasks, 'one', 999999999, now),
        throwsFormatException,
      );
    },
  );

  test(
    'chemical queues move remaining doses together, isolate groups and only reopen latest completion',
    () {
      final original = [
        task('a', chemical: true),
        task('b', chemical: true, date: '2026-09-02', day: 2),
        task('c', chemical: true, date: '2026-09-03', day: 3),
        task('other-tank', chemical: true, tank: 'two'),
        task('other-plan', chemical: true, plan: 'another'),
      ];
      final now = DateTime(2026, 9, 10),
          snapshot = original.map((t) => t.toJson()).toList();
      expect(projectRollingDates(original, now).values.take(3), [
        '2026-09-10',
        '2026-09-11',
        '2026-09-12',
      ]);
      expect(() => delayRollingTasks(original, 'b', 1, now), throwsStateError);
      var tasks = delayRollingTasks(original, 'a', 2, now);
      expect(tasks.take(3).map((t) => rollingSchedule(t).nextDate), [
        '2026-09-12',
        '2026-09-13',
        '2026-09-14',
      ]);
      tasks = completeRollingTasks(tasks, 'a', '2026-09-08', now);
      expect(tasks.first.status, 'completed');
      expect(tasks.skip(1).take(2).map((t) => rollingSchedule(t).nextDate), [
        '2026-09-09',
        '2026-09-10',
      ]);
      tasks = completeRollingTasks(tasks, 'b', '2026-09-09', now);
      expect(
        () => reopenRollingTasks(tasks, 'a', '2026-09-08', now),
        throwsStateError,
      );
      tasks = correctRollingTasks(tasks, 'b', '2026-09-09', '2026-09-10', now);
      expect(rollingSchedule(tasks[2]).nextDate, '2026-09-11');
      tasks = reopenRollingTasks(tasks, 'b', '2026-09-10', now);
      expect(tasks[0].status, 'completed');
      expect(tasks.map((t) => t.notes), original.map((t) => t.notes));
      expect(
        tasks.skip(3).map((t) => t.toJson()),
        original.skip(3).map((t) => t.toJson()),
      );
      expect(original.map((t) => t.toJson()), snapshot);
    },
  );

  test(
    'old fixed rules and explicit histories survive migration and later interval edits',
    () {
      final encoded = Recurrence(
        start: '1980-01-01',
        completedBefore: '2026-09-08',
        states: {'2026-09-01': 'completed', '2026-09-02': 'pending'},
      ).encode();
      final legacy = task('legacy').copyWith(
        rollingJson: const Value(null),
        recurrenceJson: Value(encoded),
        intervalAmount: 1,
      );
      final migrated = initializeRollingTask(legacy);
      expect(rollingSchedule(migrated).nextDate, '2026-09-02');
      expect(rollingHistoryState(migrated, '2000-02-29'), 'completed');
      expect(rollingHistoryState(migrated, '2026-09-02'), isNull);
      final edited = migrated.copyWith(intervalAmount: 7);
      expect(rollingHistoryState(edited, '2000-02-29'), 'completed');
      expect(edited.recurrenceJson, encoded);
      expect(legacy.rollingJson, isNull);
    },
  );

  test(
    'strict rolling decoding and civil date arithmetic reject damaged data',
    () {
      final base =
          jsonDecode(rollingSchedule(task('one')).encode())
              as Map<String, dynamic>;
      for (final patch in [
        {'version': 2},
        {'nextDate': '2026-02-30'},
        {'revision': -1},
        {'revision': 1.5},
        {
          'completed': [
            {'dueDate': '2026-09-09', 'completedDate': '2026-09-08'},
            {'dueDate': '2026-09-10', 'completedDate': '2026-09-08'},
          ],
        },
        {
          'legacySchedule': {
            'recurrenceJson': '{}',
            'intervalAmount': 1,
            'intervalUnit': 'day',
          },
        },
      ]) {
        expect(validRollingSchedule(jsonEncode({...base, ...patch})), isFalse);
      }
      expect(addRollingDays('2024-02-28', 1), '2024-02-29');
      expect(addRollingDays('2026-12-31', 1), '2027-01-01');
      expect(
        nextRollingDate(
          task('month').copyWith(intervalAmount: 1, intervalUnit: 'month'),
          '2024-01-31',
        ),
        '2024-02-29',
      );
      expect(() => addRollingDays('9999-12-31', 1), throwsFormatException);
    },
  );

  test(
    '5000 independent plans keep one projected date each without daily history growth',
    () {
      final tasks = [
        for (var i = 0; i < 5000; i++)
          task('$i', chemical: true, plan: 'plan-$i'),
      ];
      final dates = projectRollingDates(tasks, DateTime(2026, 9, 8));
      expect(dates.length, 5000);
      expect(dates.values.every((date) => date == '2026-09-08'), isTrue);
      expect(
        tasks.every((task) => rollingSchedule(task).completed.isEmpty),
        isTrue,
      );
    },
  );

  test(
    'repository writes actual history transactionally; reload, edit, correction and undo retain audit rows',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var now = DateTime(2026, 9, 10, 10);
      final repo = MaintenanceRepository(db, now: () => now.toUtc());
      const tank = AppDatabase.defaultTankId;
      final id = await repo.createTask(
        tankId: tank,
        title: '换滤棉',
        intervalAmount: 7,
        intervalUnit: MaintenanceIntervalUnit.day,
        dueAt: DateTime(2026, 9, 1),
        calendarRecurrence: true,
      );
      Future<MaintenanceTask> stored() =>
          db.select(db.maintenanceTasks).getSingle();
      Future<List<MaintenanceTaskItem>> items() =>
          repo.watchTaskItems(tank, MaintenanceTaskFilter.all).first;
      expect(
        calendarOccurrences(await items(), DateTime(2026, 9, 1), 9, now: now),
        isEmpty,
      );
      await repo.delayTask(
        tankId: tank,
        taskId: id,
        days: 2,
        expectedRevision: 0,
      );
      await repo.complete(
        tankId: tank,
        taskId: id,
        completedDate: DateTime(2026, 9, 9),
        expectedRevision: 1,
      );
      expect(rollingSchedule(await stored()).nextDate, '2026-09-16');
      await repo.correctCompletion(
        tankId: tank,
        taskId: id,
        completedDate: DateTime(2026, 9, 9),
        newDate: DateTime(2026, 9, 8),
        expectedRevision: 2,
      );
      expect(
        calendarOccurrences(await items(), DateTime(2026, 9, 9), 1, now: now),
        isEmpty,
      );
      final done = calendarOccurrences(
        await items(),
        DateTime(2026, 9, 8),
        1,
        now: now,
      ).single;
      expect(done.state, MaintenanceTaskViewState.completed);
      expect(done.canEditCompletion, isTrue);
      await repo.reopen(
        tankId: tank,
        taskId: id,
        occurrenceDate: DateTime(2026, 9, 8),
        expectedRevision: 3,
      );
      expect(rollingSchedule(await stored()).completed, isEmpty);
      expect(await db.select(db.taskEvents).get(), hasLength(1));
      final before = (await stored()).rollingJson;
      await expectLater(
        repo.complete(
          tankId: tank,
          taskId: id,
          completedDate: DateTime(2026, 9, 11),
        ),
        throwsStateError,
      );
      expect((await stored()).rollingJson, before);
      now = DateTime(2026, 9, 14);
      expect(
        calendarOccurrences(await items(), now, 1, now: now).single.task.id,
        id,
      );
      expect((await stored()).rollingJson, before);
    },
  );
}
