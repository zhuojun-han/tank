import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_dosing.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/alkalinity_calculator.dart';

void main() {
  test('recipes use actual volume and output without rounding stock', () {
    final po4 = calculateMaintenanceDosing(
      chemical: DosingChemical.po4,
      dailyChange: 0.02,
    );
    expect(po4.dailyLiquidMl, 84);
    expect(po4.stockMl, closeTo(.4 * 500 / 84, 1e-12));
    final kh = calculateMaintenanceDosing(
      chemical: DosingChemical.kh,
      dailyChange: 0.5,
    );
    expect(kh.dailyStockMl, 60);
    expect(kh.stockMl, closeTo(60 * 500 / 84, 1e-10));
    expect(kh.khConcentrationGPerL, closeTo(50.00416667, 1e-7));
    final changed = calculateMaintenanceDosing(
      chemical: DosingChemical.po4,
      dailyChange: 0.02,
      minutes: 2,
    );
    expect(changed.dailyLiquidMl, 168);
    expect(changed.stockMl, closeTo(0.4 * 500 / 168, 1e-12));
    final units = calculateMaintenanceDosing(
      chemical: DosingChemical.po4,
      dailyChange: 0.02,
      flow: 84,
      unit: PumpFlowUnit.mlPerMinute,
    );
    expect(units.stockMl, po4.stockMl);
  });
  test('zero requirement, capacity and invalid numerical inputs', () {
    expect(
      calculateMaintenanceDosing(
        chemical: DosingChemical.po4,
        dailyChange: 0,
      ).stockMl,
      0,
    );
    expect(
      calculateMaintenanceDosing(
        chemical: DosingChemical.kh,
        dailyChange: 1,
      ).feasible,
      isFalse,
    );
    for (final value in [-1.0, double.nan, double.infinity]) {
      expect(
        () => calculateMaintenanceDosing(
          chemical: DosingChemical.po4,
          dailyChange: value,
        ),
        throwsFormatException,
      );
    }
    expect(
      () => calculateMaintenanceDosing(
        chemical: DosingChemical.po4,
        dailyChange: 0.02,
        flow: 0,
      ),
      throwsFormatException,
    );
    expect(
      () => calculateMaintenanceDosing(
        chemical: DosingChemical.po4,
        dailyChange: 0.02,
        minutes: 0,
      ),
      throwsFormatException,
    );
    expect(
      () => calculateMaintenanceDosing(
        chemical: DosingChemical.po4,
        dailyChange: 1e308,
        waterL: 1e308,
      ),
      throwsFormatException,
    );
  });
  test(
    '4 ml KH stock retains temperature/purity limits and is shared with KH plans',
    () {
      expect(
        () => calculateMaintenanceDosing(
          chemical: DosingChemical.kh,
          dailyChange: 0.5,
          khStrength: 4,
        ),
        throwsFormatException,
      );
      final kh = calculateMaintenanceDosing(
        chemical: DosingChemical.kh,
        dailyChange: 0.5,
        khStrength: 4,
        temperature: 30,
      );
      expect(kh.dailyStockMl, 40);
      expect(kh.stockMl, closeTo(40 * 500 / 84, 1e-10));
      final plan = calculateAlkalinityPlan(
        currentDkh: 7,
        targetDkh: 8,
        stockMlPerPointOne: 4,
        stockTemperatureC: 30,
      );
      expect(
        plan.stockConcentrationGPerL,
        closeTo(kh.khConcentrationGPerL!, 1e-10),
      );
      for (final strength in alkalinityStockMlOptions) {
        expect(
          calculateMaintenanceDosing(
            chemical: DosingChemical.kh,
            dailyChange: 0.5,
            khStrength: strength,
            temperature: 30,
          ).dailyStockMl,
          strength * 10,
        );
      }
      expect(
        () => calculateMaintenanceDosing(
          chemical: DosingChemical.kh,
          dailyChange: 0.5,
          khStrength: 5,
        ),
        throwsFormatException,
      );
      expect(
        () => calculateMaintenanceDosing(
          chemical: DosingChemical.kh,
          dailyChange: 0.5,
          khPurity: 50,
        ),
        throwsFormatException,
      );
      expect(
        () => calculateMaintenanceDosing(
          chemical: DosingChemical.kh,
          dailyChange: 0.5,
          temperature: 41,
        ),
        throwsFormatException,
      );
      // Hidden KH values cannot prevent computing the selected PO4 recipe.
      expect(
        calculateMaintenanceDosing(
          chemical: DosingChemical.po4,
          dailyChange: 0.02,
          khPurity: double.nan,
          temperature: -1,
        ).stockMl,
        closeTo(.4 * 500 / 84, 1e-12),
      );
    },
  );
}
