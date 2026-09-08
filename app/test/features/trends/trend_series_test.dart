import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/trends/domain/trend_series.dart';

void main() {
  TestRecord record({
    required String id,
    required String parameterId,
    required double min,
    double? max,
    required DateTime measuredAt,
  }) {
    return TestRecord(
      id: id,
      tankId: AppDatabase.defaultTankId,
      parameterId: parameterId,
      confirmedMinValue: min,
      confirmedMaxValue: max,
      unit: 'mg/L',
      measuredAt: measuredAt,
      wasManuallyEdited: false,
      createdAt: measuredAt,
      updatedAt: measuredAt,
    );
  }

  test('趋势数据按参数过滤并按检测时间升序排列', () {
    final later = DateTime.utc(2026, 8, 10);
    final earlier = DateTime.utc(2026, 8, 1);
    final series = buildTrendSeries([
      record(
        id: 'later',
        parameterId: AppDatabase.no3Id,
        min: 10,
        measuredAt: later,
      ),
      record(
        id: 'po4',
        parameterId: AppDatabase.po4Id,
        min: 0.03,
        measuredAt: earlier,
      ),
      record(
        id: 'earlier',
        parameterId: AppDatabase.no3Id,
        min: 4,
        measuredAt: earlier,
      ),
    ], AppDatabase.no3Id);

    expect(series.map((item) => item.record.id), ['earlier', 'later']);
  });

  test('旧范围记录保留上下界且不虚构插值', () {
    final series = buildTrendSeries([
      record(
        id: 'range',
        parameterId: AppDatabase.no3Id,
        min: 10,
        max: 20,
        measuredAt: DateTime.utc(2026, 8, 10),
      ),
    ], AppDatabase.no3Id);

    expect(series.single.lower, 10);
    expect(series.single.upper, 20);
    expect(series.single.point, isNull);
  });

  test('图表刻度同时覆盖记录值与用户目标区间', () {
    final measuredAt = DateTime.utc(2026, 8, 10);
    final series = buildTrendSeries([
      record(
        id: 'one',
        parameterId: AppDatabase.no3Id,
        min: 5,
        measuredAt: measuredAt,
      ),
    ], AppDatabase.no3Id);
    final target = WaterQualityTarget(
      id: 'target',
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
      minValue: 1,
      maxValue: 10,
      unit: 'mg/L',
      updatedAt: measuredAt,
    );

    final scale = TrendScale.from(data: series, target: target);
    expect(scale.minimum, lessThanOrEqualTo(1));
    expect(scale.maximum, greaterThanOrEqualTo(10));
  });
}
