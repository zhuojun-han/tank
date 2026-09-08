import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/features/calculators/presentation/maintenance_dosing_page.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/alkalinity_calculator.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/calculator_session.dart';

void main() {
  testWidgets('320px KH form inherits only the same tank session plan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = CalculatorSession();
    session.rememberKh(
      'tank-a',
      calculateAlkalinityPlan(
        currentDkh: 7,
        targetDkh: 8,
        netWaterVolumeL: 300,
        dailyDkhConsumption: 0.2,
        purityPercent: 99,
        stockMlPerPointOne: 4,
        stockTemperatureC: 30,
      ),
    );
    expect(session.khPlanFor('tank-b'), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: MaintenanceDosingPage(previousKh: session.khPlanFor('tank-a')),
      ),
    );
    await tester.tap(find.text('KH · 碳酸氢钠'));
    await tester.pumpAndSettle();
    expect(find.text('取母液 142.857 ml'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('dosing-water')))
          .controller!
          .text,
      '300.0',
    );
    await tester.ensureVisible(find.byKey(const Key('dosing-details')));
    await tester.tap(find.byKey(const Key('dosing-details')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('dosing-temperature')));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('dosing-purity')))
          .controller!
          .text,
      '99.0',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('dosing-temperature')))
          .controller!
          .text,
      '30.0',
    );
    await tester.enterText(find.byKey(const Key('dosing-temperature')), '20');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('dosing-error')));
    expect(find.byKey(const Key('dosing-stock')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'selected channel keeps independent inputs and excludes hidden errors',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: MaintenanceDosingPage()));
      expect(find.text('取母液 2.381 ml'), findsOneWidget);
      expect(find.text('每瓶使用天数'), findsNothing);
      expect(find.byKey(const Key('dosing-purity')), findsNothing);
      await tester.enterText(find.byKey(const Key('dosing-minutes-0')), '2');
      await tester.pump();
      expect(find.text('取母液 1.19 ml'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('dosing-flow-0')), '');
      await tester.pump();
      expect(find.byKey(const Key('dosing-error')), findsOneWidget);
      await tester.tap(find.text('KH · 碳酸氢钠'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dosing-error')), findsNothing);
      expect(find.text('取母液 357.143 ml'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('dosing-minutes-1')))
            .controller!
            .text,
        '1',
      );
      await tester.tap(find.text('PO₄ · 氯化镧'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('dosing-minutes-0')))
            .controller!
            .text,
        '2',
      );
      expect(find.byKey(const Key('dosing-error')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
