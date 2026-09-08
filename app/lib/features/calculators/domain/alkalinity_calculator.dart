import 'dart:math' as math;

/// Same nahco3-dkh-stock-v2 model as web-demo/app/alkalinity-calculator.ts.
/// Sources and limits: docs/SODIUM_BICARBONATE_KH_CALCULATOR.md.
const gramsPurePer100LPerDkh = 100 / 2.8 / 1000 * 84.007;
const alkalinityStockMlOptions = [4, 6, 8, 10];

class AlkalinityPlanDay {
  const AlkalinityPlanDay(
    this.day,
    this.startingDkh,
    this.netRise,
    this.consumption,
    this.endingDkh,
    this.stockMl,
  );
  final int day;
  final double startingDkh, netRise, consumption, endingDkh, stockMl;
  double get doseDkh => netRise + consumption;
  double get postDoseDkh => startingDkh + doseDkh;
}

class AlkalinityPlan {
  const AlkalinityPlan({
    required this.currentDkh,
    required this.targetDkh,
    required this.netWaterVolumeL,
    required this.purityPercent,
    required this.maxDailyDkhRise,
    required this.dailyDkhConsumption,
    required this.stockFinalVolumeMl,
    required this.stockMlPerPointOne,
    required this.stockTemperatureC,
    required this.stockConcentrationGPerL,
    required this.conservativeLimitGPerL,
    required this.dailyPlan,
  });
  final double currentDkh,
      targetDkh,
      netWaterVolumeL,
      purityPercent,
      maxDailyDkhRise,
      dailyDkhConsumption;
  final double stockFinalVolumeMl,
      stockTemperatureC,
      stockConcentrationGPerL,
      conservativeLimitGPerL;
  final int stockMlPerPointOne;
  final List<AlkalinityPlanDay> dailyPlan;
  int get days => dailyPlan.length;
  double get solidMassToWeighG =>
      stockConcentrationGPerL * stockFinalVolumeMl / 1000;
  double get totalStockRequiredMl =>
      dailyPlan.fold(0, (sum, day) => sum + day.stockMl);
  int get stockBatchesRequired =>
      (totalStockRequiredMl / stockFinalVolumeMl).ceil();
  double get stockShortfallMl =>
      math.max(0, totalStockRequiredMl - stockFinalVolumeMl);
}

double sodiumBicarbonateSolubilityAt(double temperature) {
  if (!temperature.isFinite || temperature < 0 || temperature > 40) {
    throw const FormatException('母液最低温度必须在 0–40°C 之间。');
  }
  const points = [6.4, 7.6, 8.7, 10.0, 11.3]; // g / 100 g solution
  final index = (temperature / 10).floor();
  if (index == 4) return points[4];
  return points[index] +
      (points[index + 1] - points[index]) * (temperature / 10 - index);
}

AlkalinityPlan calculateAlkalinityPlan({
  required double currentDkh,
  required double targetDkh,
  double netWaterVolumeL = 200,
  double purityPercent = 100,
  double maxDailyDkhRise = 0.5,
  double dailyDkhConsumption = 0.5,
  double stockFinalVolumeMl = 500,
  int stockMlPerPointOne = 6,
  double stockTemperatureC = 0,
}) {
  if (!currentDkh.isFinite ||
      currentDkh < 0 ||
      !targetDkh.isFinite ||
      targetDkh <= currentDkh) {
    throw const FormatException('当前 KH 必须非负，目标 KH 必须高于当前值。');
  }
  if (!netWaterVolumeL.isFinite ||
      netWaterVolumeL <= 0 ||
      !purityPercent.isFinite ||
      purityPercent <= 0 ||
      purityPercent > 100) {
    throw const FormatException('净水量须大于 0，包装纯度须大于 0 且不超过 100%。');
  }
  if (!maxDailyDkhRise.isFinite ||
      maxDailyDkhRise < 0.1 ||
      maxDailyDkhRise > 1) {
    throw const FormatException('计划单日净升幅必须在 0.1–1.0 dKH 之间。');
  }
  if (!dailyDkhConsumption.isFinite ||
      dailyDkhConsumption < 0 ||
      !stockFinalVolumeMl.isFinite ||
      stockFinalVolumeMl <= 0 ||
      !alkalinityStockMlOptions.contains(stockMlPerPointOne)) {
    throw const FormatException('每日消耗须非负，母液体积须大于 0，强度请选择 4/6/8/10 mL 档位。');
  }
  final limit = sodiumBicarbonateSolubilityAt(stockTemperatureC) * 10 * 0.8;
  final concentration =
      gramsPurePer100LPerDkh *
      0.1 *
      1000 /
      stockMlPerPointOne /
      (purityPercent / 100);
  if (concentration > limit + 1e-12) {
    throw FormatException(
      '该配方需 ${concentration.toStringAsFixed(3)} g/L，超过最低温度下采用 20% 余量的 ${limit.toStringAsFixed(3)} g/L 上限；请选择更大的毫升档位。',
    );
  }
  final count = (targetDkh - currentDkh) / maxDailyDkhRise;
  if (!count.isFinite || count > 3650 + 1e-12) {
    throw const FormatException('计划超过 3650 天，请核对单位。');
  }
  final days = math.max(1, (count - 1e-12).ceil());
  var remaining = targetDkh - currentDkh;
  var starting = currentDkh;
  final schedule = <AlkalinityPlanDay>[];
  for (var i = 1; i <= days; i++) {
    final rise = i == days ? remaining : math.min(maxDailyDkhRise, remaining);
    final dose = rise + dailyDkhConsumption;
    final ml = dose * (netWaterVolumeL / 100) / (0.1 / stockMlPerPointOne);
    if (!ml.isFinite) throw const FormatException('计算超出数值范围，请核对输入。');
    final ending = i == days ? targetDkh : starting + rise;
    schedule.add(
      AlkalinityPlanDay(i, starting, rise, dailyDkhConsumption, ending, ml),
    );
    remaining -= rise;
    starting = ending;
  }
  final plan = AlkalinityPlan(
    currentDkh: currentDkh,
    targetDkh: targetDkh,
    netWaterVolumeL: netWaterVolumeL,
    purityPercent: purityPercent,
    maxDailyDkhRise: maxDailyDkhRise,
    dailyDkhConsumption: dailyDkhConsumption,
    stockFinalVolumeMl: stockFinalVolumeMl,
    stockMlPerPointOne: stockMlPerPointOne,
    stockTemperatureC: stockTemperatureC,
    stockConcentrationGPerL: concentration,
    conservativeLimitGPerL: limit,
    dailyPlan: List.unmodifiable(schedule),
  );
  if (!plan.solidMassToWeighG.isFinite ||
      !plan.totalStockRequiredMl.isFinite ||
      !(plan.totalStockRequiredMl / stockFinalVolumeMl).isFinite) {
    throw const FormatException('计算超出数值范围，请核对输入。');
  }
  return plan;
}
