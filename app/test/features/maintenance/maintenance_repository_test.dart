import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/lanthanum_calculator.dart';
import 'package:lanjiao_water_quality/features/maintenance/data/maintenance_repository.dart';
import 'package:lanjiao_water_quality/features/maintenance/domain/rolling_schedule.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase database;
  late TankRepository tanks;
  late DateTime clock;
  late MaintenanceRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    tanks = TankRepository(database);
    clock = DateTime.utc(2026, 8, 12, 1);
    repository = MaintenanceRepository(database, now: () => clock);
  });

  tearDown(() => database.close());

  test('新增任务默认 09:00 且查询严格按海缸隔离', () async {
    final secondTankId = await tanks.createTank(name: '维护隔离缸');
    final firstId = await repository.createTask(
      tankId: AppDatabase.defaultTankId,
      title: '  换水  ',
      notes: '  每次记录水量  ',
      intervalAmount: 2,
      intervalUnit: MaintenanceIntervalUnit.week,
      dueAt: DateTime.utc(2026, 8, 15, 9),
    );
    await repository.createTask(
      tankId: secondTankId,
      title: '清洗滤棉',
      intervalAmount: 3,
      intervalUnit: MaintenanceIntervalUnit.day,
      dueAt: DateTime.utc(2026, 8, 13, 9),
      preferredReminderTime: '08:30',
    );

    final first = await repository
        .watchAllTasks(AppDatabase.defaultTankId)
        .first;
    final second = await repository.watchAllTasks(secondTankId).first;
    expect(first, hasLength(1));
    expect(first.single.id, firstId);
    expect(first.single.title, '换水');
    expect(first.single.notes, '每次记录水量');
    expect(first.single.preferredReminderTime, '09:00');
    expect(first.single.status, MaintenanceTaskStatus.enabled.name);
    expect(second.single.title, '清洗滤棉');
    expect(second.single.preferredReminderTime, '08:30');

    await expectLater(
      repository.updateTask(
        tankId: secondTankId,
        taskId: firstId,
        title: '越权修改',
        intervalAmount: 1,
        intervalUnit: MaintenanceIntervalUnit.day,
        dueAt: clock,
        preferredReminderTime: '09:00',
      ),
      throwsStateError,
    );
    expect(
      (await repository.watchAllTasks(AppDatabase.defaultTankId).first)
          .single
          .title,
      '换水',
    );
  });

  test('编辑、停用、重新启用和归档保留任务且限制后续操作', () async {
    final taskId = await repository.createTask(
      tankId: AppDatabase.defaultTankId,
      title: '更换活性炭',
      intervalAmount: 1,
      intervalUnit: MaintenanceIntervalUnit.month,
      dueAt: DateTime.utc(2026, 9, 1),
    );
    clock = DateTime.utc(2026, 8, 12, 2);
    await repository.updateTask(
      tankId: AppDatabase.defaultTankId,
      taskId: taskId,
      title: '更换 活性炭',
      notes: '',
      intervalAmount: 4,
      intervalUnit: MaintenanceIntervalUnit.week,
      dueAt: DateTime.utc(2026, 9, 9),
      preferredReminderTime: '10:15',
    );
    await repository.setEnabled(
      tankId: AppDatabase.defaultTankId,
      taskId: taskId,
      enabled: false,
    );

    var task = (await repository.watchAllTasks(AppDatabase.defaultTankId).first)
        .single;
    expect(task.title, '更换 活性炭');
    expect(task.notes, isNull);
    expect(task.intervalAmount, 4);
    expect(task.intervalUnit, MaintenanceIntervalUnit.week.name);
    expect(task.preferredReminderTime, '10:15');
    expect(task.status, MaintenanceTaskStatus.disabled.name);
    await expectLater(
      repository.complete(tankId: AppDatabase.defaultTankId, taskId: taskId),
      throwsStateError,
    );
    expect(await database.select(database.taskEvents).get(), isEmpty);

    await repository.setEnabled(
      tankId: AppDatabase.defaultTankId,
      taskId: taskId,
      enabled: true,
    );
    await repository.archiveTask(
      tankId: AppDatabase.defaultTankId,
      taskId: taskId,
    );
    task = (await repository.watchAllTasks(AppDatabase.defaultTankId).first)
        .single;
    expect(task.status, MaintenanceTaskStatus.archived.name);
    await expectLater(
      repository.setEnabled(
        tankId: AppDatabase.defaultTankId,
        taskId: taskId,
        enabled: true,
      ),
      throwsStateError,
    );
  });

  test('永久删除在同一事务中删除任务与事件且不能跨缸操作', () async {
    final secondTankId = await tanks.createTank(name: '删除隔离缸');
    final firstId = await repository.createTask(
      tankId: AppDatabase.defaultTankId,
      title: '待删除换水',
      intervalAmount: 1,
      intervalUnit: MaintenanceIntervalUnit.week,
      dueAt: clock,
    );
    final secondId = await repository.createTask(
      tankId: secondTankId,
      title: '应保留任务',
      intervalAmount: 1,
      intervalUnit: MaintenanceIntervalUnit.week,
      dueAt: clock,
    );
    await repository.complete(
      tankId: AppDatabase.defaultTankId,
      taskId: firstId,
    );
    await repository.snooze(
      tankId: secondTankId,
      taskId: secondId,
      until: clock.add(const Duration(hours: 1)),
    );

    await expectLater(
      repository.deleteTask(tankId: secondTankId, taskId: firstId),
      throwsStateError,
    );
    expect(
      await repository.watchAllTasks(AppDatabase.defaultTankId).first,
      hasLength(1),
    );
    expect(await database.select(database.taskEvents).get(), hasLength(2));

    await repository.archiveTask(
      tankId: AppDatabase.defaultTankId,
      taskId: firstId,
    );
    await repository.deleteTask(
      tankId: AppDatabase.defaultTankId,
      taskId: firstId,
    );

    expect(
      await repository.watchAllTasks(AppDatabase.defaultTankId).first,
      isEmpty,
    );
    final remainingTasks = await repository.watchAllTasks(secondTankId).first;
    expect(remainingTasks.single.id, secondId);
    final remainingEvents = await database.select(database.taskEvents).get();
    expect(remainingEvents, hasLength(1));
    expect(remainingEvents.single.taskId, secondId);
  });

  test('完成在事务中记录事件并从实际完成日计算日周月周期', () async {
    clock = DateTime.utc(2026, 1, 31, 14, 20);
    final taskIds = <String>[];
    for (final entry in [
      (amount: 1, unit: MaintenanceIntervalUnit.day),
      (amount: 2, unit: MaintenanceIntervalUnit.week),
      (amount: 1, unit: MaintenanceIntervalUnit.month),
    ]) {
      taskIds.add(
        await repository.createTask(
          tankId: AppDatabase.defaultTankId,
          title: '${entry.unit.name}-${entry.amount}',
          intervalAmount: entry.amount,
          intervalUnit: entry.unit,
          dueAt: clock,
        ),
      );
    }
    for (final taskId in taskIds) {
      await repository.complete(
        tankId: AppDatabase.defaultTankId,
        taskId: taskId,
      );
    }

    final stored = await repository
        .watchAllTasks(AppDatabase.defaultTankId)
        .first;
    expect(rollingSchedule(stored[0]).nextDate, '2026-02-01');
    expect(rollingSchedule(stored[1]).nextDate, '2026-02-14');
    expect(rollingSchedule(stored[2]).nextDate, '2026-02-28');
    final events = await repository
        .watchCompletedEvents(AppDatabase.defaultTankId)
        .first;
    expect(events, hasLength(3));
    expect(
      events.every((entry) => entry.event.occurredAt.toUtc() == clock),
      isTrue,
    );

    final completed = await repository
        .watchTaskItems(
          AppDatabase.defaultTankId,
          MaintenanceTaskFilter.completed,
          referenceTime: clock,
        )
        .first;
    expect(completed, hasLength(3));
    expect(
      completed.every(
        (item) => item.state == MaintenanceTaskViewState.completed,
      ),
      isTrue,
    );
    final pending = await repository
        .watchPendingTasks(AppDatabase.defaultTankId, referenceTime: clock)
        .first;
    expect(pending, isEmpty);
  });

  test('停止保留历史与原始日期；旧稍后提醒仍可读取', () async {
    final originalDue = DateTime.utc(2026, 8, 11, 1);
    final taskId = await repository.createTask(
      tankId: AppDatabase.defaultTankId,
      title: '更换吸磷材料',
      intervalAmount: 7,
      intervalUnit: MaintenanceIntervalUnit.day,
      dueAt: originalDue,
    );
    final snoozedUntil = clock.add(const Duration(hours: 1));
    await repository.snooze(
      tankId: AppDatabase.defaultTankId,
      taskId: taskId,
      until: snoozedUntil,
      note: '先处理其他维护',
    );

    var task = (await repository.watchAllTasks(AppDatabase.defaultTankId).first)
        .single;
    expect(task.dueAt.toUtc(), originalDue);
    var pending = await repository
        .watchPendingTasks(AppDatabase.defaultTankId, referenceTime: clock)
        .first;
    expect(pending.single.state, MaintenanceTaskViewState.snoozed);
    expect(pending.single.latestEvent?.snoozedUntil?.toUtc(), snoozedUntil);

    clock = DateTime.utc(2026, 8, 12, 3);
    await repository.skip(
      tankId: AppDatabase.defaultTankId,
      taskId: taskId,
      note: '本周期不需要',
    );
    task = (await repository.watchAllTasks(AppDatabase.defaultTankId).first)
        .single;
    expect(task.dueAt.toUtc(), originalDue);
    expect(task.status, 'skipped');
    final all = await repository
        .watchTaskItems(
          AppDatabase.defaultTankId,
          MaintenanceTaskFilter.all,
          referenceTime: clock,
        )
        .first;
    expect(all.single.state, MaintenanceTaskViewState.skipped);
    expect(
      await repository.watchCompletedEvents(AppDatabase.defaultTankId).first,
      isEmpty,
    );
    final handled = await repository
        .watchHandledEvents(AppDatabase.defaultTankId)
        .first;
    expect(handled, hasLength(1));
    expect(handled.single.event.type, TaskEventType.skipped.name);
    expect(await database.select(database.taskEvents).get(), hasLength(2));
  });

  test('到期边界恢复待处理，非法输入不写入数据', () async {
    final taskId = await repository.createTask(
      tankId: AppDatabase.defaultTankId,
      title: '检查设备',
      intervalAmount: 1,
      intervalUnit: MaintenanceIntervalUnit.day,
      dueAt: clock,
    );
    await repository.complete(
      tankId: AppDatabase.defaultTankId,
      taskId: taskId,
    );
    final nextDue = clock.add(const Duration(days: 1));
    final atBoundary = await repository
        .watchPendingTasks(AppDatabase.defaultTankId, referenceTime: nextDue)
        .first;
    expect(atBoundary.single.state, MaintenanceTaskViewState.overdue);

    await expectLater(
      repository.createTask(
        tankId: AppDatabase.defaultTankId,
        title: ' ',
        intervalAmount: 1,
        intervalUnit: MaintenanceIntervalUnit.day,
        dueAt: clock,
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.createTask(
        tankId: AppDatabase.defaultTankId,
        title: '非法时间',
        intervalAmount: 1,
        intervalUnit: MaintenanceIntervalUnit.day,
        dueAt: clock,
        preferredReminderTime: '24:00',
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.snooze(
        tankId: AppDatabase.defaultTankId,
        taskId: taskId,
        until: clock,
      ),
      throwsArgumentError,
    );
    expect(
      await repository.watchAllTasks(AppDatabase.defaultTankId).first,
      hasLength(1),
    );
  });

  test('氯化镧计划创建有限一次性任务并可停止当天及后续', () async {
    final plan = calculateLanthanumPlan(
      currentPo4MgL: 0.28,
      targetPo4MgL: 0.03,
      netWaterVolumeL: 200,
      maxDailyPo4DropMgL: 0.1,
    );
    final ids = await repository.createLanthanumPlanTasks(
      tankId: AppDatabase.defaultTankId,
      plan: plan,
      startDate: DateTime(2026, 8, 12),
    );
    expect(ids, hasLength(3));
    var tasks = await repository.watchAllTasks(AppDatabase.defaultTankId).first;
    expect(tasks.every((task) => task.isOneOff), isTrue);
    expect(tasks.every((task) => task.source == 'lanthanum-plan'), isTrue);
    expect(tasks.map((task) => task.planDayIndex), [1, 2, 3]);
    expect(tasks.first.notes, contains('达到 0.03 mg/L 或出现异常'));
    expect(tasks.first.notes, isNot(contains('达到 0.03 mg/L、达到 0.03 mg/L')));
    expect(
      tasks[1].dueAt.toLocal().difference(tasks[0].dueAt.toLocal()),
      const Duration(days: 1),
    );

    await expectLater(
      repository.createLanthanumPlanTasks(
        tankId: AppDatabase.defaultTankId,
        plan: plan,
      ),
      throwsStateError,
    );
    await repository.complete(
      tankId: AppDatabase.defaultTankId,
      taskId: ids.first,
    );
    await repository.skip(tankId: AppDatabase.defaultTankId, taskId: ids[1]);

    tasks = await repository.watchAllTasks(AppDatabase.defaultTankId).first;
    expect(tasks[0].status, MaintenanceTaskStatus.completed.name);
    expect(tasks[1].status, MaintenanceTaskStatus.skipped.name);
    expect(tasks[2].status, MaintenanceTaskStatus.skipped.name);
    final events = await database.select(database.taskEvents).get();
    expect(events, hasLength(3));
  });

  test('UTC 月周期按月末截断并保留时分秒', () {
    expect(
      calculateNextDueAt(
        DateTime.utc(2024, 1, 31, 9, 8, 7),
        1,
        MaintenanceIntervalUnit.month,
      ),
      DateTime.utc(2024, 2, 29, 9, 8, 7),
    );
    expect(
      calculateNextDueAt(
        DateTime.utc(2026, 12, 31, 9),
        2,
        MaintenanceIntervalUnit.month,
      ),
      DateTime.utc(2027, 2, 28, 9),
    );
  });
}
