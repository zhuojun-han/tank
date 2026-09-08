/// Preserve the exact decimal midpoint of the user's boundary strings (as
/// represented by doubles), instead of imposing a fixed decimal-place limit.
double decimalMidpoint(double minimum, double maximum) {
  (BigInt, int) parts(double value) {
    final exponentParts = value.toString().toLowerCase().split('e');
    final decimal = exponentParts.first.split('.');
    final fraction = decimal.length == 2 ? decimal[1] : '';
    return (
      BigInt.parse('${decimal[0]}$fraction'),
      (exponentParts.length == 2 ? int.parse(exponentParts[1]) : 0) -
          fraction.length,
    );
  }

  final low = parts(minimum), high = parts(maximum);
  final exponent = low.$2 < high.$2 ? low.$2 : high.$2;
  final sum =
      low.$1 * BigInt.from(10).pow(low.$2 - exponent) +
      high.$1 * BigInt.from(10).pow(high.$2 - exponent);
  return double.parse('${sum * BigInt.from(5)}e${exponent - 1}');
}

String calculatorTargetDefault({
  required bool kh,
  double? minimum,
  double? maximum,
}) {
  if (minimum == null && maximum == null) return kh ? '8' : '0.03';
  if (minimum == null ||
      maximum == null ||
      !minimum.isFinite ||
      !maximum.isFinite ||
      minimum < 0 ||
      maximum < minimum) {
    return '';
  }
  final value = decimalMidpoint(minimum, maximum);
  return value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toString();
}
