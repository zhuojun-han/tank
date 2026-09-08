import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/features/test_timer/domain/kh_titration.dart';
import '../../../tool/support/project_root_locator.dart';

void main() {
  test('all 50 printed KH rows match the shared contract exactly', () async {
    final root = await locateProjectRoot();
    final contract =
        jsonDecode(
              await File(
                '${root.path}/contracts/kh-titration.json',
              ).readAsString(),
            )
            as Map;
    expect(khTitrationTableId, contract['contract']);
    final rows = contract['rows'] as List;
    expect(rows.length, khTitrationDkhRows.length);
    for (final row in rows) {
      final remaining = (row['readingMl'] as num).toDouble();
      final result = calculateKhTitration(1, remaining);
      expect(result.dkh, row['dkh']);
      expect(result.tableReadingMl, remaining);
      expect(result.interpolated, false);
    }
  });
  test(
    'partial syringe, interpolation and rounding match Web including trailing zero',
    () {
      final interpolated = calculateKhTitration(.8, .29);
      expect(interpolated.tableReadingMl, closeTo(.49, 1e-12));
      expect(interpolated.dkh, closeTo(7.85, 1e-12));
      expect(interpolated.displayDkh, '7.9');
      expect(interpolated.interpolated, true);
      expect(calculateKhTitration(1, .48).displayDkh, '8.0');
      expect(calculateKhTitration(1, .98).displayDkh, '0.0');
      expect(calculateKhTitration(.9, .6).displayDkh, '4.5');
    },
  );
  test(
    'empty/nonfinite, invalid volumes and out-of-table readings are rejected',
    () {
      for (final input in [
        (double.nan, .5),
        (1.0, double.infinity),
        (1.01, .5),
        (-1.0, .5),
        (.5, .6),
        (1.0, -.1),
        (1.0, 1.0),
        (0.0, 0.0),
        (1.0, .99),
      ]) {
        expect(
          () => calculateKhTitration(input.$1, input.$2),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'metadata is recalculated and rejects a changed formula/table/display',
    () {
      final json = calculateKhTitration(.8, .29).toJson();
      expect(validateKhTitrationJson(jsonEncode(json)).displayDkh, '7.9');
      for (final patch in [
        {'tableId': 'other'},
        {'dkh': 8},
        {'usedMl': 0},
        {'displayDkh': '7.8'},
        {'interpolated': false},
      ]) {
        expect(
          () => validateKhTitrationJson(jsonEncode({...json, ...patch})),
          throwsFormatException,
        );
      }
    },
  );
}
