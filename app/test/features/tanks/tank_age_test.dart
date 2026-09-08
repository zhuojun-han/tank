import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/features/tanks/domain/tank_age.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  test(
    'calendar validation matches exact Web dates without normalizing input',
    () {
      for (final value in [
        '0000-01-01',
        '2000-02-29',
        '2024-02-29',
        '9999-12-31',
      ]) {
        expect(isTankCalendarDate(value), isTrue, reason: value);
      }
      for (final value in <String?>[
        null,
        '',
        '2026-2-01',
        '2026-02-30',
        '1900-02-29',
        '2026-00-01',
        '2026-13-01',
        '2026-01-00',
        '2026-01-32',
        '2026-09-08 ',
        '2026-09-08T00:00:00Z',
        '10000-01-01',
        '2026-09-08\n',
      ]) {
        expect(isTankCalendarDate(value), isFalse, reason: '$value');
      }
    },
  );

  test('day zero, month/year/leap transitions and unset/future display', () {
    final today = DateTime(2026, 9, 8, 23, 59);
    expect(tankAgeDays('2026-09-08', today), 0);
    expect(tankAgeDays('2026-08-31', today), 8);
    expect(tankAgeDays('2025-12-31', DateTime(2026, 1, 1)), 1);
    expect(tankAgeDays('2024-02-28', DateTime(2024, 3, 1)), 2);
    expect(tankAgeDays('2025-02-28', DateTime(2025, 3, 1)), 1);
    expect(tankAgeDays('2000-01-01', DateTime(2026, 1, 1)), 9497);
    expect(formatTankAge('2026-09-08', today), '已运行 0 天');
    for (final value in [null, '', '2026-02-30', '2026-09-09']) {
      expect(tankAgeDays(value, today), isNull);
      expect(formatTankAge(value, today), '设置开缸日期');
    }
  });

  test('civil day difference crosses 23/25-hour DST days without drift', () {
    tz_data.initializeTimeZones();
    final location = tz.getLocation('America/New_York');
    final spring = tz.TZDateTime(location, 2026, 3, 9);
    final autumn = tz.TZDateTime(location, 2026, 11, 2);
    expect(spring.difference(tz.TZDateTime(location, 2026, 3, 8)).inHours, 23);
    expect(autumn.difference(tz.TZDateTime(location, 2026, 11, 1)).inHours, 25);
    expect(tankAgeDays('2026-03-08', spring), 1);
    expect(tankAgeDays('2026-11-01', autumn), 1);
    // Use the caller's local day even when the same instant is tomorrow in UTC.
    final evening = tz.TZDateTime(location, 2026, 9, 8, 23);
    expect(evening.toUtc().day, 9);
    expect(tankAgeDays('2026-09-08', evening), 0);
  });

  test('only user submission rejects future; clear remains optional', () {
    final today = DateTime(2026, 9, 8);
    expect(validateTankStartDate(null, today), isNull);
    expect(validateTankStartDate('', today), isNull);
    expect(validateTankStartDate('2026-09-08', today), '2026-09-08');
    expect(
      () => validateTankStartDate('2026-09-09', today),
      throwsFormatException,
    );
    expect(
      () => validateTankStartDate('2026-02-30', today),
      throwsFormatException,
    );
    expect(isTankCalendarDate('2026-09-09'), isTrue);
  });
}
