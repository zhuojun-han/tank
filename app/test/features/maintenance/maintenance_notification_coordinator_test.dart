import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/core/notifications/local_notification.dart';
import 'package:lanjiao_water_quality/core/notifications/local_notification_service.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_notification_coordinator.dart';
import 'package:lanjiao_water_quality/features/maintenance/data/maintenance_repository.dart';
import 'package:lanjiao_water_quality/features/maintenance/domain/recurrence.dart';
import 'package:lanjiao_water_quality/features/maintenance/domain/rolling_schedule.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_cycle_items.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_cycle.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_dosing.dart';
import 'package:lanjiao_water_quality/features/calculators/data/maintenance_cycle_repository.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';

void main() {
  test(
    'theory refill schedules only a bounded finite window and cancels it at course end',
    () async {
      final store = _FakeTaskStore(), service = _FakeNotificationService();
      var now = DateTime(2026, 9, 12, 8);
      final c = prepareMaintenanceCycle(
        input: const MaintenanceDosingInput(
          dailyChange: .1,
          volumeMl: 100,
          flow: 100,
          unit: PumpFlowUnit.mlPerMinute,
        ),
        chemical: DosingChemical.po4,
        tankId: 'tank',
        startDate: '2026-09-12',
        id: 'finite',
        theory: const MaintenanceTheory(
          planId: 'plan',
          source: 'lanthanum-plan',
          target: .05,
          planStartDate: '2026-09-12',
          endDate: '2026-11-12',
          lastDayRatio: .5,
        ),
      );
      final coordinator = MaintenanceNotificationCoordinator(
        taskStore: store,
        notificationService: service,
        nowUtc: () => now.toUtc(),
        nowDeviceLocal: () => now,
      );
      await coordinator.start();
      var ready = coordinator.states.firstWhere(
        (s) => s.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit(maintenanceCycleNotificationItems([c], now));
      await ready;
      expect(service.dailySchedules, isEmpty);
      expect(service.localOneShots.length, lessThanOrEqualTo(31));
      expect(service.localOneShots, isNotEmpty);
      expect(
        service.localOneShots.every(
          (e) => cycleDateKey(e.atDeviceLocal).compareTo('2026-11-12') <= 0,
        ),
        isTrue,
      );
      final finiteIds = service.localOneShots.map((e) => e.request.id).toSet();
      final base = store.persistedIds.single;
      final saved = MaintenanceCycle(
        id: c.id,
        tankId: c.tankId,
        chemical: c.chemical,
        input: c.input,
        startDate: c.startDate,
        refillDate: c.refillDate,
        solutionMl: c.solutionMl,
        dailyLiquidMl: c.dailyLiquidMl,
        effectPerMl: c.effectPerMl,
        retainedMl: c.retainedMl,
        addedStockMl: c.addedStockMl,
        addedWaterMl: c.addedWaterMl,
        theory: c.theory,
        notificationId: base,
      );
      now = DateTime(2026, 11, 13);
      service.cancelledIds.clear();
      ready = coordinator.states.firstWhere(
        (s) => s.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit(maintenanceCycleNotificationItems([saved], now));
      await ready;
      expect(service.cancelledIds, containsAll(finiteIds));
      expect(service.dailySchedules, isEmpty);
      final enough = prepareMaintenanceCycle(
        input: const MaintenanceDosingInput(
          dailyChange: .1,
          volumeMl: 300,
          flow: 100,
          unit: PumpFlowUnit.mlPerMinute,
        ),
        chemical: DosingChemical.po4,
        tankId: 'tank',
        startDate: '2026-11-13',
        id: 'enough',
        theory: const MaintenanceTheory(
          planId: 'enough',
          source: 'lanthanum-plan',
          target: .05,
          planStartDate: '2026-11-13',
          endDate: '2026-11-15',
          lastDayRatio: .5,
        ),
      );
      service.localOneShots.clear();
      service.oneShots.clear();
      ready = coordinator.states.firstWhere(
        (s) => s.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit(maintenanceCycleNotificationItems([enough], now));
      await ready;
      expect(service.oneShots, isEmpty);
      expect(service.localOneShots.single.request.title, contains('最后一天'));
      expect(
        cycleDateKey(service.localOneShots.single.atDeviceLocal),
        '2026-11-15',
      );
      expect(service.dailySchedules, isEmpty);
      await coordinator.dispose();
      await store.close();
    },
  );
  test(
    'persisted reminder-only snooze overrides a revised finite plan without changing dates',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lanjiao-snooze-',
      );
      final file = File('${directory.path}/data.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      addTearDown(() async {
        await db.close();
        await directory.delete(recursive: true);
      });
      final now = DateTime(2026, 9, 12, 6, 49, 56);
      final task = _item(dueAt: DateTime(2026, 9, 11, 9).toUtc()).task.copyWith(
        tankId: AppDatabase.defaultTankId,
        source: const Value('lanthanum-plan'),
        planId: const Value('finite-po4'),
        planDayIndex: const Value(2),
        isOneOff: true,
        rollingJson: Value(
          RollingSchedule(
            startDate: '2026-09-11',
            nextDate: '2026-09-11',
            revision: 2,
          ).encode(),
        ),
      );
      await db.into(db.maintenanceTasks).insert(task);
      for (final until in [
        now.add(const Duration(minutes: 1)).toUtc(),
        DateTime(2026, 9, 13, 2).toUtc(),
      ]) {
        await db
            .into(db.taskEvents)
            .insertOnConflictUpdate(
              TaskEvent(
                id: 'persisted-reminder',
                taskId: task.id,
                type: 'snoozed',
                occurredAt: now.toUtc(),
                snoozedUntil: until,
                note: 'webview-reminder-only',
              ),
            );
        await db.close();
        db = AppDatabase(NativeDatabase(file));
        final restored = (await MaintenanceRepository(
          db,
          now: () => now,
        ).watchAllTaskItems().first).single;
        final store = _FakeTaskStore();
        final notifications = _FakeNotificationService();
        var clock = now;
        final coordinator = MaintenanceNotificationCoordinator(
          taskStore: store,
          notificationService: notifications,
          nowUtc: () => clock.toUtc(),
          nowDeviceLocal: () => clock,
        );
        await coordinator.start();
        final ready = coordinator.states.firstWhere(
          (s) => s.phase == MaintenanceNotificationSyncPhase.ready,
        );
        store.emit([restored]);
        await ready;
        expect(notifications.oneShots.single.atUtc, until);
        expect(dateKey(restored.task.dueAt.toLocal()), '2026-09-12');
        if (until.toLocal().day == 13) {
          clock = DateTime(2026, 9, 13, 1);
          await coordinator.reconcileNow();
          expect(notifications.oneShots.last.atUtc, until);
        }
        await coordinator.dispose();
        await store.close();
        final stored = await db.select(db.maintenanceTasks).getSingle();
        expect(stored.dueAt.toUtc(), task.dueAt.toUtc());
        expect(stored.rollingJson, task.rollingJson);
      }
    },
  );

  test(
    'late inexact snooze survives resume but backdated completion cancels its old alarm',
    () async {
      final store = _FakeTaskStore();
      final notifications = _FakeNotificationService();
      var now = DateTime(2026, 9, 12, 9, 59);
      final coordinator = MaintenanceNotificationCoordinator(
        taskStore: store,
        notificationService: notifications,
        nowUtc: () => now.toUtc(),
        nowDeviceLocal: () => now,
      );
      addTearDown(coordinator.dispose);
      addTearDown(store.close);
      final id = stableMaintenanceNotificationId('task-1');
      final task = initializeRollingTask(
        _item(
          dueAt: DateTime(2026, 9, 11, 9).toUtc(),
          notificationId: id,
        ).task.copyWith(intervalAmount: 1, intervalUnit: 'day'),
      );
      final until = now.add(const Duration(minutes: 1)).toUtc();
      await coordinator.start();
      var ready = coordinator.states.firstWhere(
        (s) => s.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit([
        MaintenanceTaskItem(
          task: task,
          state: MaintenanceTaskViewState.overdue,
          latestEvent: TaskEvent(
            id: 'snoozed',
            taskId: task.id,
            type: 'snoozed',
            occurredAt: now.toUtc(),
            snoozedUntil: until,
            note: 'webview-reminder-only',
          ),
        ),
      ]);
      await ready;
      expect(notifications.oneShots.single.atUtc, until);
      notifications.cancelledIds.clear();
      now = until.toLocal().add(const Duration(seconds: 20));
      await coordinator.reconcileNow();
      expect(notifications.cancelledIds, isNot(contains(id)));
      expect(notifications.oneShots, hasLength(1));

      // Completing yesterday's occurrence leaves today's head overdue. It is
      // still a new schedule and must clear the previous snooze notification.
      final completed = completeRollingTasks(
        [task],
        task.id,
        '2026-09-11',
        now,
      ).single;
      notifications.cancelledIds.clear();
      ready = coordinator.states.firstWhere(
        (s) => s.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit([
        MaintenanceTaskItem(
          task: completed,
          state: MaintenanceTaskViewState.overdue,
        ),
      ]);
      await ready;
      expect(notifications.cancelledIds, contains(id));
    },
  );

  test(
    'ordinary saves retain unchanged alarms but forced refresh reapplies them',
    () async {
      final store = _FakeTaskStore();
      final notifications = _FakeNotificationService();
      final coordinator = _coordinator(store, notifications);
      addTearDown(coordinator.dispose);
      addTearDown(store.close);
      await coordinator.start();
      final ready = coordinator.states.firstWhere(
        (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit([
        _item(
          dueAt: DateTime.utc(2026, 8, 13),
          notificationId: stableMaintenanceNotificationId('task-1'),
        ),
      ]);
      await ready;
      notifications.cancelledIds.clear();
      await coordinator.reconcileNow(force: false);
      await coordinator.reconcileNow(force: false);
      expect(notifications.oneShots, hasLength(1));
      expect(notifications.dailySchedules, hasLength(1));
      expect(notifications.cancelledIds, isEmpty);
      await coordinator.reconcileNow();
      expect(notifications.oneShots, hasLength(2));
      expect(notifications.dailySchedules, hasLength(2));
      expect(notifications.cancelledIds, hasLength(2));
    },
  );

  test(
    'slow gateway coalesces rapid snapshots and keeps the final forced refresh',
    () async {
      final store = _FakeTaskStore(),
          notifications = _SlowNotificationService();
      final coordinator = _coordinator(store, notifications);
      await coordinator.start();
      final id = stableMaintenanceNotificationId('task-1');
      store.emit([_item(dueAt: DateTime.utc(2026, 8, 13), notificationId: id)]);
      await notifications.entered.future;
      for (var index = 0; index < 100; index++) {
        store.emit([
          _item(dueAt: DateTime.utc(2026, 8, 14 + index), notificationId: id),
        ]);
      }
      await Future<void>.delayed(Duration.zero);
      final settled = coordinator.reconcileNow();
      notifications.release.complete();
      await settled;
      expect(notifications.oneShots, hasLength(2));
      expect(notifications.dailySchedules, hasLength(2));
      expect(
        dateKey(notifications.oneShots.last.atUtc),
        dateKey(DateTime.utc(2026, 8, 113)),
      );
      await coordinator.dispose();
      await store.close();
    },
  );

  test(
    'uncompleted weekly head rolls tomorrow; only actual completion establishes the next week',
    () async {
      final store = _FakeTaskStore(),
          notifications = _FakeNotificationService();
      var now = DateTime(2026, 9, 5, 8);
      final coordinator = MaintenanceNotificationCoordinator(
        taskStore: store,
        notificationService: notifications,
        nowUtc: () => now.toUtc(),
        nowDeviceLocal: () => now,
      );
      addTearDown(coordinator.dispose);
      addTearDown(store.close);
      await coordinator.start();
      final task = initializeRollingTask(
        _item(dueAt: DateTime(2026, 9, 5, 9).toUtc()).task,
      );
      var ready = coordinator.states.firstWhere(
        (s) => s.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit([
        MaintenanceTaskItem(
          task: task,
          state: MaintenanceTaskViewState.upcoming,
        ),
      ]);
      await ready;
      expect(notifications.oneShots.map((s) => dateKey(s.atUtc)), [
        '2026-09-05',
      ]);
      expect(
        dateKey(notifications.dailySchedules.single.atDeviceLocal),
        '2026-09-06',
      );
      now = DateTime(2026, 9, 6, 8);
      await coordinator.reconcileNow();
      expect(dateKey(notifications.oneShots.last.atUtc), '2026-09-06');
      expect(
        dateKey(notifications.dailySchedules.last.atDeviceLocal),
        '2026-09-07',
      );
      final completed = completeRollingTasks(
        [task],
        task.id,
        '2026-09-06',
        now,
      ).single;
      ready = coordinator.states.firstWhere(
        (s) => s.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit([
        MaintenanceTaskItem(
          task: completed,
          state: MaintenanceTaskViewState.upcoming,
        ),
      ]);
      await ready;
      expect(dateKey(notifications.oneShots.last.atUtc), '2026-09-13');
      expect(rollingSchedule(task).completed, isEmpty);
    },
  );

  test(
    'a finite plan schedules only its unresolved head and advances after actual completion',
    () async {
      final store = _FakeTaskStore(),
          notifications = _FakeNotificationService(),
          now = DateTime(2026, 9, 8, 8);
      final coordinator = MaintenanceNotificationCoordinator(
        taskStore: store,
        notificationService: notifications,
        nowUtc: () => now.toUtc(),
        nowDeviceLocal: () => now,
      );
      addTearDown(coordinator.dispose);
      addTearDown(store.close);
      await coordinator.start();
      final tasks = [
        for (var i = 0; i < 3; i++)
          initializeRollingTask(
            _item(dueAt: DateTime(2026, 9, 5 + i, 9).toUtc()).task.copyWith(
              id: 'chemical-$i',
              source: const Value('alkalinity-plan'),
              planId: const Value('same'),
              planDayIndex: Value(i + 1),
              isOneOff: true,
            ),
          ),
      ];
      var ready = coordinator.states.firstWhere(
        (s) => s.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit([
        for (final task in tasks)
          MaintenanceTaskItem(
            task: task,
            state: MaintenanceTaskViewState.upcoming,
          ),
      ]);
      await ready;
      expect(notifications.oneShots, hasLength(1));
      expect(notifications.dailySchedules, hasLength(1));
      final after = completeRollingTasks(
        tasks,
        'chemical-0',
        '2026-09-08',
        now,
      );
      notifications.oneShots.clear();
      notifications.dailySchedules.clear();
      ready = coordinator.states.firstWhere(
        (s) => s.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit([
        for (final task in after)
          MaintenanceTaskItem(
            task: task,
            state: MaintenanceTaskViewState.upcoming,
          ),
      ]);
      await ready;
      expect(notifications.oneShots, hasLength(1));
      expect(dateKey(notifications.oneShots.single.atUtc), '2026-09-09');
    },
  );

  test(
    'refill deferral replaces its reminder and closure cancels the previous cycle',
    () async {
      final store = _FakeTaskStore(),
          notifications = _FakeNotificationService(),
          now = DateTime(2026, 9, 1, 8);
      final coordinator = MaintenanceNotificationCoordinator(
        taskStore: store,
        notificationService: notifications,
        nowUtc: () => now.toUtc(),
        nowDeviceLocal: () => now,
      );
      addTearDown(coordinator.dispose);
      addTearDown(store.close);
      await coordinator.start();
      final cycle = prepareMaintenanceCycle(
        input: const MaintenanceDosingInput(dailyChange: .1),
        chemical: DosingChemical.po4,
        tankId: 'tank-1',
        startDate: '2026-09-01',
        id: 'reservoir',
      );
      var ready = coordinator.states.firstWhere(
        (s) => s.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit(maintenanceCycleNotificationItems([cycle], now));
      await ready;
      expect(notifications.oneShots, hasLength(1));
      expect(dateKey(notifications.oneShots.last.atUtc), '2026-09-06');
      ready = coordinator.states.firstWhere(
        (s) => s.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit(
        maintenanceCycleNotificationItems([
          cycle.copyWith(refillDeferredUntil: '2026-09-09'),
        ], now),
      );
      await ready;
      expect(dateKey(notifications.oneShots.last.atUtc), '2026-09-09');
      final id = store.persistedIds.first;
      notifications.cancelledIds.clear();
      ready = coordinator.states.firstWhere(
        (s) => s.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit(
        maintenanceCycleNotificationItems([
          cycle.copyWith(closedOnDate: '2026-09-03'),
        ], now),
      );
      await ready;
      expect(
        notifications.cancelledIds,
        containsAll([id, maintenanceDailyNotificationId(id)]),
      );
    },
  );

  test(
    'archived tanks disable both ordinary and refill reminders while retaining stored cycles',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.now(),
          repo = MaintenanceRepository(db),
          cycles = MaintenanceCycleRepository(db);
      const tank = AppDatabase.defaultTankId;
      await TankRepository(db).createTank(name: '保留缸');
      final taskId = await repo.createTask(
        tankId: tank,
        title: '任务',
        intervalAmount: 1,
        intervalUnit: MaintenanceIntervalUnit.day,
        dueAt: now,
      );
      await cycles.confirm(
        prepareMaintenanceCycle(
          input: const MaintenanceDosingInput(dailyChange: .1),
          chemical: DosingChemical.po4,
          tankId: tank,
          startDate: dateKey(now),
          id: 'reservoir',
        ),
      );
      const taskAlarm = 0x10800001, refillAlarm = 0x10800002;
      await repo.setNotificationId(
        tankId: tank,
        taskId: taskId,
        notificationId: taskAlarm,
      );
      await cycles.setNotificationId('reservoir', refillAlarm);
      final store = RepositoryMaintenanceNotificationTaskStore(
        repo,
        cycles: cycles,
      );
      expect(
        (await store.watchAllTaskItems().first).every(
          (i) => i.task.status == 'enabled',
        ),
        isTrue,
      );
      await TankRepository(db).archiveTank(tank);
      final after = await store.watchAllTaskItems().first;
      expect(after, hasLength(2));
      expect(after.every((i) => i.task.status == 'disabled'), isTrue);
      expect((await cycles.getCycles()).single.closedOnDate, isNull);
      final notifications = _FakeNotificationService();
      final coordinator = MaintenanceNotificationCoordinator(
        taskStore: store,
        notificationService: notifications,
      );
      addTearDown(coordinator.dispose);
      final settled = coordinator.states.firstWhere(
        (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
      );
      await coordinator.start();
      await settled;
      // Date projection must not reactivate an archived tank's refill cycle.
      expect(notifications.oneShots, isEmpty);
      expect(notifications.dailySchedules, isEmpty);
      expect(notifications.localOneShots, isEmpty);
      expect(
        notifications.cancelledIds,
        containsAll([
          taskAlarm,
          maintenanceDailyNotificationId(taskAlarm),
          refillAlarm,
          maintenanceDailyNotificationId(refillAlarm),
        ]),
      );
    },
  );

  test('只确认当前head并每日提醒，完成后再排下一次，停止取消', () async {
    final store = _FakeTaskStore();
    final notifications = _FakeNotificationService();
    final clock = DateTime(2026, 9, 5, 8);
    final coordinator = MaintenanceNotificationCoordinator(
      taskStore: store,
      notificationService: notifications,
      nowUtc: () => clock.toUtc(),
      nowDeviceLocal: () => clock,
    );
    addTearDown(coordinator.dispose);
    addTearDown(store.close);
    await coordinator.start();
    final rule = Recurrence(start: '2026-09-05', completedBefore: '2026-09-05');
    final base = _item(dueAt: DateTime(2026, 9, 5, 9).toUtc());
    MaintenanceTaskItem item() => MaintenanceTaskItem(
      task: base.task.copyWith(
        recurrenceJson: Value(rule.encode()),
        intervalUnit: 'day',
        intervalAmount: 2,
      ),
      state: MaintenanceTaskViewState.upcoming,
    );
    var ready = coordinator.states.firstWhere(
      (s) => s.phase == MaintenanceNotificationSyncPhase.ready,
    );
    store.emit([item()]);
    await ready;
    expect(notifications.dailySchedules, hasLength(1));
    expect(
      dateKey(notifications.dailySchedules.single.atDeviceLocal),
      '2026-09-06',
    );
    expect(notifications.oneShots.map((r) => dateKey(r.atUtc)), ['2026-09-05']);
    notifications.oneShots.clear();
    rule.states['2026-09-05'] = 'completed';
    ready = coordinator.states.firstWhere(
      (s) => s.phase == MaintenanceNotificationSyncPhase.ready,
    );
    store.emit([item()]);
    await ready;
    expect(notifications.oneShots.map((r) => dateKey(r.atUtc)), ['2026-09-07']);
    notifications.oneShots.clear();
    notifications.cancelledIds.clear();
    rule.stoppedAfter = '2026-09-05';
    ready = coordinator.states.firstWhere(
      (s) => s.phase == MaintenanceNotificationSyncPhase.ready,
    );
    store.emit([item()]);
    await ready;
    expect(notifications.oneShots, isEmpty);
    expect(notifications.cancelledIds, hasLength(2));
  });
  group('buildMaintenanceNotificationPlan', () {
    final nowUtc = DateTime.utc(2026, 8, 12, 2);

    test('plans exact snooze and preferred-time daily overdue reminders', () {
      final snoozedUntil = DateTime.utc(2026, 8, 13, 4, 30);
      final plan = buildMaintenanceNotificationPlan(
        _item(
          dueAt: DateTime.utc(2026, 8, 11),
          preferredReminderTime: '07:45',
          latestEvent: TaskEvent(
            id: 'event-1',
            taskId: 'task-1',
            type: TaskEventType.snoozed.name,
            occurredAt: nowUtc,
            snoozedUntil: snoozedUntil,
          ),
        ),
        nowUtc: nowUtc,
        nowDeviceLocal: DateTime(2026, 8, 12, 10),
        toDeviceLocal: _toUtcPlusEight,
      );

      expect(plan.dueReminderAtUtc, snoozedUntil);
      expect(
        plan.dailyReminderStartsAtDeviceLocal,
        DateTime(2026, 8, 14, 7, 45),
      );
    });

    test('expired snooze falls back to the original task due instant', () {
      final originalDue = DateTime.utc(2026, 8, 13, 4);
      final plan = buildMaintenanceNotificationPlan(
        _item(
          dueAt: originalDue,
          preferredReminderTime: '08:15',
          latestEvent: TaskEvent(
            id: 'event-1',
            taskId: 'task-1',
            type: TaskEventType.snoozed.name,
            occurredAt: DateTime.utc(2026, 8, 12),
            snoozedUntil: DateTime.utc(2026, 8, 12, 1),
          ),
        ),
        nowUtc: nowUtc,
        nowDeviceLocal: DateTime(2026, 8, 12, 10),
        toDeviceLocal: _toUtcPlusEight,
      );

      expect(plan.dueReminderAtUtc, originalDue);
      expect(
        plan.dailyReminderStartsAtDeviceLocal,
        DateTime(2026, 8, 14, 8, 15),
      );
    });

    test('overdue reminders use the next preferred device-local time', () {
      final beforePreferred = buildMaintenanceNotificationPlan(
        _item(dueAt: DateTime.utc(2026, 8, 11), preferredReminderTime: '08:45'),
        nowUtc: nowUtc,
        nowDeviceLocal: DateTime(2026, 8, 12, 8, 30),
      );
      final afterPreferred = buildMaintenanceNotificationPlan(
        _item(dueAt: DateTime.utc(2026, 8, 11), preferredReminderTime: '08:45'),
        nowUtc: nowUtc,
        nowDeviceLocal: DateTime(2026, 8, 12, 9, 30),
      );

      expect(beforePreferred.dueReminderAtUtc, isNull);
      expect(
        beforePreferred.dailyReminderStartsAtDeviceLocal,
        DateTime(2026, 8, 12, 8, 45),
      );
      expect(
        afterPreferred.dailyReminderStartsAtDeviceLocal,
        DateTime(2026, 8, 13, 8, 45),
      );
    });
  });

  test('stable due and daily IDs are deterministic and disjoint', () {
    final first = stableMaintenanceNotificationId('task-1');
    final daily = maintenanceDailyNotificationId(first);

    expect(stableMaintenanceNotificationId('task-1'), first);
    expect(first, inInclusiveRange(0x10000000, 0x1fffffff));
    expect(daily, inInclusiveRange(0x20000000, 0x2fffffff));
    expect(
      stableMaintenanceNotificationId('task-1', reservedIds: {first}),
      isNot(first),
    );
  });

  test(
    'persists a missing ID and schedules exact plus daily only once',
    () async {
      final store = _FakeTaskStore();
      final notifications = _FakeNotificationService();
      final coordinator = _coordinator(store, notifications);
      await coordinator.start();

      var ready = coordinator.states.firstWhere(
        (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit([
        _item(dueAt: DateTime.utc(2026, 8, 13), preferredReminderTime: '09:30'),
      ]);
      await ready;
      expect(store.persistedIds, hasLength(1));
      expect(notifications.oneShots, hasLength(1));
      expect(notifications.dailySchedules, hasLength(1));
      expect(
        notifications.dailySchedules.single.atDeviceLocal,
        DateTime(2026, 8, 14, 9, 30),
      );
      expect(
        notifications.dailySchedules.single.request.id,
        maintenanceDailyNotificationId(store.persistedIds.single),
      );

      notifications.cancelledIds.clear();
      final persistedId = store.persistedIds.single;
      ready = coordinator.states.firstWhere(
        (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit([
        _item(
          dueAt: DateTime.utc(2026, 8, 13),
          preferredReminderTime: '09:30',
          notificationId: persistedId,
        ),
      ]);
      await ready;
      expect(store.persistedIds, hasLength(1));
      expect(notifications.oneShots, hasLength(1));
      expect(notifications.dailySchedules, hasLength(1));
      expect(notifications.cancelledIds, isEmpty);

      await coordinator.dispose();
      await store.close();
    },
  );

  test('disabled and removed tasks cancel both notification IDs', () async {
    final store = _FakeTaskStore();
    final notifications = _FakeNotificationService();
    final coordinator = _coordinator(store, notifications);
    final notificationId = stableMaintenanceNotificationId('task-1');
    await coordinator.start();

    var ready = coordinator.states.firstWhere(
      (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
    );
    store.emit([
      _item(dueAt: DateTime.utc(2026, 8, 13), notificationId: notificationId),
    ]);
    await ready;
    notifications.cancelledIds.clear();

    ready = coordinator.states.firstWhere(
      (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
    );
    store.emit([
      _item(
        dueAt: DateTime.utc(2026, 8, 13),
        notificationId: notificationId,
        status: MaintenanceTaskStatus.disabled.name,
      ),
    ]);
    await ready;
    expect(
      notifications.cancelledIds,
      containsAll([
        notificationId,
        maintenanceDailyNotificationId(notificationId),
      ]),
    );

    notifications.cancelledIds.clear();
    ready = coordinator.states.firstWhere(
      (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
    );
    store.emit(const []);
    await ready;
    expect(
      notifications.cancelledIds,
      containsAll([
        notificationId,
        maintenanceDailyNotificationId(notificationId),
      ]),
    );

    await coordinator.dispose();
    await store.close();
  });

  test(
    'notification preference cancels schedules and can enable them again',
    () async {
      final store = _FakeTaskStore();
      final notifications = _FakeNotificationService();
      final enabled = StreamController<bool>.broadcast();
      final coordinator = MaintenanceNotificationCoordinator(
        taskStore: store,
        notificationService: notifications,
        notificationsEnabled: enabled.stream,
        nowUtc: () => DateTime.utc(2026, 8, 12, 2),
        nowDeviceLocal: () => DateTime(2026, 8, 12, 10),
        toDeviceLocal: _toUtcPlusEight,
      );
      final notificationId = stableMaintenanceNotificationId('task-1');
      await coordinator.start();

      var ready = coordinator.states.firstWhere(
        (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit([
        _item(dueAt: DateTime.utc(2026, 8, 13), notificationId: notificationId),
      ]);
      await ready;
      expect(notifications.oneShots, isEmpty);
      expect(notifications.dailySchedules, isEmpty);
      expect(
        notifications.cancelledIds,
        containsAll([
          notificationId,
          maintenanceDailyNotificationId(notificationId),
        ]),
      );

      notifications.cancelledIds.clear();
      ready = coordinator.states.firstWhere(
        (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
      );
      enabled.add(true);
      await ready;
      expect(notifications.oneShots, hasLength(1));
      expect(notifications.dailySchedules, hasLength(1));

      ready = coordinator.states.firstWhere(
        (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
      );
      enabled.add(false);
      await ready;
      expect(
        notifications.cancelledIds,
        containsAll([
          notificationId,
          maintenanceDailyNotificationId(notificationId),
        ]),
      );

      notifications.cancelledIds.clear();
      await coordinator.reconcileNow(force: false);
      expect(notifications.cancelledIds, isEmpty);
      ready = coordinator.states.firstWhere(
        (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit(const []);
      await ready;
      expect(
        notifications.cancelledIds,
        containsAll([
          notificationId,
          maintenanceDailyNotificationId(notificationId),
        ]),
      );

      await coordinator.dispose();
      await enabled.close();
      await store.close();
    },
  );

  test(
    'cycle advance cancels both old IDs before applying the next plan',
    () async {
      final store = _FakeTaskStore();
      final notifications = _FakeNotificationService();
      final coordinator = _coordinator(store, notifications);
      final notificationId = stableMaintenanceNotificationId('task-1');
      await coordinator.start();

      var ready = coordinator.states.firstWhere(
        (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit([
        _item(dueAt: DateTime.utc(2026, 8, 13), notificationId: notificationId),
      ]);
      await ready;
      notifications.cancelledIds.clear();

      ready = coordinator.states.firstWhere(
        (state) => state.phase == MaintenanceNotificationSyncPhase.ready,
      );
      store.emit([
        _item(dueAt: DateTime.utc(2026, 8, 20), notificationId: notificationId),
      ]);
      await ready;

      expect(
        notifications.cancelledIds,
        containsAll([
          notificationId,
          maintenanceDailyNotificationId(notificationId),
        ]),
      );
      expect(notifications.oneShots, hasLength(2));
      expect(notifications.dailySchedules, hasLength(2));

      await coordinator.dispose();
      await store.close();
    },
  );
}

MaintenanceNotificationCoordinator _coordinator(
  _FakeTaskStore store,
  _FakeNotificationService notifications,
) {
  return MaintenanceNotificationCoordinator(
    taskStore: store,
    notificationService: notifications,
    nowUtc: () => DateTime.utc(2026, 8, 12, 2),
    nowDeviceLocal: () => DateTime(2026, 8, 12, 10),
    toDeviceLocal: _toUtcPlusEight,
  );
}

DateTime _toUtcPlusEight(DateTime utc) => DateTime(
  utc.year,
  utc.month,
  utc.day,
  utc.hour + 8,
  utc.minute,
  utc.second,
  utc.millisecond,
  utc.microsecond,
);

MaintenanceTaskItem _item({
  required DateTime dueAt,
  TaskEvent? latestEvent,
  int? notificationId,
  String preferredReminderTime = '09:00',
  String status = 'enabled',
}) {
  return MaintenanceTaskItem(
    task: MaintenanceTask(
      isOneOff: false,
      id: 'task-1',
      tankId: 'tank-1',
      title: '换水',
      intervalAmount: 1,
      intervalUnit: MaintenanceIntervalUnit.week.name,
      dueAt: dueAt,
      preferredReminderTime: preferredReminderTime,
      status: status,
      notificationId: notificationId,
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
    ),
    latestEvent: latestEvent,
    state: MaintenanceTaskViewState.upcoming,
  );
}

final class _FakeTaskStore implements MaintenanceNotificationTaskStore {
  final _controller = StreamController<List<MaintenanceTaskItem>>.broadcast();
  final persistedIds = <int>[];

  void emit(List<MaintenanceTaskItem> items) => _controller.add(items);

  Future<void> close() => _controller.close();

  @override
  Stream<List<MaintenanceTaskItem>> watchAllTaskItems() => _controller.stream;

  @override
  Future<void> persistNotificationId({
    required String tankId,
    required String taskId,
    required int notificationId,
  }) async {
    persistedIds.add(notificationId);
  }
}

final class _FakeNotificationService implements LocalNotificationService {
  final oneShots = <({LocalNotificationRequest request, DateTime atUtc})>[];
  final localOneShots =
      <({LocalNotificationRequest request, DateTime atDeviceLocal})>[];
  final dailySchedules =
      <({LocalNotificationRequest request, DateTime atDeviceLocal})>[];
  final cancelledIds = <int>[];

  @override
  Stream<LocalNotificationTap> get taps => const Stream.empty();

  @override
  Future<NotificationOperationResult> initialize() async =>
      const NotificationOperationResult.succeeded();

  @override
  Future<NotificationPermissionStatus> permissionStatus() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<NotificationPermissionStatus>
  requestExactSchedulingPermission() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<NotificationOperationResult> scheduleAtUtc(
    LocalNotificationRequest request,
    DateTime scheduledAtUtc,
  ) async {
    oneShots.add((request: request, atUtc: scheduledAtUtc));
    return const NotificationOperationResult.succeeded();
  }

  @override
  Future<NotificationOperationResult> scheduleAtDeviceLocalTime(
    LocalNotificationRequest request,
    DateTime deviceLocalDateTime,
  ) async {
    localOneShots.add((request: request, atDeviceLocal: deviceLocalDateTime));
    return const NotificationOperationResult.succeeded();
  }

  @override
  Future<NotificationOperationResult> scheduleDailyAtDeviceLocalTime(
    LocalNotificationRequest request,
    DateTime firstDeviceLocalDateTime,
  ) async {
    dailySchedules.add((
      request: request,
      atDeviceLocal: firstDeviceLocalDateTime,
    ));
    return const NotificationOperationResult.succeeded();
  }

  @override
  Future<NotificationOperationResult> cancel(int id) async {
    cancelledIds.add(id);
    return const NotificationOperationResult.succeeded();
  }
}

final class _SlowNotificationService extends _FakeNotificationService {
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<NotificationOperationResult> scheduleAtUtc(
    LocalNotificationRequest request,
    DateTime scheduledAtUtc,
  ) async {
    if (!entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return super.scheduleAtUtc(request, scheduledAtUtc);
  }
}
