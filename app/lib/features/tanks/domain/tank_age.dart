/// Strict four-digit calendar date, shared with the Web storage contract.
bool isTankCalendarDate(String? value) {
  if (value == null ||
      value.length != 10 ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return false;
  }
  final year = int.parse(value.substring(0, 4));
  final month = int.parse(value.substring(5, 7));
  final day = int.parse(value.substring(8, 10));
  final date = DateTime.utc(year, month, day);
  return date.year == year && date.month == month && date.day == day;
}

DateTime _calendarDay(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

DateTime _startDay(String value) => DateTime.utc(
  int.parse(value.substring(0, 4)),
  int.parse(value.substring(5, 7)),
  int.parse(value.substring(8, 10)),
);

/// Validate a new selection. Reading an archive must allow valid future dates
/// because the device clock may have moved backwards since it was saved.
String? validateTankStartDate(String? value, DateTime today) {
  if (value == null || value.isEmpty) return null;
  if (!isTankCalendarDate(value)) {
    throw const FormatException('请选择有效的开缸日期。');
  }
  if (_startDay(value).isAfter(_calendarDay(today))) {
    throw const FormatException('开缸日期不能晚于今天。');
  }
  return value;
}

/// Count civil days instead of elapsed hours, including across DST changes.
/// [today] carries the caller's local calendar date, never a converted instant.
int? tankAgeDays(String? startedOn, DateTime today) {
  if (!isTankCalendarDate(startedOn)) return null;
  final days = _calendarDay(today).difference(_startDay(startedOn!)).inDays;
  return days < 0 ? null : days;
}

String formatTankAge(String? startedOn, DateTime today) {
  final days = tankAgeDays(startedOn, today);
  return days == null ? '设置开缸日期' : '已运行 $days 天';
}
