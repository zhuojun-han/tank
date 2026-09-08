import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/lanthanum_calculator.dart';

void main() {
  test('固定母液保持 1 mL 处理 10 mg PO4 的化学计量', () {
    final plan = calculateLanthanumPlan(
      currentPo4MgL: 0.23,
      targetPo4MgL: 0.03,
      netWaterVolumeL: 200,
      maxDailyPo4DropMgL: 0.1,
    );

    expect(plan.solidMassToWeighG, closeTo(19.571329, 0.000001));
    expect(plan.days, 2);
    expect(plan.totalStockRequiredMl, closeTo(4, 1e-9));
    expect(plan.dailyPlan.first.stockToUseMl, closeTo(2, 1e-9));
    expect(plan.dailyPlan.last.endingPo4MgL, closeTo(0.03, 1e-12));
  });

  test('最后一天只使用剩余理论份额', () {
    final plan = calculateLanthanumPlan(
      currentPo4MgL: 0.28,
      targetPo4MgL: 0.03,
      netWaterVolumeL: 200,
      maxDailyPo4DropMgL: 0.1,
    );
    expect(plan.days, 3);
    expect(plan.dailyPlan.last.theoreticalPo4DropMgL, closeTo(0.05, 1e-12));
    expect(plan.dailyPlan.last.stockToUseMl, closeTo(1, 1e-9));
  });

  test('拒绝低于目标下限和范围外单日降幅', () {
    LanthanumPlan run({double target = 0.03, double daily = 0.1}) =>
        calculateLanthanumPlan(
          currentPo4MgL: 0.2,
          targetPo4MgL: target,
          netWaterVolumeL: 200,
          maxDailyPo4DropMgL: daily,
        );
    expect(() => run(target: 0.02), throwsFormatException);
    expect(() => run(daily: 0.6), throwsFormatException);
  });
}
