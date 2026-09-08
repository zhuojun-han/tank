import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/calculators/presentation/alkalinity_calculator_page.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_providers.dart';
import 'package:lanjiao_water_quality/features/maintenance/data/maintenance_repository.dart';
import 'package:lanjiao_water_quality/features/tanks/application/tank_providers.dart';

void main() {
  testWidgets('KH 页面计算、取消及确认创建有限日程', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final tank = await db.select(db.tanks).getSingle();
    final repo = MaintenanceRepository(db);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const AlkalinityCalculatorPage()),
        GoRoute(
          path: '/maintenance',
          builder: (_, _) => const Scaffold(body: Text('保存成功')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTankProvider.overrideWith((ref) => Stream.value(tank)),
          maintenanceRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('alkalinity-input-0')), '6.5');
    await tester.scrollUntilVisible(
      find.byKey(const Key('calculate-alkalinity')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('calculate-alkalinity')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('save-alkalinity-plan')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('360.00 mL'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-alkalinity-plan')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 100 && find.text('取消').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await db.select(db.maintenanceTasks).get(), isEmpty);
    await tester.tap(find.byKey(const Key('save-alkalinity-plan')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 100 && find.text('确认加入').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.tap(find.text('确认加入'));
    for (var i = 0; i < 100 && find.text('保存成功').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('保存成功'), findsOneWidget);
    final tasks = await db.select(db.maintenanceTasks).get();
    expect(tasks, hasLength(3));
    expect(tasks.every((t) => t.source == 'alkalinity-plan'), true);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
    router.dispose();
    await db.close();
  });
}
