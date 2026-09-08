import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/target_default.dart';

void main() {
  test(
    'target midpoint preserves decimals and scientific notation without fixed precision',
    () {
      expect(
        calculatorTargetDefault(kh: true, minimum: 7.8, maximum: 7.81),
        '7.805',
      );
      expect(
        calculatorTargetDefault(kh: false, minimum: .01, maximum: .03),
        '0.02',
      );
      expect(decimalMidpoint(1e-8, 2e-8), 1.5e-8);
    },
  );
  test(
    'missing target defaults differ from single-sided or invalid target',
    () {
      expect(calculatorTargetDefault(kh: true), '8');
      expect(calculatorTargetDefault(kh: false), '0.03');
      expect(calculatorTargetDefault(kh: true, minimum: 7), '');
      expect(calculatorTargetDefault(kh: false, maximum: .1), '');
      expect(calculatorTargetDefault(kh: true, minimum: 9, maximum: 7), '');
      expect(
        calculatorTargetDefault(kh: true, minimum: double.nan, maximum: 7),
        '',
      );
    },
  );
}
