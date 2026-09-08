import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/data/backup/local_backup_service.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/alkalinity_calculator.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/lanthanum_calculator.dart';
import 'package:lanjiao_water_quality/features/maintenance/data/maintenance_repository.dart';
import 'package:lanjiao_water_quality/features/maintenance/domain/recurrence.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late MaintenanceRepository repo;
  late DateTime now;
  const tank = AppDatabase.defaultTankId;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 9, 5, 9);
    repo = MaintenanceRepository(db, now: () => now.toUtc());
  });
  tearDown(() => db.close());
  Future<List<MaintenanceTaskItem>> items() =>
      repo.watchTaskItems(tank, MaintenanceTaskFilter.all).first;
  Future<String> recurring() => repo.createTask(
    tankId: tank,
    title: '滤棉',
    intervalAmount: 2,
    intervalUnit: MaintenanceIntervalUnit.day,
    dueAt: DateTime(2026, 9, 1, 9),
    calendarRecurrence: true,
  );

  test('按开始日展开六周，过去默认完成，逐日恢复完成不影响未来', () async {
    final id = await recurring();
    var dates = calendarOccurrences(
      await items(),
      DateTime(2026, 9, 1),
      42,
      now: now,
    );
    expect(dates, hasLength(21));
    expect(dates[0].state, MaintenanceTaskViewState.completed);
    expect(dates[1].state, MaintenanceTaskViewState.completed);
    expect(dates[2].state, MaintenanceTaskViewState.overdue);
    await repo.reopen(
      tankId: tank,
      taskId: id,
      occurrenceDate: DateTime(2026, 9, 1),
    );
    await repo.complete(
      tankId: tank,
      taskId: id,
      occurrenceDate: DateTime(2026, 9, 5),
    );
    dates = calendarOccurrences(
      await items(),
      DateTime(2026, 9, 1),
      9,
      now: now,
    );
    expect(dates.first.state, MaintenanceTaskViewState.overdue);
    expect(dates[2].state, MaintenanceTaskViewState.completed);
    expect(dates[3].state, MaintenanceTaskViewState.upcoming);
    expect(await db.select(db.maintenanceTasks).get(), hasLength(1));
    final next = (await repo.watchAllTaskItems().first).single;
    expect(dateKey(next.task.dueAt), '2026-09-07');
  });

  test('一小时稍后在到期恢复，不影响其他日期，停止保留历史', () async {
    final id = await recurring();
    await repo.snooze(
      tankId: tank,
      taskId: id,
      occurrenceDate: now,
      until: now.add(const Duration(hours: 1)),
    );
    expect(
      calendarOccurrences(
        await items(),
        localDate(now),
        1,
        now: now,
      ).single.state,
      MaintenanceTaskViewState.snoozed,
    );
    now = now.add(const Duration(hours: 1));
    expect(
      calendarOccurrences(
        await items(),
        localDate(now),
        1,
        now: now,
      ).single.state,
      MaintenanceTaskViewState.overdue,
    );
    await repo.skip(
      tankId: tank,
      taskId: id,
      occurrenceDate: DateTime(2026, 9, 7),
    );
    expect(
      calendarOccurrences(await items(), DateTime(2026, 9, 7), 1, now: now),
      isEmpty,
    );
    await repo.stopRecurring(
      tankId: tank,
      taskId: id,
      from: DateTime(2026, 9, 9),
    );
    expect(
      calendarOccurrences(await items(), DateTime(2026, 9, 9), 42, now: now),
      isEmpty,
    );
    expect(
      calendarOccurrences(await items(), DateTime(2026, 9, 1), 1, now: now),
      hasLength(1),
    );
    expect(await db.select(db.taskEvents).get(), hasLength(2));
  });

  test('编辑同一规则保留逐日状态和 ID；备份 v9 往返及 v8 可读', () async {
    final id = await recurring();
    await repo.reopen(
      tankId: tank,
      taskId: id,
      occurrenceDate: DateTime(2026, 9, 1),
    );
    await repo.complete(tankId: tank, taskId: id, occurrenceDate: now);
    await repo.updateTask(
      tankId: tank,
      taskId: id,
      title: '新滤棉',
      intervalAmount: 2,
      intervalUnit: MaintenanceIntervalUnit.day,
      dueAt: DateTime(2026, 9, 1),
      preferredReminderTime: '11:30',
      calendarRecurrence: true,
    );
    final task = (await items()).single.task;
    expect(task.id, id);
    expect(
      Recurrence.decode(task.recurrenceJson!).states['2026-09-01'],
      'pending',
    );
    expect(
      Recurrence.decode(task.recurrenceJson!).states['2026-09-05'],
      'completed',
    );
    final source = await LocalBackupService(db).exportJson();
    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    await LocalBackupService(target).restoreReplace(source);
    expect(
      (await target.select(target.maintenanceTasks).getSingle()).recurrenceJson,
      task.recurrenceJson,
    );
    final json = jsonDecode(source) as Map<String, dynamic>;
    json['formatVersion'] = 8;
    (json['maintenanceTasks'] as List).single.remove('recurrenceJson');
    await LocalBackupService(target).restoreReplace(jsonEncode(json));
    expect(
      (await target.select(target.maintenanceTasks).getSingle()).recurrenceJson,
      isNull,
    );
    json['formatVersion'] = 9;
    (json['maintenanceTasks'] as List).single['recurrenceJson'] =
        '{"start":"bad"}';
    await expectLater(
      LocalBackupService(target).restoreReplace(jsonEncode(json)),
      throwsA(isA<FormatException>()),
    );
    expect((await target.select(target.maintenanceTasks).getSingle()).id, id);
  });

  test('同类覆盖只替换开始日以后，隔离其他药剂海缸并保留更早历史', () async {
    final kh = calculateAlkalinityPlan(currentDkh: 6.5, targetDkh: 8);
    final old = await repo.createAlkalinityPlanTasks(
      tankId: tank,
      plan: kh,
      startDate: DateTime(2026, 9, 4),
    );
    await repo.complete(tankId: tank, taskId: old.first);
    final other = await TankRepository(db).createTank(name: '隔离缸');
    await repo.createAlkalinityPlanTasks(tankId: other, plan: kh);
    final po4 = calculateLanthanumPlan(
      currentPo4MgL: 0.23,
      targetPo4MgL: 0.03,
      netWaterVolumeL: 200,
      maxDailyPo4DropMgL: 0.1,
    );
    await repo.createLanthanumPlanTasks(tankId: tank, plan: po4);
    await expectLater(
      repo.createAlkalinityPlanTasks(tankId: tank, plan: kh),
      throwsStateError,
    );
    expect(await db.select(db.maintenanceTasks).get(), hasLength(8));
    final fresh = await repo.createAlkalinityPlanTasks(
      tankId: tank,
      plan: kh,
      replaceExisting: true,
    );
    final all = await db.select(db.maintenanceTasks).get();
    expect(all, hasLength(9));
    expect(all.singleWhere((t) => t.id == old.first).status, 'completed');
    expect(all.any((t) => t.id == old[1]), false);
    expect(await db.select(db.taskEvents).get(), hasLength(1));
    await repo.skip(tankId: tank, taskId: fresh[1]);
    expect(
      (await items())
          .where((i) => fresh.skip(1).contains(i.task.id))
          .every((i) => i.task.status == 'skipped'),
      true,
    );
    await repo.complete(tankId: tank, taskId: fresh.first);
    now = now.add(const Duration(seconds: 1));
    await repo.reopen(tankId: tank, taskId: fresh.first);
    expect(
      (await items()).singleWhere((i) => i.task.id == fresh.first).state,
      isNot(MaintenanceTaskViewState.completed),
    );
    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    await LocalBackupService(
      target,
    ).restoreReplace(await LocalBackupService(db).exportJson());
    expect(await target.select(target.maintenanceTasks).get(), hasLength(9));
  });

  test('覆盖计划新写入失败时事务恢复全部旧任务', () async {
    final plan = calculateAlkalinityPlan(currentDkh: 6.5, targetDkh: 8);
    final old = await repo.createAlkalinityPlanTasks(tankId: tank, plan: plan);
    await repo.complete(tankId: tank, taskId: old.first);
    await db.customStatement(
      "CREATE TRIGGER reject_new_plan BEFORE INSERT ON maintenance_tasks BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
    );
    await expectLater(
      repo.createAlkalinityPlanTasks(
        tankId: tank,
        plan: plan,
        replaceExisting: true,
      ),
      throwsA(isA<Exception>()),
    );
    expect(
      (await db.select(db.maintenanceTasks).get()).map((t) => t.id).toSet(),
      old.toSet(),
    );
    expect(await db.select(db.taskEvents).get(), hasLength(1));
  });

  test('月末周期与闰年按日历展开，停止后不生成通知投影', () async {
    final id = await repo.createTask(
      tankId: tank,
      title: '月末',
      intervalAmount: 1,
      intervalUnit: MaintenanceIntervalUnit.month,
      dueAt: DateTime(2024, 1, 31),
      calendarRecurrence: true,
    );
    final task = (await items()).single.task;
    final rule = Recurrence.decode(task.recurrenceJson!);
    expect(rule.occurs(task, DateTime(2024, 2, 29)), true);
    expect(rule.nextDate(task, DateTime(2024, 2, 1)), DateTime(2024, 2, 29));
    await repo.stopRecurring(tankId: tank, taskId: id, from: now);
    expect(
      (await repo.watchAllTaskItems().first).single.task.status,
      'disabled',
    );
  });
}
