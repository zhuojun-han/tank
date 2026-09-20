import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanjiao_water_quality/app/router.dart';
import 'package:lanjiao_water_quality/app/theme.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/aquarium/application/aquarium_providers.dart';
import 'package:lanjiao_water_quality/features/aquarium/domain/fish_stock.dart';
import 'package:lanjiao_water_quality/features/calculators/application/maintenance_cycle_providers.dart';
import 'package:lanjiao_water_quality/features/calculators/data/maintenance_cycle_repository.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_cycle.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_dosing.dart';
import 'package:lanjiao_water_quality/features/calculators/presentation/maintenance_dosing_page.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_providers.dart';
import 'package:lanjiao_water_quality/features/maintenance/data/maintenance_repository.dart';
import 'package:lanjiao_water_quality/features/maintenance/domain/rolling_schedule.dart';
import 'package:lanjiao_water_quality/features/tanks/application/tank_providers.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';
import 'package:lanjiao_water_quality/features/test_records/application/test_record_providers.dart';
import 'package:lanjiao_water_quality/features/trends/data/record_history_source.dart';
import 'package:lanjiao_water_quality/features/trends/presentation/database_record_history_widgets.dart';
import 'package:lanjiao_water_quality/features/trends/presentation/record_history_widgets.dart';

import '../../support/record_history_fixture.dart';

Future<void> _show(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      220,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 20,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pump();
}

Future<void> _flush(WidgetTester tester) async {
  // Let real SQLite watch streams deliver before pumping the next UI frame.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;
  late MaintenanceCycleRepository cycles;
  late MaintenanceRepository tasks;
  late ProviderContainer container;
  late GoRouter router;
  late StreamController<Tank> changes;
  late DateTime now;
  late Tank tankA, tankB, selected;
  late List<WaterParameter> parameters;
  late List<TestRecord> historyRecords;
  late Map<String, List<WaterQualityTarget>> targetRanges;

  setUp(() async {
    final today = DateTime.now();
    now = DateTime(today.year, today.month, today.day, 12);
    db = AppDatabase(NativeDatabase.memory());
    final tanks = TankRepository(db);
    tankA = (await db.select(db.tanks).get()).single;
    final id = await tanks.createTank(name: '独立B缸');
    tankB = (await (db.select(
      db.tanks,
    )..where((t) => t.id.equals(id))).get()).single;
    selected = tankA;
    parameters = [];
    historyRecords = [];
    targetRanges = {};
    cycles = MaintenanceCycleRepository(db, now: () => now);
    tasks = MaintenanceRepository(db, now: () => now);
    changes = StreamController<Tank>.broadcast();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        maintenanceCycleRepositoryProvider.overrideWithValue(cycles),
        maintenanceRepositoryProvider.overrideWithValue(tasks),
        maintenanceClockProvider.overrideWith((ref) => Stream.value(now)),
        currentTankProvider.overrideWith((ref) async* {
          yield selected;
          yield* changes.stream;
        }),
        enabledParametersProvider.overrideWith(
          (ref, tankId) => Stream.value(parameters),
        ),
        latestTestRecordsProvider.overrideWith(
          (ref, tankId) => Stream.value(
            historyRecords.where((record) => record.tankId == tankId).toList(),
          ),
        ),
        waterQualityTargetsProvider.overrideWith(
          (ref, tankId) =>
              Stream.value(targetRanges[tankId] ?? <WaterQualityTarget>[]),
        ),
        recordHistorySourceProvider.overrideWithValue(
          FixtureRecordHistorySource(historyRecords),
        ),
        fishStockProvider.overrideWith(
          (ref, tankId) => Stream.value(<FishStockItem>[]),
        ),
      ],
    );
    router = createAppRouter();
  });

  tearDown(() async {
    router.dispose();
    container.dispose();
    await changes.close();
    await db.close();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          theme: LanjiaoTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await _flush(tester);
  }

  MaintenanceCycle prepare(
    String id,
    Tank tank, {
    bool kh = false,
    int elapsed = 0,
  }) => prepareMaintenanceCycle(
    id: id,
    tankId: tank.id,
    chemical: kh ? DosingChemical.kh : DosingChemical.po4,
    startDate: cycleDateKey(DateTime(now.year, now.month, now.day - elapsed)),
    input: MaintenanceDosingInput(dailyChange: kh ? 0.5 : 0.02),
  );

  testWidgets(
    'web home order and two-column metrics remain usable at 320px with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final (id, code) in [
        (AppDatabase.no3Id, 'NO3'),
        (AppDatabase.po4Id, 'PO4'),
      ]) {
        parameters.add(
          WaterParameter(
            id: id,
            code: code,
            displayName: code,
            unit: 'mg/L',
            isBuiltIn: true,
            photoSupported: true,
            createdAt: now,
          ),
        );
        historyRecords.add(
          TestRecord(
            id: 'layout-$id',
            tankId: tankA.id,
            parameterId: id,
            confirmedMinValue: 5,
            unit: 'mg/L',
            measuredAt: now,
            wasManuallyEdited: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      await tester.runAsync(
        () => cycles.confirm(prepare('layout-cycle', tankA, kh: true)),
      );
      await open(tester);
      final first = find.byKey(const Key('home-metric-${AppDatabase.no3Id}'));
      final second = find.byKey(const Key('home-metric-${AppDatabase.po4Id}'));
      await _show(tester, first);
      expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
      expect(
        tester.getTopLeft(first).dx,
        lessThan(tester.getTopLeft(second).dx),
      );
      expect(
        tester.getSize(first).width,
        closeTo(tester.getSize(second).width, .01),
      );
      final scroll = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const Key('home-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      double documentTop(Finder finder) =>
          tester.getTopLeft(finder).dy + scroll.pixels;
      var previous = documentTop(first);
      for (final key in [
        'home-advice-section',
        'home-manage-parameters',
        'home-dosing-heading',
        'home-todos-heading',
        'home-trends-heading',
      ]) {
        final finder = find.byKey(Key(key));
        await _show(tester, finder);
        final top = documentTop(finder);
        expect(top, greaterThan(previous), reason: key);
        previous = top;
        expect(tester.takeException(), isNull, reason: key);
      }
      scroll.jumpTo(0);
      await _flush(tester);
      await _show(tester, first);
      await tester.tap(first);
      await _flush(tester);
      expect(
        tester
            .widget<DatabaseRecordChart>(find.byKey(const Key('trend-chart')))
            .scope,
        (tankId: tankA.id, parameterId: AppDatabase.no3Id),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'home shows finite cycle status once, cancels delay and removes postponed refill from today',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final due = prepare('po4-a', tankA, elapsed: 5),
          daily = prepare('kh-a', tankA, kh: true);
      await tester.runAsync(() async {
        await cycles.confirm(due);
        await cycles.confirm(daily);
        await cycles.confirm(prepare('po4-b', tankB));
      });
      await open(tester);
      final dueTile = find.byKey(const Key('home-cycle-po4-a'));
      await _show(tester, dueTile);
      expect(dueTile, findsOneWidget);
      expect(
        find.byKey(const Key('home-maintenance-cycle-po4-a')),
        findsNothing,
      );
      expect(find.text('当前没有未完成维护事项'), findsNothing);
      expect(find.byKey(const Key('home-cycle-po4-b')), findsNothing);
      expect(
        find.descendant(of: dueTile, matching: find.textContaining('80 mL')),
        findsOneWidget,
      );
      final delay = find.descendant(of: dueTile, matching: find.text('延迟'));
      await tester.tap(delay);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '1',
      );
      await tester.tap(find.text('取消'));
      await _flush(tester);
      expect(
        (await tester.runAsync(
          () => cycles.getCycles(),
        ))!.singleWhere((c) => c.id == due.id).refillDeferredUntil,
        isNull,
      );
      await tester.tap(delay);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '2');
      await tester.runAsync(() async {
        await tester.tap(find.text('确认延迟'));
      });
      await _flush(tester);
      expect(find.byKey(const Key('home-cycle-po4-a')), findsNothing);
      expect(find.text('当前没有未完成维护事项'), findsOneWidget);
      final dailyTile = find.byKey(const Key('home-cycle-kh-a'));
      await _show(tester, dailyTile);
      expect(
        find.descendant(of: dailyTile, matching: find.text('已完成')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dailyTile, matching: find.text('完成任务')),
        findsNothing,
      );
      expect(
        await tester.runAsync(() => db.select(db.maintenanceTasks).get()),
        isEmpty,
      );
      expect(
        await tester.runAsync(() => db.select(db.taskEvents).get()),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'home refill route selects reagent and switching tank resets dosing draft',
    (tester) async {
      await tester.runAsync(() async {
        await cycles.confirm(prepare('kh-a', tankA, kh: true));
        await cycles.confirm(prepare('po4-b', tankB));
      });
      await open(tester);
      final a = find.byKey(const Key('home-cycle-kh-a'));
      await _show(tester, a);
      await tester.tap(find.descendant(of: a, matching: find.text('提前配液')));
      await _flush(tester);
      final pageA = tester.widget<MaintenanceDosingPage>(
        find.byType(MaintenanceDosingPage),
      );
      expect(pageA.tankId, tankA.id);
      expect(pageA.initialChemical, 'kh');
      await tester.enterText(find.byKey(const Key('dosing-water')), '333');
      await tester.pump();
      selected = tankB;
      changes.add(selected);
      await _flush(tester);
      final pageB = tester.widget<MaintenanceDosingPage>(
        find.byType(MaintenanceDosingPage),
      );
      expect(pageB.tankId, tankB.id);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('dosing-water')))
            .controller!
            .text,
        isNot('333'),
      );
      await tester.pageBack();
      await _flush(tester);
      final b = find.byKey(const Key('home-cycle-po4-b'));
      await _show(tester, b);
      expect(find.byKey(const Key('home-cycle-kh-a')), findsNothing);
      await tester.tap(find.descendant(of: b, matching: find.text('提前配液')));
      await _flush(tester);
      final fromB = tester.widget<MaintenanceDosingPage>(
        find.byType(MaintenanceDosingPage),
      );
      expect(fromB.tankId, tankB.id);
      expect(fromB.initialChemical, 'po4');
      expect(await tester.runAsync(() => cycles.getCycles()), hasLength(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'home actual completion date cancels without write then starts next interval from chosen date',
    (tester) async {
      final start = DateTime(now.year, now.month, now.day - 7);
      final taskId = (await tester.runAsync(
        () => tasks.createTask(
          tankId: tankA.id,
          title: '每周清洁滤棉',
          intervalAmount: 7,
          intervalUnit: MaintenanceIntervalUnit.day,
          dueAt: start,
        ),
      ))!;
      await open(tester);
      final tile = find.byKey(Key('home-maintenance-$taskId'));
      await _show(tester, tile);
      final complete = find.descendant(of: tile, matching: find.text('完成任务'));
      final before = (await tester.runAsync(
        () => db.select(db.maintenanceTasks).get(),
      ))!.single;
      await tester.tap(complete);
      await tester.pumpAndSettle();
      expect(find.text('实际完成日期'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await _flush(tester);
      expect(
        (await tester.runAsync(
          () => db.select(db.maintenanceTasks).get(),
        ))!.single,
        before,
      );
      expect(
        await tester.runAsync(() => db.select(db.taskEvents).get()),
        isEmpty,
      );
      await tester.tap(complete);
      await tester.pumpAndSettle();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      if (yesterday.month != now.month) {
        await tester.tap(find.byTooltip('Previous month'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('${yesterday.day}'));
      await tester.runAsync(() async {
        await tester.tap(find.text('确认'));
      });
      await _flush(tester);
      final saved = (await tester.runAsync(
        () => db.select(db.maintenanceTasks).get(),
      ))!.single;
      final schedule = rollingSchedule(saved);
      expect(schedule.completed.single.completedDate, cycleDateKey(yesterday));
      expect(
        schedule.nextDate,
        cycleDateKey(
          DateTime(yesterday.year, yesterday.month, yesterday.day + 7),
        ),
      );
      expect(find.byKey(Key('home-maintenance-$taskId')), findsNothing);
      expect(
        await tester.runAsync(() => db.select(db.taskEvents).get()),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'home KH record opens matching trend and changing tanks replaces chart and nullable target',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      parameters.add(
        WaterParameter(
          id: AppDatabase.khId,
          code: 'KH',
          displayName: '碳酸盐硬度',
          unit: 'dKH',
          isBuiltIn: true,
          photoSupported: false,
          createdAt: now,
        ),
      );
      for (final (tank, value) in [(tankA, 7.7), (tankB, 8.2)]) {
        historyRecords.add(
          TestRecord(
            id: 'kh-${tank.id}',
            tankId: tank.id,
            parameterId: AppDatabase.khId,
            confirmedMinValue: value,
            unit: 'dKH',
            measuredAt: now,
            wasManuallyEdited: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
        targetRanges[tank.id] = [
          WaterQualityTarget(
            id: 'target-${tank.id}',
            tankId: tank.id,
            parameterId: AppDatabase.khId,
            minValue: tank.id == tankA.id ? 7 : null,
            maxValue: tank.id == tankB.id ? 9 : null,
            unit: 'dKH',
            updatedAt: now,
          ),
        ];
      }
      await open(tester);
      final record = find.text('KH · 7.7 dKH');
      await _show(tester, record);
      await tester.tap(record);
      await _flush(tester);
      expect(
        tester
            .widget<DatabaseRecordChart>(find.byKey(const Key('trend-chart')))
            .scope
            .parameterId,
        AppDatabase.khId,
      );
      expect(find.text('目标 ≥7 dKH'), findsOneWidget);
      expect(
        tester
            .widget<DatabaseRecordChart>(find.byKey(const Key('trend-chart')))
            .scope
            .tankId,
        tankA.id,
      );
      selected = tankB;
      changes.add(selected);
      await _flush(tester);
      expect(find.text('目标 ≤9 dKH'), findsOneWidget);
      expect(find.text('目标 ≥7 dKH'), findsNothing);
      final chart = tester.widget<DatabaseRecordChart>(
        find.byKey(const Key('trend-chart')),
      );
      expect(chart.scope.tankId, tankB.id);
      final visible = tester.widget<ScrollableRecordChart>(
        find.descendant(
          of: find.byKey(const Key('trend-chart')),
          matching: find.byType(ScrollableRecordChart),
        ),
      );
      expect(visible.data.map((item) => item.record.tankId).toSet(), {
        tankB.id,
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
