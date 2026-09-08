import 'dart:convert';
import 'dart:math' as math;

const khTitrationTableId = 'kh-titration-from-syringe-v1';
const _epsilon = 2.220446049250313e-16 * 8;
// Printed rows 0.00 through 0.98 mL; checked against contracts/kh-titration.json.
const khTitrationDkhRows = <double>[
  15.7,
  15.3,
  15.0,
  14.7,
  14.4,
  14.1,
  13.7,
  13.4,
  13.1,
  12.8,
  12.5,
  12.1,
  11.8,
  11.5,
  11.2,
  10.9,
  10.5,
  10.2,
  9.9,
  9.6,
  9.3,
  8.9,
  8.6,
  8.3,
  8.0,
  7.7,
  7.3,
  7.0,
  6.7,
  6.4,
  6.1,
  5.7,
  5.4,
  5.1,
  4.8,
  4.5,
  4.1,
  3.8,
  3.5,
  3.2,
  2.8,
  2.5,
  2.2,
  1.9,
  1.6,
  1.2,
  0.9,
  0.6,
  0.3,
  0.0,
];

class KhTitrationResult {
  const KhTitrationResult({
    required this.initialMl,
    required this.remainingMl,
    required this.usedMl,
    required this.tableReadingMl,
    required this.dkh,
    required this.displayDkh,
    required this.interpolated,
  });
  final double initialMl;
  final double remainingMl;
  final double usedMl;
  final double tableReadingMl;
  final double dkh;
  final String displayDkh;
  final bool interpolated;
  double get confirmedValue => double.parse(displayDkh);

  Map<String, Object> toJson() => {
    'tableId': khTitrationTableId,
    'initialMl': initialMl,
    'remainingMl': remainingMl,
    'usedMl': usedMl,
    'tableReadingMl': tableReadingMl,
    'dkh': dkh,
    'displayDkh': displayDkh,
    'interpolated': interpolated,
  };

  factory KhTitrationResult.fromJson(Map<String, Object?> json) {
    double value(String key) {
      final raw = json[key];
      if (raw is! num || !raw.isFinite) {
        throw const FormatException('KH 滴定元数据无效。');
      }
      return raw.toDouble();
    }

    if (json['tableId'] != khTitrationTableId) {
      throw const FormatException('KH 滴定表版本无效。');
    }
    final checked = calculateKhTitration(
      value('initialMl'),
      value('remainingMl'),
    );
    for (final entry in {
      'usedMl': checked.usedMl,
      'tableReadingMl': checked.tableReadingMl,
      'dkh': checked.dkh,
    }.entries) {
      if ((value(entry.key) - entry.value).abs() > 1e-12) {
        throw const FormatException('KH 滴定元数据与原始输入不一致。');
      }
    }
    if (json['displayDkh'] != checked.displayDkh ||
        json['interpolated'] != checked.interpolated) {
      throw const FormatException('KH 滴定显示结果无效。');
    }
    return checked;
  }
}

KhTitrationResult validateKhTitrationJson(String source) {
  if (source.length > 2048) throw const FormatException('KH 滴定元数据过长。');
  final value = jsonDecode(source);
  if (value is! Map<String, dynamic>) {
    throw const FormatException('KH 滴定元数据无效。');
  }
  return KhTitrationResult.fromJson(value);
}

KhTitrationResult calculateKhTitration(double initialMl, double remainingMl) {
  if (!initialMl.isFinite || !remainingMl.isFinite) {
    throw const FormatException('请输入有效的初始容积和剩余溶剂体积。');
  }
  if (initialMl <= 0 || initialMl > 1) {
    throw const FormatException('针筒初始容积须大于 0 且不超过 1 mL。');
  }
  if (remainingMl < 0 || remainingMl > initialMl) {
    throw const FormatException('剩余溶剂须在 0 与初始容积之间。');
  }
  final usedMl = initialMl - remainingMl;
  final rawReading = 1 - usedMl;
  final exact = List.generate(
    khTitrationDkhRows.length,
    (i) => i,
  ).where((i) => (i / 50 - rawReading).abs() <= _epsilon).firstOrNull;
  final reading = exact == null ? rawReading : exact / 50;
  if (reading < 0 || reading > .98) {
    throw const FormatException('换算读数超出表格 0.00–0.98 mL 范围，请核对输入。');
  }
  double dkh;
  if (exact != null) {
    dkh = khTitrationDkhRows[exact];
  } else {
    final lower = (reading * 50).floor();
    final fraction = (reading - lower / 50) / ((lower + 1) / 50 - lower / 50);
    dkh =
        khTitrationDkhRows[lower] +
        fraction * (khTitrationDkhRows[lower + 1] - khTitrationDkhRows[lower]);
  }
  final scaled = dkh * 10;
  final rounded = (scaled + _epsilon * math.max(1, scaled.abs())).round() / 10;
  return KhTitrationResult(
    initialMl: initialMl,
    remainingMl: remainingMl,
    usedMl: usedMl,
    tableReadingMl: reading,
    dkh: dkh,
    displayDkh: rounded.toStringAsFixed(1),
    interpolated: exact == null,
  );
}
