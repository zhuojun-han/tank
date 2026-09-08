import '../../../data/database/app_database.dart';

class TrendDatum {
  const TrendDatum({required this.record});

  final TestRecord record;

  double get lower => record.confirmedMinValue;
  double get upper => record.confirmedMaxValue ?? record.confirmedMinValue;
  double? get point =>
      record.confirmedInterpolation ?? (lower == upper ? lower : null);
}

class TrendScale {
  const TrendScale({required this.minimum, required this.maximum});

  final double minimum;
  final double maximum;

  factory TrendScale.from({
    required List<TrendDatum> data,
    WaterQualityTarget? target,
  }) {
    final values = <double>[
      for (final item in data) ...[item.lower, item.upper],
      if (target?.minValue case final double lower) lower,
      if (target?.maxValue case final double upper) upper,
    ];
    if (values.isEmpty) return const TrendScale(minimum: 0, maximum: 1);
    var minimum = values.reduce((a, b) => a < b ? a : b);
    var maximum = values.reduce((a, b) => a > b ? a : b);
    if (minimum == maximum) {
      final padding = minimum == 0 ? 1.0 : minimum.abs() * 0.15;
      minimum = (minimum - padding).clamp(0, double.infinity);
      maximum += padding;
    } else {
      final padding = (maximum - minimum) * 0.12;
      minimum = (minimum - padding).clamp(0, double.infinity);
      maximum += padding;
    }
    return TrendScale(minimum: minimum, maximum: maximum);
  }
}

List<TrendDatum> buildTrendSeries(
  List<TestRecord> records,
  String parameterId,
) {
  final result = [
    for (final record in records)
      if (record.parameterId == parameterId) TrendDatum(record: record),
  ];
  result.sort((a, b) => a.record.measuredAt.compareTo(b.record.measuredAt));
  return result;
}
