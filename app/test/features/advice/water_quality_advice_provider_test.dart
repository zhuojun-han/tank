import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/advice/application/water_quality_advice_provider.dart';
import 'package:lanjiao_water_quality/features/advice/domain/water_quality_advice.dart';

void main() {
  test('选择最新记录且规则只读取人工确认值，不读取算法估值', () {
    final oldTime = DateTime.utc(2026, 8, 1);
    final newTime = DateTime.utc(2026, 8, 10);
    final advice = buildWaterQualityAdvice(
      parameters: [_no3(newTime)],
      records: [
        _record(
          id: 'old',
          measuredAt: oldTime,
          confirmedValue: 20,
          estimatedValue: 20,
        ),
        _record(
          id: 'new',
          measuredAt: newTime,
          confirmedValue: 5,
          estimatedValue: 100,
        ),
      ],
      targets: [
        WaterQualityTarget(
          id: 'target',
          tankId: AppDatabase.defaultTankId,
          parameterId: AppDatabase.no3Id,
          minValue: 4,
          maxValue: 6,
          unit: 'mg/L',
          updatedAt: newTime,
        ),
      ],
    ).single;

    expect(advice.status, WaterQualityAdviceStatus.withinTarget);
    expect(advice.latestConfirmedRecord?.recordId, 'new');
    expect(advice.latestConfirmedRecord?.minValue, 5);
  });
}

WaterParameter _no3(DateTime now) => WaterParameter(
  id: AppDatabase.no3Id,
  code: 'NO3',
  displayName: '硝酸盐',
  unit: 'mg/L',
  isBuiltIn: true,
  photoSupported: true,
  createdAt: now,
);

TestRecord _record({
  required String id,
  required DateTime measuredAt,
  required double confirmedValue,
  required double estimatedValue,
}) => TestRecord(
  id: id,
  tankId: AppDatabase.defaultTankId,
  parameterId: AppDatabase.no3Id,
  estimatedMinValue: estimatedValue,
  estimatedMaxValue: estimatedValue,
  estimationMethod: 'unverified-test-estimate',
  confirmedMinValue: confirmedValue,
  unit: 'mg/L',
  measuredAt: measuredAt,
  wasManuallyEdited: false,
  createdAt: measuredAt,
  updatedAt: measuredAt,
);
