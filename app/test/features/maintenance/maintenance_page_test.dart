import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanjiao_water_quality/app/theme.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_providers.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_notification_providers.dart';
import 'package:lanjiao_water_quality/features/maintenance/data/maintenance_repository.dart';
import 'package:lanjiao_water_quality/features/maintenance/presentation/maintenance_page.dart';
import 'package:lanjiao_water_quality/features/maintenance/domain/rolling_schedule.dart';
import 'package:lanjiao_water_quality/features/calculators/application/maintenance_cycle_providers.dart';
import 'package:lanjiao_water_quality/features/calculators/data/maintenance_cycle_repository.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_cycle.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_dosing.dart';
import 'package:lanjiao_water_quality/features/tanks/application/tank_providers.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late MaintenanceRepository repository;
  late DateTime clock;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    clock = DateTime.now().toUtc().subtract(const Duration(seconds: 1));
    repository = MaintenanceRepository(database, now: () => clock);
  });

  tearDown(() => database.close());

  testWidgets('补液通知切换正确海缸和药剂，已关闭周期不打开旧配方', (tester) async {
    _useTallTestSurface(tester);
    final tanks = TankRepository(database),
        cycles = MaintenanceCycleRepository(database);
    final otherId = await tanks.createTank(name: '另一个缸');
    final cycle = prepareMaintenanceCycle(
      input: const MaintenanceDosingInput(dailyChange: .1),
      chemical: DosingChemical.kh,
      tankId: otherId,
      startDate: cycleDateKey(clock),
      id: 'notify-cycle',
    );
    await cycles.confirm(cycle);
    await tanks.switchTank(AppDatabase.defaultTankId);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: MaintenancePage(initialTaskId: 'cycle-notify-cycle'),
          ),
        ),
        GoRoute(
          path: '/maintenance-dosing',
          builder: (_, state) => Scaffold(
            body: Text('药剂 ${state.uri.queryParameters['chemical']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    Widget page() => ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        notificationsEnabledProvider.overrideWithValue(false),
        maintenanceRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
    await tester.pumpWidget(page());
    await _pumpUntilFound(tester, find.text('药剂 kh'));
    expect(
      (await tester.runAsync(
        () => database.select(database.appPreferences).getSingle(),
      ))!.currentTankId,
      otherId,
    );
    await _disposePage(tester);
    await (database.update(
      database.maintenanceCycles,
    )..where((row) => row.id.equals(cycle.id))).write(
      MaintenanceCyclesCompanion(closedOnDate: Value(cycleDateKey(clock))),
    );
    await tanks.switchTank(AppDatabase.defaultTankId);
    router.go('/');
    await tester.pumpWidget(page());
    await _pumpUntilFound(tester, find.text('该补液周期已结束或不存在'));
    expect(find.text('药剂 kh'), findsNothing);
    expect(
      (await tester.runAsync(
        () => database.select(database.appPreferences).getSingle(),
      ))!.currentTankId,
      AppDatabase.defaultTankId,
    );
    await _disposePage(tester);
  });

  testWidgets('空态只展示当前海缸，并严格隔离其他海缸任务', (tester) async {
    _useTallTestSurface(tester);
    final now = clock;
    final defaultTank = _tank(
      id: AppDatabase.defaultTankId,
      name: '我的海缸',
      now: now,
    );

    await tester.pumpWidget(
      _testPage(repository: repository, tank: defaultTank),
    );
    await _pumpUntilFound(tester, find.text('当前没有待处理计划'));

    expect(find.text('任务日历'), findsOneWidget);
    expect(find.text('当天没有已安排的事项。'), findsOneWidget);

    final secondTankId = await TankRepository(database).createTank(name: '隔离缸');
    await repository.createTask(
      tankId: AppDatabase.defaultTankId,
      title: '主缸换水',
      intervalAmount: 1,
      intervalUnit: MaintenanceIntervalUnit.week,
      dueAt: now.add(const Duration(days: 1)),
    );
    await repository.createTask(
      tankId: secondTankId,
      title: '隔离缸清洗滤棉',
      intervalAmount: 3,
      intervalUnit: MaintenanceIntervalUnit.day,
      dueAt: now.add(const Duration(days: 1)),
    );

    await tester.pumpWidget(
      _testPage(
        repository: repository,
        tank: _tank(id: secondTankId, name: '隔离缸', now: now),
      ),
    );
    await _pumpUntilFound(tester, find.text('全部'));
    await tester.tap(find.text('全部'));
    await _pumpUntilFound(tester, find.text('隔离缸清洗滤棉'));

    expect(find.text('隔离缸清洗滤棉'), findsWidgets);
    expect(find.text('主缸换水'), findsNothing);
    await _disposePage(tester);
  });

  testWidgets('待处理展示全局计划，完成记录随所选日期切换，日历操作不重复', (tester) async {
    _useTallTestSurface(tester);
    final tank = _tank(id: AppDatabase.defaultTankId, name: '我的海缸', now: clock);
    final ruleId = await repository.createTask(
      tankId: tank.id,
      title: '周期换水',
      intervalAmount: 1,
      intervalUnit: MaintenanceIntervalUnit.week,
      dueAt: clock.add(const Duration(days: 1)),
      calendarRecurrence: true,
    );
    final completedId = await repository.createTask(
      tankId: tank.id,
      title: '今天已完成',
      intervalAmount: 1,
      intervalUnit: MaintenanceIntervalUnit.day,
      dueAt: clock,
      isOneOff: true,
    );
    await repository.complete(tankId: tank.id, taskId: completedId);
    await tester.pumpWidget(_testPage(repository: repository, tank: tank));
    await _pumpUntilFound(tester, find.byKey(Key('maintenance-task-$ruleId')));
    expect(find.byKey(Key('calendar-complete-$ruleId')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('maintenance-calendar'))).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const Key('maintenance-catalog-heading')))
            .dy,
      ),
    );
    expect(
      tester
          .getTopLeft(find.byKey(const Key('maintenance-catalog-heading')))
          .dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('maintenance-filter'))).dy,
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('maintenance-filter')),
        matching: find.text('已完成'),
      ),
    );
    final today = clock.toLocal();
    String keyFor(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    await _pumpUntilFound(
      tester,
      find.byKey(Key('maintenance-history-$completedId-${keyFor(today)}')),
    );
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    await tester.tap(
      find.byKey(Key('maintenance-calendar-day-${keyFor(tomorrow)}')),
    );
    await _pumpUntilFound(tester, find.text('所选日期没有记录'));
    expect(find.byKey(Key('calendar-complete-$ruleId')), findsOneWidget);
    expect(
      find.byKey(Key('maintenance-history-$completedId-${keyFor(today)}')),
      findsNothing,
    );
    await tester.tap(find.text('待处理'));
    await _pumpUntilFound(tester, find.byKey(Key('maintenance-task-$ruleId')));
    // The global card links to a task day; completing belongs to its occurrence.
    expect(find.text('完成本次'), findsOneWidget);
    await tester.tap(find.text('全部'));
    await _pumpUntilFound(tester, find.byKey(Key('maintenance-task-$ruleId')));
    expect(find.byKey(Key('maintenance-task-$ruleId')), findsOneWidget);
    await _disposePage(tester);
  });
  testWidgets('新增任务使用默认 09:00 提醒时间', (tester) async {
    _useTallTestSurface(tester);
    final tank = _tank(id: AppDatabase.defaultTankId, name: '我的海缸', now: clock);
    await tester.pumpWidget(_testPage(repository: repository, tank: tank));
    await _pumpUntilFound(tester, find.text('当前没有待处理计划'));

    await tester.tap(find.byKey(const Key('add-maintenance-task')));
    await _pumpUntilFound(tester, find.text('新增维护任务'));
    await tester.enterText(find.byKey(const Key('maintenance-title')), '检查蛋分');
    await tester.tap(find.text('保存'));
    await _pumpUntilFound(tester, find.text('维护任务已创建'));

    final tasks = await (database.select(
      database.maintenanceTasks,
    )..where((task) => task.tankId.equals(tank.id))).get();
    expect(tasks, hasLength(1));
    expect(tasks.single.title, '检查蛋分');
    expect(tasks.single.preferredReminderTime, '09:00');
    await _disposePage(tester);
  });

  testWidgets('日历当天的独立事项可直接完成', (tester) async {
    _useTallTestSurface(tester);
    final tank = _tank(id: AppDatabase.defaultTankId, name: '我的海缸', now: clock);
    final taskId = await repository.createTask(
      tankId: tank.id,
      title: '当天一次性事项',
      intervalAmount: 1,
      intervalUnit: MaintenanceIntervalUnit.day,
      dueAt: clock,
      isOneOff: true,
    );

    await tester.pumpWidget(_testPage(repository: repository, tank: tank));
    final complete = find.byKey(Key('calendar-complete-$taskId'));
    await _pumpUntilFound(tester, complete);
    await tester.tap(complete);
    await _pumpUntilFound(tester, find.text('实际完成日期'));
    await tester.tap(find.text('确认'));
    await _pumpUntilFound(tester, find.text('已完成，后续日期已更新'));

    final task = await (database.select(
      database.maintenanceTasks,
    )..where((row) => row.id.equals(taskId))).getSingle();
    expect(task.status, MaintenanceTaskStatus.completed.name);
    await _disposePage(tester);
  });

  testWidgets('任务详情支持实际完成、取消延迟及自定义延迟和停止', (tester) async {
    _useTallTestSurface(tester);
    final tank = _tank(id: AppDatabase.defaultTankId, name: '我的海缸', now: clock);
    final completeId = await _createTask(repository, tank.id, '完成任务', clock);
    final snoozeId = await _createTask(repository, tank.id, '稍后任务', clock);
    final skipId = await _createTask(repository, tank.id, '跳过任务', clock);

    await tester.pumpWidget(_testPage(repository: repository, tank: tank));
    await _pumpUntilFound(tester, find.text('全部'));
    await tester.tap(find.text('全部'));
    await _pumpUntilFound(tester, find.text('完成任务'));

    await tester.tap(find.byKey(Key('maintenance-task-$completeId')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('complete-maintenance-task')),
    );
    await tester.tap(find.byKey(const Key('complete-maintenance-task')));
    await _pumpUntilFound(tester, find.text('实际完成日期'));
    await tester.tap(find.text('确认'));
    await _pumpUntilFound(tester, find.text('已完成，后续日期已更新'));
    await tester.ensureVisible(find.byKey(Key('maintenance-task-$snoozeId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('maintenance-task-$snoozeId')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('snooze-maintenance-task')),
    );
    await tester.tap(find.byKey(const Key('snooze-maintenance-task')));
    await _pumpUntilFound(tester, find.text('延迟任务'));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    var delayed = await (database.select(
      database.maintenanceTasks,
    )..where((t) => t.id.equals(snoozeId))).getSingle();
    expect(rollingSchedule(delayed).revision, 0);
    await tester.ensureVisible(find.byKey(Key('maintenance-task-$snoozeId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('maintenance-task-$snoozeId')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('snooze-maintenance-task')),
    );
    await tester.tap(find.byKey(const Key('snooze-maintenance-task')));
    await _pumpUntilFound(tester, find.text('延迟任务'));
    await tester.enterText(find.byType(TextField).last, '2');
    await tester.tap(find.text('确认延迟'));
    await _pumpUntilFound(tester, find.text('已延迟 2 天'));
    delayed = await (database.select(
      database.maintenanceTasks,
    )..where((t) => t.id.equals(snoozeId))).getSingle();
    expect(rollingSchedule(delayed).revision, 1);

    await tester.ensureVisible(find.byKey(Key('maintenance-task-$skipId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('maintenance-task-$skipId')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('skip-maintenance-task')),
    );
    await tester.tap(find.byKey(const Key('skip-maintenance-task')));
    await _pumpUntilFound(tester, find.text('停止任务？'));
    await tester.tap(find.text('停止').last);
    await _pumpUntilFound(tester, find.text('已停止后续任务'));

    final events = await database.select(database.taskEvents).get();
    expect(
      events.where((event) => event.type == TaskEventType.completed.name),
      hasLength(1),
    );
    expect(events.where((event) => event.type == 'snoozed'), isEmpty);
    expect(
      events.where((event) => event.type == TaskEventType.skipped.name),
      hasLength(1),
    );
    await _disposePage(tester);
  });

  testWidgets('永久删除需要二次确认并一并移除历史事件', (tester) async {
    _useTallTestSurface(tester);
    final tank = _tank(id: AppDatabase.defaultTankId, name: '我的海缸', now: clock);
    final taskId = await _createTask(repository, tank.id, '待删除任务', clock);
    await repository.complete(tankId: tank.id, taskId: taskId);

    await tester.pumpWidget(_testPage(repository: repository, tank: tank));
    await _pumpUntilFound(tester, find.text('全部'));
    await tester.tap(find.text('全部'));
    await _pumpUntilFound(tester, find.text('待删除任务'));
    await tester.tap(find.byKey(Key('maintenance-task-menu-$taskId')));
    await _pumpUntilFound(tester, find.text('删除'));
    await tester.tap(find.text('删除'));
    await _pumpUntilFound(tester, find.text('永久删除任务？'));

    expect(find.textContaining('无法撤销'), findsOneWidget);
    expect(
      await (database.select(
        database.maintenanceTasks,
      )..where((task) => task.tankId.equals(tank.id))).get(),
      hasLength(1),
    );
    expect(await database.select(database.taskEvents).get(), hasLength(1));

    await tester.tap(find.text('取消'));
    await _pumpUntilFound(tester, find.byKey(Key('maintenance-task-$taskId')));
    await tester.tap(find.byKey(Key('maintenance-task-menu-$taskId')));
    await _pumpUntilFound(tester, find.text('删除'));
    await tester.tap(find.text('删除'));
    await _pumpUntilFound(tester, find.text('永久删除任务？'));
    await tester.tap(find.text('永久删除'));
    await _pumpUntilFound(tester, find.text('任务已永久删除'));
    await _pumpUntilAbsent(tester, find.byKey(Key('maintenance-task-$taskId')));

    expect(
      await (database.select(
        database.maintenanceTasks,
      )..where((task) => task.tankId.equals(tank.id))).get(),
      isEmpty,
    );
    expect(await database.select(database.taskEvents).get(), isEmpty);
    await _disposePage(tester);
  });
  testWidgets('未来补液日提前延期后立即进入全局待处理，原周期与当日状态保留', (tester) async {
    _useTallTestSurface(tester);
    final cycles = MaintenanceCycleRepository(database, now: () => clock);
    final cycle = prepareMaintenanceCycle(
      input: const MaintenanceDosingInput(dailyChange: .1),
      chemical: DosingChemical.kh,
      tankId: AppDatabase.defaultTankId,
      startDate: cycleDateKey(clock),
      id: 'future-refill',
    );
    await cycles.confirm(cycle);
    expect(cycle.refillDate.compareTo(cycleDateKey(clock)), greaterThan(0));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          notificationsEnabledProvider.overrideWithValue(false),
          maintenanceRepositoryProvider.overrideWithValue(repository),
          maintenanceCycleRepositoryProvider.overrideWithValue(cycles),
        ],
        child: MaterialApp(
          theme: LanjiaoTheme.light,
          home: const Scaffold(body: MaintenancePage()),
        ),
      ),
    );
    try {
      await _pumpUntilFound(tester, find.text('当前没有待处理计划'));
      const catalog = Key('maintenance-cycle-plan-cycle-future-refill');
      expect(find.byKey(catalog), findsNothing);
      await tester.tap(find.text('全部'));
      await _pumpUntilFound(tester, find.byKey(catalog));
      await tester.tap(find.text('待处理'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(Key('maintenance-calendar-day-${cycle.refillDate}')),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('calendar-complete-cycle-future-refill')),
      );
      await tester.tap(find.text('延迟'));
      await _pumpUntilFound(tester, find.text('延迟任务'));
      await tester.enterText(find.byType(TextField), '2');
      await tester.tap(find.text('确认延迟'));
      await _pumpUntilFound(tester, find.byKey(catalog));
      final deferred = cycleDateKey(
        DateTime.parse(cycle.refillDate).add(const Duration(days: 2)),
      );
      expect(
        find.descendant(
          of: find.byKey(catalog),
          matching: find.text('补液日期 $deferred'),
        ),
        findsOneWidget,
      );
      // The selected original refill day no longer has an outstanding occurrence.
      expect(
        find.byKey(const Key('calendar-complete-cycle-future-refill')),
        findsNothing,
      );
      final saved = (await cycles.getCycles(tankId: cycle.tankId)).single;
      expect(saved.refillDate, cycle.refillDate);
      expect(saved.refillDeferredUntil, deferred);
      expect(saved.dailyLiquidMl, cycle.dailyLiquidMl);
      expect(saved.solutionMl, cycle.solutionMl);
      expect(await database.select(database.maintenanceTasks).get(), isEmpty);
      expect(await database.select(database.taskEvents).get(), isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      await _disposePage(tester);
    }
  });

  testWidgets('窄屏大字体完整月历和长任务表单可滚动，取消不写入', (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final tank = _tank(id: AppDatabase.defaultTankId, name: '当前缸', now: clock);
    final taskId = await repository.createTask(
      tankId: tank.id,
      title: '清洗设备',
      intervalAmount: 1,
      intervalUnit: MaintenanceIntervalUnit.week,
      dueAt: clock,
      notes: List.filled(20, '这是较长的执行说明，完成后检查设备运行情况。').join('\n'),
    );
    await tester.pumpWidget(
      _testPage(repository: repository, tank: tank, textScale: 1.6),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('maintenance-calendar')),
    );
    expect(find.byKey(Key('calendar-complete-$taskId')), findsOneWidget);
    await tester.ensureVisible(find.byKey(Key('maintenance-task-$taskId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('maintenance-task-$taskId')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('complete-maintenance-task')),
    );
    await tester.ensureVisible(
      find.byKey(const Key('snooze-maintenance-task')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('snooze-maintenance-task')));
    await _pumpUntilFound(tester, find.text('延迟任务'));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    final task = await (database.select(
      database.maintenanceTasks,
    )..where((t) => t.id.equals(taskId))).getSingle();
    expect(rollingSchedule(task).revision, 0);
    // The header is lazily unmounted after scrolling through the long calendar.
    // Scroll the page back until it is built, rather than asking ensureVisible
    // for an element that is currently outside the ListView's cache.
    await tester.scrollUntilVisible(
      find.byKey(const Key('add-maintenance-task')),
      -400,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-maintenance-task')));
    await _pumpUntilFound(tester, find.byKey(const Key('maintenance-title')));
    await tester.enterText(find.byKey(const Key('maintenance-title')), '取消的任务');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('取消').last);
    await tester.tap(find.text('取消').last);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(
      await database.select(database.maintenanceTasks).get(),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
    await _disposePage(tester);
  });
}

Widget _testPage({
  required MaintenanceRepository repository,
  required Tank tank,
  double textScale = 1,
}) {
  return ProviderScope(
    key: ValueKey('maintenance-scope-${tank.id}'),
    overrides: [
      notificationsEnabledProvider.overrideWithValue(false),
      maintenanceCyclesProvider(
        tank.id,
      ).overrideWith((ref) => Stream.value([])),
      currentTankProvider.overrideWith((ref) => Stream.value(tank)),
      maintenanceRepositoryProvider.overrideWith((ref) => repository),
    ],
    child: MaterialApp(
      theme: LanjiaoTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const Scaffold(body: MaintenancePage()),
    ),
  );
}

Tank _tank({required String id, required String name, required DateTime now}) {
  return Tank(
    id: id,
    name: name,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}

Future<String> _createTask(
  MaintenanceRepository repository,
  String tankId,
  String title,
  DateTime now,
) {
  return repository.createTask(
    tankId: tankId,
    title: title,
    intervalAmount: 1,
    intervalUnit: MaintenanceIntervalUnit.week,
    dueAt: now,
  );
}

void _useTallTestSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 350; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('等待组件超时：$finder');
}

Future<void> _pumpUntilAbsent(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 350; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('等待组件消失超时：$finder');
}

Future<void> _disposePage(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // Riverpod cancels Drift query streams while finalizing the unmounted
  // ProviderScope. Drift schedules a zero-delay cleanup timer at that point,
  // so one additional frame is not always enough to consume it.
  await tester.pump(Duration.zero);
  await tester.pump();
}
