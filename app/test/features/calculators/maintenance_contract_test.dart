import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_dosing.dart';
import '../../../tool/support/project_root_locator.dart';

void main() {
  test('shared web/App maintenance recipe contract', () async {
    final root = await locateProjectRoot();
    final data =
        jsonDecode(
              await File(
                '${root.path}/contracts/maintenance-dosing.json',
              ).readAsString(),
            )
            as Map;
    final tolerance = (data['absoluteTolerance'] as num).toDouble();
    for (final row in data['cases'] as List) {
      final input = {...data['defaults'] as Map, ...row['input'] as Map};
      double number(String key) => (input[key] as num).toDouble();
      MaintenanceDosingResult calculate() => calculateMaintenanceDosing(
        chemical: input['chemical'] == 'po4'
            ? DosingChemical.po4
            : DosingChemical.kh,
        waterL: number('waterL'),
        volumeMl: number('volumeMl'),
        dailyChange: number('dailyChange'),
        flow: number('flow'),
        minutes: number('minutes'),
        unit: input['unit'] == 'ml/s'
            ? PumpFlowUnit.mlPerSecond
            : PumpFlowUnit.mlPerMinute,
        khStrength: (input['khStrength'] as num).toInt(),
        khPurity: number('khPurity'),
        temperature: number('temperature'),
      );
      final expected = row['expected'] as Map? ?? const {};
      if (row['reject'] == true) {
        expect(calculate, throwsFormatException, reason: row['id']);
      } else {
        final actual = calculate();
        for (final entry in {
          'dailyStockMl': actual.dailyStockMl,
          'dailyLiquidMl': actual.dailyLiquidMl,
          'actualDays': actual.actualDays,
          'stockMl': actual.stockMl,
        }.entries) {
          expect(
            entry.value,
            closeTo(expected[entry.key], tolerance),
            reason: '${row['id']} ${entry.key}',
          );
        }
        expect(actual.feasible, expected['feasible'], reason: row['id']);
      }
    }
  });
}
