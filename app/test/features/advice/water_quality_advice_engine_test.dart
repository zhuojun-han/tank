import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/features/advice/domain/water_quality_advice.dart';

void main() {
  group('WaterQualityAdviceEngine', () {
    test('NO3 高于目标时给出文档中的渐进维护检查项', () {
      final advice = WaterQualityAdviceEngine.evaluate(
        _input(code: 'NO3', value: 25, targetMin: 2, targetMax: 10),
      );

      expect(advice.status, WaterQualityAdviceStatus.aboveTarget);
      expect(advice.title, 'NO3 高于目标');
      expect(advice.actions, contains('采用适量分次换水，避免骤降'));
      expect(
        advice.sources.map((item) => item.title),
        contains(startsWith('Red Sea')),
      );
    });

    test('NO3 低于目标时不建议盲目添加药剂', () {
      final advice = WaterQualityAdviceEngine.evaluate(
        _input(code: 'NO3', value: 1, targetMin: 2, targetMax: 10),
      );

      expect(advice.status, WaterQualityAdviceStatus.belowTarget);
      expect(advice.actions, contains('不要盲目添加硝酸盐药剂'));
    });

    test('PO4 高于和低于目标使用各自有来源的规则', () {
      final high = WaterQualityAdviceEngine.evaluate(
        _input(code: 'PO4', value: 0.2, targetMin: 0.02, targetMax: 0.08),
      );
      final low = WaterQualityAdviceEngine.evaluate(
        _input(code: 'PO4', value: 0.01, targetMin: 0.02, targetMax: 0.08),
      );

      expect(high.status, WaterQualityAdviceStatus.aboveTarget);
      expect(high.actions, contains('按产品说明检查或更换吸磷材料'));
      expect(low.status, WaterQualityAdviceStatus.belowTarget);
      expect(low.actions, contains('不要盲目添加磷酸盐'));
      expect(
        high.sources.map((item) => item.title),
        contains(startsWith('Tropic Marin · Nutrient Control')),
      );
    });

    test('单值位于用户目标内时只建议维持和复测', () {
      final advice = WaterQualityAdviceEngine.evaluate(
        _input(code: 'NO3', value: 5, targetMin: 2, targetMax: 10),
      );

      expect(advice.status, WaterQualityAdviceStatus.withinTarget);
      expect(advice.title, 'NO3 位于目标范围内');
      expect(advice.actions, ['保持当前喂食、过滤和维护节奏', '按原计划复测并持续观察']);
    });

    test('范围结果部分重叠时只提示复测，不判定高低', () {
      final advice = WaterQualityAdviceEngine.evaluate(
        _input(
          code: 'NO3',
          value: 8,
          maxValue: 15,
          targetMin: 5,
          targetMax: 10,
        ),
      );

      expect(advice.status, WaterQualityAdviceStatus.retestRequired);
      expect(advice.title, 'NO3 需要复测确认');
      expect(advice.summary, contains('不能判定偏高或偏低'));
      expect(advice.actions.join(), isNot(contains('减少喂食')));
    });

    test('缺少人工确认记录或用户目标时明确标为数据不足', () {
      final noRecord = WaterQualityAdviceEngine.evaluate(
        const WaterQualityAdviceInput(
          parameterId: 'no3',
          parameterCode: 'NO3',
          parameterName: '硝酸盐',
          userTarget: UserTargetRange(minValue: 2, maxValue: 10, unit: 'mg/L'),
        ),
      );
      final noTarget = WaterQualityAdviceEngine.evaluate(
        WaterQualityAdviceInput(
          parameterId: 'no3',
          parameterCode: 'NO3',
          parameterName: '硝酸盐',
          latestConfirmedRecord: _record(5),
        ),
      );

      expect(noRecord.status, WaterQualityAdviceStatus.insufficientData);
      expect(noRecord.trigger, contains('尚无'));
      expect(noTarget.status, WaterQualityAdviceStatus.insufficientData);
      expect(noTarget.title, 'NO3 尚未设置目标');
      expect(noTarget.summary, contains('不会套用所谓通用最佳值'));
    });

    test('NO3/PO4 之外不生成没有来源的方向性维护建议', () {
      final advice = WaterQualityAdviceEngine.evaluate(
        _input(code: 'KH', value: 12, targetMin: 7, targetMax: 9),
      );

      expect(advice.status, WaterQualityAdviceStatus.unsupportedParameter);
      expect(advice.sources, isEmpty);
      expect(advice.actions, ['规范复测并持续观察', '查阅可靠资料或咨询有经验的专业人士']);
    });

    test('无效记录不会触发方向性维护建议', () {
      final advice = WaterQualityAdviceEngine.evaluate(
        _input(code: 'NO3', value: double.nan, targetMin: 2, targetMax: 10),
      );

      expect(advice.status, WaterQualityAdviceStatus.insufficientData);
      expect(advice.title, 'NO3 记录需要复核');
    });
  });
}

WaterQualityAdviceInput _input({
  required String code,
  required double value,
  double? maxValue,
  required double targetMin,
  required double targetMax,
}) => WaterQualityAdviceInput(
  parameterId: code.toLowerCase(),
  parameterCode: code,
  parameterName: code,
  latestConfirmedRecord: _record(value, maxValue: maxValue),
  userTarget: UserTargetRange(
    minValue: targetMin,
    maxValue: targetMax,
    unit: 'mg/L',
  ),
);

ConfirmedMeasurement _record(double value, {double? maxValue}) =>
    ConfirmedMeasurement(
      recordId: 'record',
      minValue: value,
      maxValue: maxValue,
      unit: 'mg/L',
      measuredAt: DateTime.utc(2026, 8, 10),
    );
