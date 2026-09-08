import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/alkalinity_calculator.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/lanthanum_calculator.dart';
import 'package:lanjiao_water_quality/features/calculators/presentation/alkalinity_calculator_page.dart';
import 'package:lanjiao_water_quality/features/calculators/presentation/lanthanum_calculator_page.dart';
import 'package:lanjiao_water_quality/features/maintenance/data/maintenance_repository.dart';
import 'package:lanjiao_water_quality/features/tanks/application/tank_providers.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';

Future<void> settleDb(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> tapKey(WidgetTester tester, String key) async {
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(Key(key)),
    280,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await settleDb(tester);
}

void main() {
  for (final kh in [false, true]) {
    final kind = kh ? 'KH' : 'PO4';
    final currentKey = kh ? 'alkalinity-input-0' : 'lanthanum-current-po4';
    final targetKey = kh ? 'alkalinity-input-1' : 'lanthanum-target-po4';
    final calculateKey = kh ? 'calculate-alkalinity' : 'calculate-lanthanum';
    final saveKey = kh ? 'save-alkalinity-plan' : 'save-lanthanum-plan';
    testWidgets(
      '$kind page rejects user bounds, accepts boundary, cancel preserves empty tasks',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final tank = await db.select(db.tanks).getSingle();
        final tanks = TankRepository(db);
        if (kh) {
          await tanks.setParameterEnabled(
            tankId: tank.id,
            parameterId: AppDatabase.khId,
            enabled: true,
          );
        }
        await tanks.setTarget(
          tankId: tank.id,
          parameterId: kh ? AppDatabase.khId : AppDatabase.po4Id,
          minValue: kh ? 7 : .05,
          maxValue: kh ? 8 : .1,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              home: kh
                  ? const AlkalinityCalculatorPage()
                  : const LanthanumCalculatorPage(),
            ),
          ),
        );
        await settleDb(tester);
        await tester.enterText(find.byKey(Key(currentKey)), kh ? '6' : '.23');
        await tester.enterText(find.byKey(Key(targetKey)), kh ? '9' : '.03');
        await tapKey(tester, calculateKey);
        expect(
          find.textContaining(kh ? '不得高于当前海缸目标上限' : '不得低于当前海缸目标下限'),
          findsOneWidget,
        );
        expect(find.byKey(Key(saveKey)), findsNothing);
        await tester.scrollUntilVisible(
          find.byKey(Key(targetKey)),
          -280,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(find.byKey(Key(targetKey)), kh ? '8' : '.05');
        await tapKey(tester, calculateKey);
        await tapKey(tester, saveKey);
        expect(find.text('确认加入'), findsOneWidget);
        await tester.tap(find.text('取消'));
        await settleDb(tester);
        expect(await db.select(db.maintenanceTasks).get(), isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await settleDb(tester);
        await db.close();
      },
    );

    testWidgets(
      '$kind range changed during overwrite confirmation cannot replace existing tasks',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final tank = await db.select(db.tanks).getSingle();
        final tanks = TankRepository(db);
        final repo = MaintenanceRepository(db);
        if (kh) {
          await tanks.setParameterEnabled(
            tankId: tank.id,
            parameterId: AppDatabase.khId,
            enabled: true,
          );
        }
        await tanks.setTarget(
          tankId: tank.id,
          parameterId: kh ? AppDatabase.khId : AppDatabase.po4Id,
          minValue: kh ? 7 : .05,
          maxValue: kh ? 8 : .1,
        );
        final ids = kh
            ? await repo.createAlkalinityPlanTasks(
                tankId: tank.id,
                plan: calculateAlkalinityPlan(currentDkh: 6, targetDkh: 8),
              )
            : await repo.createLanthanumPlanTasks(
                tankId: tank.id,
                plan: calculateLanthanumPlan(
                  currentPo4MgL: .23,
                  targetPo4MgL: .05,
                  netWaterVolumeL: 200,
                  maxDailyPo4DropMgL: .1,
                ),
              );
        await repo.complete(tankId: tank.id, taskId: ids.first);
        final before = await db.select(db.maintenanceTasks).get();
        final events = await db.select(db.taskEvents).get();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              home: kh
                  ? const AlkalinityCalculatorPage()
                  : const LanthanumCalculatorPage(),
            ),
          ),
        );
        await settleDb(tester);
        await tester.enterText(find.byKey(Key(currentKey)), kh ? '6' : '.23');
        await tester.enterText(find.byKey(Key(targetKey)), kh ? '8' : '.05');
        await tapKey(tester, calculateKey);
        await tapKey(tester, saveKey);
        expect(find.text('确认覆盖'), findsOneWidget);
        await tester.tap(find.text('仅计算，不覆盖原计划'));
        await settleDb(tester);
        expect(await db.select(db.maintenanceTasks).get(), before);
        expect(await db.select(db.taskEvents).get(), events);
        await tapKey(tester, saveKey);
        expect(find.text('确认覆盖'), findsOneWidget);
        await tanks.setTarget(
          tankId: tank.id,
          parameterId: kh ? AppDatabase.khId : AppDatabase.po4Id,
          minValue: kh ? 7 : .06,
          maxValue: kh ? 7.8 : .1,
        );
        await tester.tap(find.text('确认覆盖'));
        await settleDb(tester);
        expect(await db.select(db.maintenanceTasks).get(), before);
        expect(await db.select(db.taskEvents).get(), events);
        expect(find.byKey(Key(saveKey)), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await settleDb(tester);
        await db.close();
      },
    );
  }
}
