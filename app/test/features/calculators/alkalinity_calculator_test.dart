import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/alkalinity_calculator.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/lanthanum_calculator.dart';

void main() {
  test('KH 默认计划和网页版数值一致，净提升与消耗分列', () {
    final p = calculateAlkalinityPlan(currentDkh: 6.5, targetDkh: 8);
    expect(p.days, 3);
    expect(p.solidMassToWeighG, closeTo(25.002083333, 1e-8));
    expect(p.totalStockRequiredMl, closeTo(360, 1e-8));
    expect(p.dailyPlan.first.netRise, 0.5);
    expect(p.dailyPlan.first.consumption, 0.5);
    expect(p.dailyPlan.first.stockMl, 120);
    expect(p.dailyPlan.last.endingDkh, 8);
    final larger = calculateAlkalinityPlan(
      currentDkh: 6.5,
      targetDkh: 8,
      stockFinalVolumeMl: 1000,
    );
    expect(larger.solidMassToWeighG, closeTo(p.solidMassToWeighG * 2, 1e-8));
    expect(larger.totalStockRequiredMl, p.totalStockRequiredMl);
  });
  test('KH 插值、低温过浓、纯度、有限天数和非有限输入', () {
    expect(sodiumBicarbonateSolubilityAt(5), closeTo(7, 1e-8));
    expect(
      () => calculateAlkalinityPlan(
        currentDkh: 6,
        targetDkh: 8,
        stockMlPerPointOne: 5,
      ),
      throwsFormatException,
    );
    expect(
      () => calculateAlkalinityPlan(
        currentDkh: 6,
        targetDkh: 8,
        purityPercent: 50,
      ),
      throwsFormatException,
    );
    expect(
      () => calculateAlkalinityPlan(
        currentDkh: 6,
        targetDkh: 8,
        stockTemperatureC: -1,
      ),
      throwsFormatException,
    );
    expect(
      () => calculateAlkalinityPlan(currentDkh: 6, targetDkh: 5000),
      throwsFormatException,
    );
    expect(
      () => calculateAlkalinityPlan(currentDkh: double.nan, targetDkh: 8),
      throwsFormatException,
    );
    final p = calculateAlkalinityPlan(
      currentDkh: 6.5,
      targetDkh: 8,
      dailyDkhConsumption: 0,
      stockFinalVolumeMl: 50,
    );
    expect(p.totalStockRequiredMl, closeTo(180, 1e-8));
    expect(p.stockBatchesRequired, 4);
    expect(p.stockShortfallMl, closeTo(130, 1e-8));
  });
  test('PO4 母液体积只改变称量与批数，不改变分日剂量', () {
    final p = calculateLanthanumPlan(
      currentPo4MgL: 0.23,
      targetPo4MgL: 0.03,
      netWaterVolumeL: 200,
      maxDailyPo4DropMgL: 0.1,
    );
    final q = calculateLanthanumPlan(
      currentPo4MgL: 0.23,
      targetPo4MgL: 0.03,
      netWaterVolumeL: 200,
      maxDailyPo4DropMgL: 0.1,
      stockFinalVolumeMl: 1000,
    );
    expect(q.solidMassToWeighG, closeTo(p.solidMassToWeighG * 2, 1e-8));
    expect(q.totalStockRequiredMl, p.totalStockRequiredMl);
    expect(q.dailyPlan.first.stockToUseMl, p.dailyPlan.first.stockToUseMl);
    expect(
      () => calculateLanthanumPlan(
        currentPo4MgL: 0.23,
        targetPo4MgL: 0.03,
        netWaterVolumeL: 200,
        maxDailyPo4DropMgL: 0.1,
        stockFinalVolumeMl: 0,
      ),
      throwsFormatException,
    );
  });
}
