const freshwaterSpecificGravity = 1.0;
const defaultTargetSpecificGravity = 1.025;
const defaultLabelReferenceSpecificGravity = 1.0255;
const defaultSaltGramsPerLitreAtReference = 38.2;

final class SalinityCalculationResult {
  const SalinityCalculationResult({
    required this.initialSpecificGravity,
    required this.effectiveInitialSpecificGravity,
    required this.targetSpecificGravity,
    required this.waterVolumeLitres,
    required this.labelReferenceSpecificGravity,
    required this.saltGramsPerLitreAtReference,
    required this.requiredSaltGrams,
    required this.initialAdditionGrams,
    required this.reservedAdjustmentGrams,
  });

  final double initialSpecificGravity;
  final double effectiveInitialSpecificGravity;
  final double targetSpecificGravity;
  final double waterVolumeLitres;
  final double labelReferenceSpecificGravity;
  final double saltGramsPerLitreAtReference;
  final double requiredSaltGrams;
  final double initialAdditionGrams;
  final double reservedAdjustmentGrams;
}

SalinityCalculationResult calculateSaltMix({
  required double initialSpecificGravity,
  required double targetSpecificGravity,
  required double waterVolumeLitres,
  required double labelReferenceSpecificGravity,
  required double saltGramsPerLitreAtReference,
}) {
  final values = [
    initialSpecificGravity,
    targetSpecificGravity,
    waterVolumeLitres,
    labelReferenceSpecificGravity,
    saltGramsPerLitreAtReference,
  ];
  if (values.any((value) => !value.isFinite)) {
    throw const FormatException('请填写有效数字。');
  }
  if (initialSpecificGravity != 0 &&
      (initialSpecificGravity < freshwaterSpecificGravity ||
          initialSpecificGravity > 1.04)) {
    throw const FormatException('初始比重请填写 0（无盐水），或 1.000–1.040。');
  }
  if (targetSpecificGravity <= freshwaterSpecificGravity ||
      targetSpecificGravity > 1.04) {
    throw const FormatException('目标比重请填写大于 1.000 且不高于 1.040 的数值。');
  }
  if (waterVolumeLitres <= 0) {
    throw const FormatException('水量必须大于 0 L。');
  }
  if (labelReferenceSpecificGravity <= freshwaterSpecificGravity ||
      labelReferenceSpecificGravity > 1.04) {
    throw const FormatException('包装基准比重请填写大于 1.000 且不高于 1.040 的数值。');
  }
  if (saltGramsPerLitreAtReference <= 0 || saltGramsPerLitreAtReference > 100) {
    throw const FormatException('包装标注配盐量请填写大于 0 且不高于 100 g/L 的数值。');
  }

  final effectiveInitial = initialSpecificGravity == 0
      ? freshwaterSpecificGravity
      : initialSpecificGravity;
  if (targetSpecificGravity <= effectiveInitial) {
    throw const FormatException('目标比重必须高于初始比重；降低盐度需要另行计算换水量。');
  }
  final fraction =
      (targetSpecificGravity - effectiveInitial) /
      (labelReferenceSpecificGravity - freshwaterSpecificGravity);
  final required = waterVolumeLitres * saltGramsPerLitreAtReference * fraction;
  final initialAddition = required * 0.9;
  return SalinityCalculationResult(
    initialSpecificGravity: initialSpecificGravity,
    effectiveInitialSpecificGravity: effectiveInitial,
    targetSpecificGravity: targetSpecificGravity,
    waterVolumeLitres: waterVolumeLitres,
    labelReferenceSpecificGravity: labelReferenceSpecificGravity,
    saltGramsPerLitreAtReference: saltGramsPerLitreAtReference,
    requiredSaltGrams: required,
    initialAdditionGrams: initialAddition,
    reservedAdjustmentGrams: required - initialAddition,
  );
}
