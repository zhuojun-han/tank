import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/features/image_estimation/domain/evaluation_metrics.dart';

void main() {
  test('评估统计包含成功、拒绝和严重跨档错误，不筛掉失败案例', () {
    final report = evaluateCases(
      const [
        EvaluationCase(
          id: 'correct',
          batchId: 'batch-a',
          split: EvaluationSplit.validation,
          expectedMinimum: 10,
          expectedMaximum: 25,
          predictionType: EvaluationPredictionType.range,
          predictedMinimum: 10,
          predictedMaximum: 25,
        ),
        EvaluationCase(
          id: 'rejected',
          batchId: 'batch-b',
          split: EvaluationSplit.validation,
          expectedMinimum: 5,
          expectedMaximum: 5,
          predictionType: EvaluationPredictionType.rejected,
        ),
        EvaluationCase(
          id: 'severe',
          batchId: 'batch-c',
          split: EvaluationSplit.validation,
          expectedMinimum: 0,
          expectedMaximum: 0,
          predictionType: EvaluationPredictionType.single,
          predictedMinimum: 50,
          predictedMaximum: 50,
        ),
      ],
      orderedLevels: const [0, 1, 5, 10, 25, 50, 100],
    );

    expect(report.total, 3);
    expect(report.estimated, 2);
    expect(report.rejected, 1);
    expect(report.rangePredictions, 1);
    expect(report.coveringRangePredictions, 1);
    expect(report.singlePredictions, 1);
    expect(report.correctSinglePredictions, 0);
    expect(report.severeErrors, 1);
    expect(report.rejectionRate, closeTo(1 / 3, 0.0001));
  });

  test('拒绝非色卡单档、非相邻范围以及跨调参验证批次泄漏', () {
    const invalidRange = EvaluationCase(
      id: 'wide',
      batchId: 'batch-wide',
      split: EvaluationSplit.validation,
      expectedMinimum: 10,
      expectedMaximum: 25,
      predictionType: EvaluationPredictionType.range,
      predictedMinimum: 0,
      predictedMaximum: 100,
    );
    expect(
      () => evaluateCases(
        const [invalidRange],
        orderedLevels: const [0, 1, 5, 10, 25, 50, 100],
      ),
      throwsArgumentError,
    );

    const leaked = [
      EvaluationCase(
        id: 'tune',
        batchId: 'shared-batch',
        split: EvaluationSplit.tuning,
        expectedMinimum: 10,
        expectedMaximum: 10,
        predictionType: EvaluationPredictionType.rejected,
      ),
      EvaluationCase(
        id: 'validate',
        batchId: 'shared-batch',
        split: EvaluationSplit.validation,
        expectedMinimum: 10,
        expectedMaximum: 10,
        predictionType: EvaluationPredictionType.rejected,
      ),
    ];
    expect(() => auditBatchIsolation(leaked), throwsStateError);
  });

  test('相邻范围只有覆盖完整人工标签才计入覆盖率', () {
    final report = evaluateCases(
      const [
        EvaluationCase(
          id: 'endpoint-only-overlap',
          batchId: 'batch-overlap',
          split: EvaluationSplit.validation,
          expectedMinimum: 10,
          expectedMaximum: 25,
          predictionType: EvaluationPredictionType.range,
          predictedMinimum: 5,
          predictedMaximum: 10,
        ),
      ],
      orderedLevels: const [0, 1, 5, 10, 25, 50, 100],
    );

    expect(report.rangePredictions, 1);
    expect(report.coveringRangePredictions, 0);
    expect(report.adjacentRangeCoverage, 0);
  });

  test('评估档位必须由调用方按色卡顺序严格递增提供', () {
    expect(
      () => evaluateCases(const [], orderedLevels: const [0, 10, 5, 25]),
      throwsArgumentError,
    );
  });
}
