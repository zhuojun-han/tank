import 'dart:math' as math;

const minimumTargetPo4MgL = 0.03;
const minimumDailyPo4DropMgL = 0.1;
const maximumDailyPo4DropMgL = 0.5;
const planStockFinalVolumeMl = 500.0;
const dailyDilutionFinalVolumeMl = 500.0;
const stockPo4RemovalMgPerMl = 10.0;
const po4MolarMassGPerMol = 94.971;
const lanthanumChlorideHeptahydrateMolarMassGPerMol = 371.37;
const lanthanumChloridePurityPercent = 99.9;
const maximumPlanDays = 3650;

final class LanthanumPlanDay {
  const LanthanumPlanDay({
    required this.day,
    required this.startingPo4MgL,
    required this.theoreticalPo4DropMgL,
    required this.endingPo4MgL,
    required this.stockToUseMl,
    required this.rodiToFinalVolumeMl,
  });

  final int day;
  final double startingPo4MgL;
  final double theoreticalPo4DropMgL;
  final double endingPo4MgL;
  final double stockToUseMl;
  final double rodiToFinalVolumeMl;
}

final class LanthanumPlan {
  const LanthanumPlan({
    required this.currentPo4MgL,
    required this.targetPo4MgL,
    required this.netWaterVolumeL,
    required this.maxDailyPo4DropMgL,
    required this.solidMassToWeighG,
    required this.stockConcentrationMgPerMl,
    required this.totalStockRequiredMl,
    required this.dailyPlan,
    this.stockFinalVolumeMl = planStockFinalVolumeMl,
  });

  final double currentPo4MgL;
  final double targetPo4MgL;
  final double netWaterVolumeL;
  final double maxDailyPo4DropMgL;
  final double solidMassToWeighG;
  final double stockConcentrationMgPerMl;
  final double totalStockRequiredMl;
  final List<LanthanumPlanDay> dailyPlan;
  final double stockFinalVolumeMl;
  int get stockBatchesRequired =>
      (totalStockRequiredMl / stockFinalVolumeMl).ceil();

  int get days => dailyPlan.length;
}

LanthanumPlan calculateLanthanumPlan({
  required double currentPo4MgL,
  required double targetPo4MgL,
  required double netWaterVolumeL,
  required double maxDailyPo4DropMgL,
  double stockFinalVolumeMl = planStockFinalVolumeMl,
}) {
  if (!stockFinalVolumeMl.isFinite || stockFinalVolumeMl <= 0) {
    throw const FormatException('母液最终体积必须是大于 0 的有限数值。');
  }
  if (!currentPo4MgL.isFinite || currentPo4MgL <= 0) {
    throw const FormatException('当前 PO4 必须是大于 0 的有限数值。');
  }
  if (!targetPo4MgL.isFinite || targetPo4MgL < minimumTargetPo4MgL) {
    throw const FormatException('目标 PO4 不能低于 0.03 mg/L。');
  }
  if (targetPo4MgL >= currentPo4MgL) {
    throw const FormatException('目标 PO4 必须低于当前 PO4。');
  }
  if (!netWaterVolumeL.isFinite || netWaterVolumeL <= 0) {
    throw const FormatException('净水量必须是大于 0 的有限数值。');
  }
  if (!maxDailyPo4DropMgL.isFinite ||
      maxDailyPo4DropMgL < minimumDailyPo4DropMgL ||
      maxDailyPo4DropMgL > maximumDailyPo4DropMgL) {
    throw const FormatException('计划单日降幅必须在 0.1–0.5 mg/L 之间。');
  }

  final totalDrop = currentPo4MgL - targetPo4MgL;
  final totalPo4MassMg = totalDrop * netWaterVolumeL;
  final stockPureSaltMassGPerMl =
      (stockPo4RemovalMgPerMl / 1000 / po4MolarMassGPerMol) *
      lanthanumChlorideHeptahydrateMolarMassGPerMol;
  final stockConcentrationMgPerMl =
      stockPureSaltMassGPerMl / (lanthanumChloridePurityPercent / 100) * 1000;
  final solidMassToWeighG =
      stockConcentrationMgPerMl * stockFinalVolumeMl / 1000;
  final totalStockRequiredMl = totalPo4MassMg / stockPo4RemovalMgPerMl;
  if (!(totalDrop / maxDailyPo4DropMgL).isFinite ||
      !solidMassToWeighG.isFinite ||
      !totalStockRequiredMl.isFinite ||
      !(totalStockRequiredMl / stockFinalVolumeMl).isFinite) {
    throw const FormatException('计算超出数值范围，请核对输入。');
  }
  final days = math.max(1, (totalDrop / maxDailyPo4DropMgL - 1e-12).ceil());
  if (days > maximumPlanDays) {
    throw const FormatException('计划超过 3650 天，请核对输入单位。');
  }

  var remainingDrop = totalDrop;
  var startingPo4 = currentPo4MgL;
  final dailyPlan = <LanthanumPlanDay>[];
  for (var index = 0; index < days; index += 1) {
    final day = index + 1;
    final isLast = day == days;
    final drop = isLast
        ? remainingDrop
        : math.min(maxDailyPo4DropMgL, remainingDrop);
    final stockMl = drop * netWaterVolumeL / stockPo4RemovalMgPerMl;
    if (stockMl > dailyDilutionFinalVolumeMl) {
      throw const FormatException('当日母液用量超过 500 mL 工作液容量，请降低单日降幅。');
    }
    final endingPo4 = isLast ? targetPo4MgL : startingPo4 - drop;
    dailyPlan.add(
      LanthanumPlanDay(
        day: day,
        startingPo4MgL: startingPo4,
        theoreticalPo4DropMgL: drop,
        endingPo4MgL: endingPo4,
        stockToUseMl: stockMl,
        rodiToFinalVolumeMl: dailyDilutionFinalVolumeMl - stockMl,
      ),
    );
    remainingDrop -= drop;
    startingPo4 = endingPo4;
  }
  return LanthanumPlan(
    stockFinalVolumeMl: stockFinalVolumeMl,
    currentPo4MgL: currentPo4MgL,
    targetPo4MgL: targetPo4MgL,
    netWaterVolumeL: netWaterVolumeL,
    maxDailyPo4DropMgL: maxDailyPo4DropMgL,
    solidMassToWeighG: solidMassToWeighG,
    stockConcentrationMgPerMl: stockConcentrationMgPerMl,
    totalStockRequiredMl: totalStockRequiredMl,
    dailyPlan: List.unmodifiable(dailyPlan),
  );
}
