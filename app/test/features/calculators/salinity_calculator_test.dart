import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/salinity_calculator.dart';

void main() {
  test('初始 0 按无盐水处理并使用包装比重校准', () {
    final result = calculateSaltMix(
      initialSpecificGravity: 0,
      targetSpecificGravity: 1.025,
      waterVolumeLitres: 20,
      labelReferenceSpecificGravity: 1.0255,
      saltGramsPerLitreAtReference: 38.2,
    );

    expect(result.effectiveInitialSpecificGravity, 1);
    expect(result.requiredSaltGrams, closeTo(749.0196078431372, 1e-9));
    expect(result.initialAdditionGrams, closeTo(674.1176470588235, 1e-9));
    expect(result.reservedAdjustmentGrams, closeTo(74.9019607843137, 1e-9));
  });

  test('已有盐度只计算需要补充的比例', () {
    final result = calculateSaltMix(
      initialSpecificGravity: 1.020,
      targetSpecificGravity: 1.025,
      waterVolumeLitres: 20,
      labelReferenceSpecificGravity: 1.0255,
      saltGramsPerLitreAtReference: 38.2,
    );
    expect(result.requiredSaltGrams, closeTo(149.80392156862743, 1e-9));
  });

  test('拒绝无效比重、非正水量和降低盐度请求', () {
    SalinityCalculationResult run({
      double initial = 0,
      double target = 1.025,
      double volume = 20,
    }) => calculateSaltMix(
      initialSpecificGravity: initial,
      targetSpecificGravity: target,
      waterVolumeLitres: volume,
      labelReferenceSpecificGravity: 1.0255,
      saltGramsPerLitreAtReference: 38.2,
    );

    expect(() => run(initial: 0.5), throwsFormatException);
    expect(() => run(initial: 1.026), throwsFormatException);
    expect(() => run(volume: 0), throwsFormatException);
  });
}
