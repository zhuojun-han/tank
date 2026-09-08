enum EvaluationPredictionType { single, range, rejected }

enum EvaluationSplit { tuning, validation, unassigned }

class EvaluationCase {
  const EvaluationCase({
    required this.id,
    required this.batchId,
    required this.split,
    required this.expectedMinimum,
    required this.expectedMaximum,
    required this.predictionType,
    this.predictedMinimum,
    this.predictedMaximum,
  });

  final String id;
  final String batchId;
  final EvaluationSplit split;
  final double expectedMinimum;
  final double expectedMaximum;
  final EvaluationPredictionType predictionType;
  final double? predictedMinimum;
  final double? predictedMaximum;
}

class EvaluationReport {
  const EvaluationReport({
    required this.total,
    required this.estimated,
    required this.rejected,
    required this.singlePredictions,
    required this.correctSinglePredictions,
    required this.rangePredictions,
    required this.coveringRangePredictions,
    required this.severeErrors,
  });

  final int total;
  final int estimated;
  final int rejected;
  final int singlePredictions;
  final int correctSinglePredictions;
  final int rangePredictions;
  final int coveringRangePredictions;
  final int severeErrors;

  double? get estimationRate => total == 0 ? null : estimated / total;
  double? get rejectionRate => total == 0 ? null : rejected / total;
  double? get singleAccuracy => singlePredictions == 0
      ? null
      : correctSinglePredictions / singlePredictions;
  double? get adjacentRangeCoverage => rangePredictions == 0
      ? null
      : coveringRangePredictions / rangePredictions;

  /// Serious errors divided by every validation case, including rejections.
  double? get severeErrorRateAllCases =>
      total == 0 ? null : severeErrors / total;

  double? get severeErrorRateAmongEstimated =>
      estimated == 0 ? null : severeErrors / estimated;
}

EvaluationReport evaluateCases(
  List<EvaluationCase> cases, {
  required List<double> orderedLevels,
  EvaluationSplit split = EvaluationSplit.validation,
}) {
  final levels = _validateLevels(orderedLevels);
  auditBatchIsolation(cases);
  final selected = cases.where((item) => item.split == split).toList();
  var estimated = 0;
  var rejected = 0;
  var singlePredictions = 0;
  var correctSingles = 0;
  var rangePredictions = 0;
  var coveringRanges = 0;
  var severe = 0;
  final seenIds = <String>{};
  for (final item in selected) {
    if (!seenIds.add(item.id) || item.id.trim().isEmpty) {
      throw ArgumentError('样本 ID 为空或重复：${item.id}');
    }
    if (item.batchId.trim().isEmpty) throw ArgumentError('样本批次不能为空');
    _validateGroundTruth(item, levels);
    if (item.predictionType == EvaluationPredictionType.rejected) {
      if (item.predictedMinimum != null || item.predictedMaximum != null) {
        throw ArgumentError('拒绝结果不能携带预测数值：${item.id}');
      }
      rejected++;
      continue;
    }
    final low = item.predictedMinimum;
    final high = item.predictedMaximum;
    if (low == null || high == null) {
      throw ArgumentError('样本 ${item.id} 的预测范围缺失');
    }
    _validatePrediction(item, low, high, levels);
    estimated++;
    final overlaps =
        high >= item.expectedMinimum && low <= item.expectedMaximum;
    if (item.predictionType == EvaluationPredictionType.single) {
      singlePredictions++;
      if (overlaps) correctSingles++;
    } else {
      rangePredictions++;
      // "Coverage" means the reported adjacent range contains the complete
      // human-labelled single/range result. Mere endpoint overlap would make
      // a neighbouring-but-wrong range look successful.
      final coversGroundTruth =
          low <= item.expectedMinimum && high >= item.expectedMaximum;
      if (coversGroundTruth) coveringRanges++;
    }
    if (!overlaps && _isSevere(item, low, high, levels)) severe++;
  }
  return EvaluationReport(
    total: selected.length,
    estimated: estimated,
    rejected: rejected,
    singlePredictions: singlePredictions,
    correctSinglePredictions: correctSingles,
    rangePredictions: rangePredictions,
    coveringRangePredictions: coveringRanges,
    severeErrors: severe,
  );
}

void auditBatchIsolation(List<EvaluationCase> cases) {
  final assignedSplitByBatch = <String, EvaluationSplit>{};
  for (final item in cases) {
    if (item.split == EvaluationSplit.unassigned) continue;
    final existing = assignedSplitByBatch[item.batchId];
    if (existing != null && existing != item.split) {
      throw StateError('批次 ${item.batchId} 同时出现在调参与验证集');
    }
    assignedSplitByBatch[item.batchId] = item.split;
  }
}

List<double> _validateLevels(List<double> source) {
  if (source.length < 2) throw ArgumentError('至少需要两个有序档位');
  final levels = [...source];
  for (var index = 0; index < levels.length; index++) {
    final value = levels[index];
    if (!value.isFinite ||
        value < 0 ||
        (index > 0 && levels[index - 1] >= value)) {
      throw ArgumentError('色卡档位必须严格递增且为非负有限数');
    }
  }
  return levels;
}

void _validateGroundTruth(EvaluationCase item, List<double> levels) {
  final lowIndex = levels.indexOf(item.expectedMinimum);
  final highIndex = levels.indexOf(item.expectedMaximum);
  if (lowIndex < 0 ||
      highIndex < 0 ||
      highIndex < lowIndex ||
      highIndex - lowIndex > 1) {
    throw ArgumentError('样本 ${item.id} 的人工标签必须是单档或相邻档范围');
  }
}

void _validatePrediction(
  EvaluationCase item,
  double low,
  double high,
  List<double> levels,
) {
  if (!low.isFinite || !high.isFinite || low < 0 || high < low) {
    throw ArgumentError('样本 ${item.id} 的预测范围无效');
  }
  final lowIndex = levels.indexOf(low);
  final highIndex = levels.indexOf(high);
  if (lowIndex < 0 || highIndex < 0) {
    throw ArgumentError('样本 ${item.id} 的预测必须来自色卡档位');
  }
  switch (item.predictionType) {
    case EvaluationPredictionType.single:
      if (lowIndex != highIndex) {
        throw ArgumentError('单档预测的上下界必须相同：${item.id}');
      }
      break;
    case EvaluationPredictionType.range:
      if (highIndex - lowIndex != 1) {
        throw ArgumentError('范围预测必须由两个相邻档位构成：${item.id}');
      }
      break;
    case EvaluationPredictionType.rejected:
      throw StateError('拒绝结果不应进入预测校验');
  }
}

bool _isSevere(
  EvaluationCase item,
  double low,
  double high,
  List<double> levels,
) {
  final expectedLow = levels.indexOf(item.expectedMinimum);
  final expectedHigh = levels.indexOf(item.expectedMaximum);
  final predictedLow = levels.indexOf(low);
  final predictedHigh = levels.indexOf(high);
  final gap = predictedLow > expectedHigh
      ? predictedLow - expectedHigh
      : expectedLow - predictedHigh;
  return gap > 1;
}
