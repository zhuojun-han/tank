import 'dart:convert';

enum No3DatasetSplit { tuning, validation, unassigned }

class No3DatasetLabel {
  const No3DatasetLabel({required this.minimum, required this.maximum});

  final double minimum;
  final double maximum;
}

class No3DatasetSample {
  const No3DatasetSample({
    required this.id,
    required this.batchId,
    required this.split,
    required this.imagePath,
    required this.sha256,
    required this.width,
    required this.height,
    required this.label,
    required this.regionsAnnotated,
    required this.eligibleForFinalEvaluation,
    required this.exclusionReasons,
    this.reagentLot,
    this.cardVersion,
    this.device,
    this.lighting,
    this.capturedAt,
  });

  final String id;
  final String batchId;
  final No3DatasetSplit split;
  final String imagePath;
  final String sha256;
  final int width;
  final int height;
  final No3DatasetLabel label;
  final String? reagentLot;
  final String? cardVersion;
  final String? device;
  final String? lighting;
  final DateTime? capturedAt;
  final bool regionsAnnotated;
  final bool eligibleForFinalEvaluation;
  final List<String> exclusionReasons;
}

class No3DatasetManifest {
  const No3DatasetManifest({
    required this.schemaVersion,
    required this.datasetId,
    required this.parameter,
    required this.unit,
    required this.reagentBrand,
    required this.supportedLevels,
    required this.splitRule,
    required this.samples,
  });

  final int schemaVersion;
  final String datasetId;
  final String parameter;
  final String unit;
  final String reagentBrand;
  final List<double> supportedLevels;
  final String splitRule;
  final List<No3DatasetSample> samples;

  int get validationSampleCount => samples
      .where((sample) => sample.split == No3DatasetSplit.validation)
      .length;

  int get eligibleValidationSampleCount => samples
      .where(
        (sample) =>
            sample.split == No3DatasetSplit.validation &&
            sample.eligibleForFinalEvaluation,
      )
      .length;
}

No3DatasetManifest parseNo3DatasetManifest(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('NO3 数据清单根节点必须是对象');
  }
  final schemaVersion = _requiredInt(decoded, 'schemaVersion');
  if (schemaVersion != 1) {
    throw FormatException('不支持的 NO3 数据清单版本：$schemaVersion');
  }
  final levels = _requiredList(decoded, 'supportedLevels')
      .map((value) {
        if (value is! num || !value.toDouble().isFinite || value < 0) {
          throw const FormatException('supportedLevels 必须是非负有限数');
        }
        return value.toDouble();
      })
      .toList(growable: false);
  if (levels.length < 2) {
    throw const FormatException('supportedLevels 至少需要两个档位');
  }
  for (var index = 0; index < levels.length; index++) {
    if (index > 0 && levels[index] <= levels[index - 1]) {
      throw const FormatException('supportedLevels 必须严格递增且不重复');
    }
  }

  final samples = <No3DatasetSample>[];
  final ids = <String>{};
  final contentHashes = <String>{};
  final splitByBatch = <String, No3DatasetSplit>{};
  for (final raw in _requiredList(decoded, 'samples')) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('samples 条目必须是对象');
    }
    final id = _requiredString(raw, 'id');
    if (!ids.add(id)) throw FormatException('样本 ID 重复：$id');
    final batchId = _requiredString(raw, 'batchId');
    final split = switch (_requiredString(raw, 'split')) {
      'tuning' => No3DatasetSplit.tuning,
      'validation' => No3DatasetSplit.validation,
      'unassigned' => No3DatasetSplit.unassigned,
      final value => throw FormatException('样本 $id 的 split 无效：$value'),
    };
    if (split != No3DatasetSplit.unassigned) {
      final previous = splitByBatch[batchId];
      if (previous != null && previous != split) {
        throw FormatException('批次 $batchId 同时出现在调参与验证集');
      }
      splitByBatch[batchId] = split;
    }
    final imagePath = _requiredString(raw, 'imagePath').replaceAll('\\', '/');
    if (imagePath.startsWith('/') ||
        RegExp(r'^[A-Za-z]:/').hasMatch(imagePath)) {
      throw FormatException('样本 $id 必须使用相对图片路径');
    }
    final sha = _requiredString(raw, 'sha256').toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) {
      throw FormatException('样本 $id 的 SHA-256 无效');
    }
    if (!contentHashes.add(sha)) {
      throw FormatException('样本 $id 与清单中其他图片内容重复');
    }
    final labelMap = raw['label'];
    if (labelMap is! Map<String, dynamic>) {
      throw FormatException('样本 $id 缺少人工标签');
    }
    final minimum = _requiredNumber(labelMap, 'minimum');
    final maximum = _requiredNumber(labelMap, 'maximum');
    final lowIndex = levels.indexOf(minimum);
    final highIndex = levels.indexOf(maximum);
    if (lowIndex < 0 || highIndex < lowIndex || highIndex - lowIndex > 1) {
      throw FormatException('样本 $id 的人工标签必须是单档或相邻档范围');
    }
    final annotated = _requiredBool(raw, 'regionsAnnotated');
    final eligible = _requiredBool(raw, 'eligibleForFinalEvaluation');
    final reasons = _requiredList(raw, 'exclusionReasons')
        .map((value) {
          if (value is! String || value.trim().isEmpty) {
            throw FormatException('样本 $id 的排除原因无效');
          }
          return value.trim();
        })
        .toList(growable: false);
    final reagentLot = _optionalString(raw, 'reagentLot');
    final cardVersion = _optionalString(raw, 'cardVersion');
    final device = _optionalString(raw, 'device');
    final lighting = _optionalString(raw, 'lighting');
    final capturedAt = _optionalDateTime(raw, 'capturedAt');
    if (eligible) {
      if (split != No3DatasetSplit.validation ||
          !annotated ||
          reagentLot == null ||
          cardVersion == null ||
          device == null ||
          lighting == null ||
          capturedAt == null ||
          reasons.isNotEmpty) {
        throw FormatException('样本 $id 不满足最终验证资格却被标为 eligible');
      }
    } else if (reasons.isEmpty) {
      throw FormatException('不可进入最终验证的样本 $id 必须说明排除原因');
    }
    samples.add(
      No3DatasetSample(
        id: id,
        batchId: batchId,
        split: split,
        imagePath: imagePath,
        sha256: sha,
        width: _positiveInt(raw, 'width'),
        height: _positiveInt(raw, 'height'),
        label: No3DatasetLabel(minimum: minimum, maximum: maximum),
        reagentLot: reagentLot,
        cardVersion: cardVersion,
        device: device,
        lighting: lighting,
        capturedAt: capturedAt,
        regionsAnnotated: annotated,
        eligibleForFinalEvaluation: eligible,
        exclusionReasons: List.unmodifiable(reasons),
      ),
    );
  }

  return No3DatasetManifest(
    schemaVersion: schemaVersion,
    datasetId: _requiredString(decoded, 'datasetId'),
    parameter: _requiredString(decoded, 'parameter'),
    unit: _requiredString(decoded, 'unit'),
    reagentBrand: _requiredString(decoded, 'reagentBrand'),
    supportedLevels: List.unmodifiable(levels),
    splitRule: _requiredString(decoded, 'splitRule'),
    samples: List.unmodifiable(samples),
  );
}

List<dynamic> _requiredList(Map<String, dynamic> source, String key) {
  final value = source[key];
  if (value is! List<dynamic>) throw FormatException('$key 必须是数组');
  return value;
}

String _requiredString(Map<String, dynamic> source, String key) {
  final value = source[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key 必须是非空字符串');
  }
  return value.trim();
}

String? _optionalString(Map<String, dynamic> source, String key) {
  final value = source[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key 必须是非空字符串或 null');
  }
  return value.trim();
}

int _requiredInt(Map<String, dynamic> source, String key) {
  final value = source[key];
  if (value is! int) throw FormatException('$key 必须是整数');
  return value;
}

int _positiveInt(Map<String, dynamic> source, String key) {
  final value = _requiredInt(source, key);
  if (value <= 0) throw FormatException('$key 必须大于零');
  return value;
}

double _requiredNumber(Map<String, dynamic> source, String key) {
  final value = source[key];
  if (value is! num || !value.toDouble().isFinite || value < 0) {
    throw FormatException('$key 必须是非负有限数');
  }
  return value.toDouble();
}

bool _requiredBool(Map<String, dynamic> source, String key) {
  final value = source[key];
  if (value is! bool) throw FormatException('$key 必须是布尔值');
  return value;
}

DateTime? _optionalDateTime(Map<String, dynamic> source, String key) {
  final value = source[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key 必须是 ISO-8601 或 null');
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('$key 必须是带 UTC 时区的 ISO-8601 时间');
  }
  return parsed;
}
