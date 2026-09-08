import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/calculators/application/maintenance_cycle_providers.dart';
import 'package:lanjiao_water_quality/features/calculators/data/maintenance_cycle_repository.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_cycle.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_dosing.dart';
import 'package:lanjiao_water_quality/features/calculators/presentation/maintenance_dosing_page.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_providers.dart';

Future<void> show(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
}

void main() {
  const tank = AppDatabase.defaultTankId;
  late AppDatabase db;
  late MaintenanceCycleRepository repo;
  late DateTime now;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 9, 10, 12);
    repo = MaintenanceCycleRepository(db, now: () => now);
    await db.select(db.tanks).get();
  });
  tearDown(() => db.close());

  Widget harness({
    List<MaintenanceCycle> cycles = const [],
    String chemical = 'po4',
  }) => ProviderScope(
    overrides: [
      maintenanceCycleRepositoryProvider.overrideWithValue(repo),
      maintenanceCyclesProvider(
        tank,
      ).overrideWith((ref) => Stream.value(cycles)),
      maintenanceDateProvider.overrideWith((ref) => now),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MaintenanceDosingPage(
                    tankId: tank,
                    tankName: '测试缸',
                    initialChemical: chemical,
                  ),
                ),
              ),
              child: const Text('打开配方'),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets(
    'preview cancel writes nothing, confirmed cycle saves only after explicit action',
    (tester) async {
      await tester.pumpWidget(harness());
      await tester.tap(find.text('打开配方'));
      await tester.pumpAndSettle();
      expect(find.text('2026-09-10'), findsOneWidget);
      expect(await tester.runAsync(() => repo.getCycles()), isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(await tester.runAsync(() => repo.getCycles()), isEmpty);
      await tester.tap(find.text('打开配方'));
      await tester.pumpAndSettle();
      await show(tester, find.byKey(const Key('dosing-confirm')));
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('dosing-confirm')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      final saved = (await tester.runAsync(() => repo.getCycles()))!;
      expect(saved, hasLength(1));
      expect(saved.single.startDate, '2026-09-10');
      expect(saved.single.refillDate, '2026-09-15');
      expect(
        await tester.runAsync(() => db.select(db.maintenanceTasks).get()),
        isEmpty,
      );
      expect(
        await tester.runAsync(() => db.select(db.taskEvents).get()),
        isEmpty,
      );
      expect(find.text('打开配方'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '320px KH continuation requires residual choice and adjusts stock strength',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final old = prepareMaintenanceCycle(
        id: 'old',
        tankId: tank,
        chemical: DosingChemical.kh,
        startDate: '2026-09-08',
        input: const MaintenanceDosingInput(
          dailyChange: 0.5,
          flow: 100,
          unit: PumpFlowUnit.mlPerMinute,
        ),
      );
      await tester.runAsync(() => repo.confirm(old));
      await tester.pumpWidget(harness(cycles: [old], chemical: 'kh'));
      await tester.tap(find.text('打开配方'));
      await tester.pumpAndSettle();
      await show(tester, find.byKey(const Key('dosing-confirm')));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('dosing-confirm')))
            .onPressed,
        isNull,
      );
      final choice = find.byKey(
        const ValueKey('dosing-residual-choice-old-kh'),
      );
      await show(tester, choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      await tester.tap(find.text('有，保留残液继续配制').last);
      await tester.pumpAndSettle();
      await show(tester, find.byKey(const Key('dosing-residual')));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('dosing-residual')))
            .controller!
            .text,
        '300',
      );
      await show(tester, find.byKey(const Key('dosing-strength')));
      await tester.tap(find.byKey(const Key('dosing-strength')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('8 ml / 100 L 提升 0.1 dKH').last);
      await tester.pumpAndSettle();
      await show(tester, find.byKey(const Key('dosing-stock')));
      expect(find.text('再加母液 160 ml'), findsOneWidget);
      expect(find.text('加 RO/DI 水 40 ml，定容至 500.0 ml'), findsOneWidget);
      final unchanged = (await tester.runAsync(() => repo.getCycles()))!;
      expect(unchanged, hasLength(1));
      expect(unchanged.single.closedOnDate, isNull);
      await show(tester, find.byKey(const Key('dosing-confirm')));
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('dosing-confirm')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      final cycles = (await tester.runAsync(() => repo.getCycles()))!;
      expect(cycles, hasLength(2));
      expect(
        cycles.singleWhere((c) => c.id == old.id).closedOnDate,
        '2026-09-10',
      );
      final next = cycles.singleWhere((c) => c.id != old.id);
      expect(next.retainedMl, 300);
      expect(next.addedStockMl, closeTo(160, 1e-9));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'confirmation recalculates auto residual after midnight instead of stale preview',
    (tester) async {
      final old = prepareMaintenanceCycle(
        id: 'old',
        tankId: tank,
        chemical: DosingChemical.po4,
        startDate: '2026-09-08',
        input: const MaintenanceDosingInput(
          dailyChange: 0.02,
          flow: 100,
          unit: PumpFlowUnit.mlPerMinute,
        ),
      );
      await tester.runAsync(() => repo.confirm(old));
      await tester.pumpWidget(harness(cycles: [old]));
      await tester.tap(find.text('打开配方'));
      await tester.pumpAndSettle();
      final choice = find.byKey(
        const ValueKey('dosing-residual-choice-old-po4'),
      );
      await show(tester, choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      await tester.tap(find.text('有，保留残液继续配制').last);
      await tester.pumpAndSettle();
      await show(tester, find.byKey(const Key('dosing-residual')));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('dosing-residual')))
            .controller!
            .text,
        '300',
      );
      now = DateTime(2026, 9, 11, 0, 1);
      await show(tester, find.byKey(const Key('dosing-confirm')));
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('dosing-confirm')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      final saved = (await tester.runAsync(
        () => repo.getCycles(),
      ))!.singleWhere((c) => c.id != 'old');
      expect(saved.startDate, '2026-09-11');
      expect(saved.retainedMl, 200);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'actual preparation date changes automatic residual; manual volume survives day refresh',
    (tester) async {
      final old = prepareMaintenanceCycle(
        id: 'old',
        tankId: tank,
        chemical: DosingChemical.po4,
        startDate: '2026-09-08',
        input: const MaintenanceDosingInput(
          dailyChange: 0.02,
          flow: 100,
          unit: PumpFlowUnit.mlPerMinute,
        ),
      );
      await tester.runAsync(() => repo.confirm(old));
      await tester.pumpWidget(harness(cycles: [old]));
      await tester.tap(find.text('打开配方'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dosing-prepared-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('9'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('2026-09-09'), findsOneWidget);
      final choice = find.byKey(
        const ValueKey('dosing-residual-choice-old-po4'),
      );
      await show(tester, choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      await tester.tap(find.text('有，保留残液继续配制').last);
      await tester.pumpAndSettle();
      final residual = find.byKey(const Key('dosing-residual'));
      await show(tester, residual);
      expect(tester.widget<TextField>(residual).controller!.text, '400');
      await tester.enterText(residual, '275');
      await tester.pump();
      now = DateTime(2026, 9, 11, 0, 1);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaintenanceDosingPage)),
      );
      container.invalidate(maintenanceDateProvider);
      await tester.pump();
      expect(tester.widget<TextField>(residual).controller!.text, '275');
      await show(tester, find.byKey(const Key('dosing-confirm')));
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('dosing-confirm')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      final saved = (await tester.runAsync(
        () => repo.getCycles(),
      ))!.singleWhere((c) => c.id != 'old');
      expect(saved.startDate, '2026-09-09');
      expect(saved.retainedMl, 275);
      expect(tester.takeException(), isNull);
    },
  );
}
