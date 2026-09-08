import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/calculators/presentation/alkalinity_calculator_page.dart';
import 'package:lanjiao_water_quality/features/calculators/presentation/lanthanum_calculator_page.dart';
import 'package:lanjiao_water_quality/features/tanks/application/tank_providers.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  for (final kh in [false, true]) {
    testWidgets(
      '${kh ? "KH" : "PO4"} target midpoint, manual ownership, reopened range and tank isolation',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final tanks = TankRepository(db), first = AppDatabase.defaultTankId;
        final parameter = kh ? AppDatabase.khId : AppDatabase.po4Id;
        final key = Key(kh ? 'alkalinity-input-1' : 'lanthanum-target-po4');
        Future<void> setTarget(String tank, double? min, double? max) =>
            tanks.setTarget(
              tankId: tank,
              parameterId: parameter,
              minValue: min,
              maxValue: max,
            );
        Widget app() => ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: kh
                ? const AlkalinityCalculatorPage()
                : const LanthanumCalculatorPage(),
          ),
        );
        String text() =>
            tester.widget<TextField>(find.byKey(key)).controller!.text;
        try {
          if (kh) {
            await tanks.setParameterEnabled(
              tankId: first,
              parameterId: parameter,
              enabled: true,
            );
          }
          await setTarget(first, kh ? 7.8 : .01, kh ? 7.81 : .03);
          await tester.pumpWidget(app());
          await settle(tester);
          expect(text(), kh ? '7.805' : '0.02');
          await tester.enterText(find.byKey(key), kh ? '7.806' : '.021');
          await setTarget(first, kh ? 7 : .02, kh ? 9 : .08);
          await settle(tester);
          expect(text(), kh ? '7.806' : '.021');
          expect(await db.select(db.maintenanceTasks).get(), isEmpty);
          await tester.pumpWidget(const SizedBox());
          await settle(tester);
          await tester.pumpWidget(app());
          await settle(tester);
          expect(text(), kh ? '8' : '0.05');
          await setTarget(first, kh ? 7.5 : .02, null);
          await settle(tester);
          expect(text(), '');
          await setTarget(first, null, null);
          await settle(tester);
          expect(text(), kh ? '8' : '0.03');
          final second = await tanks.createTank(name: '第二缸');
          if (kh) {
            await tanks.setParameterEnabled(
              tankId: second,
              parameterId: parameter,
              enabled: true,
            );
          }
          await setTarget(second, kh ? 8 : .06, kh ? 10 : .1);
          await tester.enterText(find.byKey(key), kh ? '8.5' : '.031');
          await tanks.switchTank(second);
          await settle(tester);
          expect(text(), kh ? '9' : '0.08');
          await tanks.switchTank(first);
          await settle(tester);
          expect(text(), kh ? '8' : '0.03');
          expect(await db.select(db.testRecords).get(), isEmpty);
          expect(await db.select(db.maintenanceTasks).get(), isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await settle(tester);
          await db.close();
        }
      },
    );
  }
}
