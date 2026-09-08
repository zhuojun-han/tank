import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_cycle.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_dosing.dart';

MaintenanceCycle cycle({
  String id = 'one',
  String tank = 'tank-a',
  DosingChemical chemical = DosingChemical.po4,
  String date = '2026-09-08',
  double volume = 500,
  double flow = 84,
  double? dailyChange,
  int strength = 6,
  MaintenanceCycle? previous,
  double retained = 0,
}) => prepareMaintenanceCycle(
  input: MaintenanceDosingInput(
    volumeMl: volume,
    dailyChange: dailyChange ?? (chemical == DosingChemical.kh ? 0.5 : 0.02),
    flow: flow,
    unit: PumpFlowUnit.mlPerMinute,
    khStrength: strength,
  ),
  chemical: chemical,
  tankId: tank,
  startDate: date,
  id: id,
  previous: previous,
  retainedMl: retained,
);

List<MaintenanceCycleOccurrence> occurrences(
  List<MaintenanceCycle> cycles, {
  String start = '2026-09-08',
  int days = 30,
  String today = '2026-09-08',
  String tank = 'tank-a',
}) => maintenanceCycleOccurrences(
  cycles,
  tankId: tank,
  start: DateTime.parse(start),
  days: days,
  now: DateTime.parse(today),
);

void main() {
  test('500 / 84 uses actual duration, six dates and last-day residual', () {
    final c = cycle();
    expect(c.refillDate, '2026-09-13');
    expect(cycleRemainingDays(c, '2026-09-08'), closeTo(500 / 84, 1e-12));
    expect(cycleRemainingDays(c, '2026-09-09'), closeTo(500 / 84 - 1, 1e-12));
    expect(cycleRemainingMl(c, '2026-09-09'), 416);
    expect(cycleRemainingMl(c, '2026-09-13'), 80);
    final rows = occurrences([c]);
    expect(rows, hasLength(6));
    expect(rows.first.remainingLabel, '预计还可用 6 天（5.95 天）');
    expect(rows[1].remainingLabel, '预计还可用 5 天（4.95 天）');
    expect(rows.last.remainingLabel, '预计还可用 1 天（0.952 天）');
    expect(rows.take(5).every((o) => o.isCompleted), isTrue);
    expect(rows.last.isRefill, isTrue);
    expect(rows.last.isCompleted, isFalse);
    expect(rows.last.detail, contains('80 mL'));
    expect(occurrences([c], start: '2026-09-14'), isEmpty);
  });

  test('reminder rolls once and delay changes no physical forecast', () {
    final c = cycle();
    final overdue = occurrences([c], today: '2026-09-16');
    expect(overdue.where((o) => o.isRefill).single.date, '2026-09-16');
    expect(
      overdue.where((o) => o.isRefill).single.remainingLabel,
      '预计还可用 0 天（0.00 天）',
    );
    expect(overdue.where((o) => o.isRefill).single.detail, contains('补液已逾期'));
    final delayed = delayMaintenanceCycle(c, 2, '2026-09-16');
    expect(delayed.refillDate, c.refillDate);
    expect(delayed.refillDeferredUntil, '2026-09-18');
    expect(
      occurrences([delayed], start: '2026-09-16', days: 1, today: '2026-09-16'),
      isEmpty,
    );
    expect(
      occurrences([
        delayed,
      ], today: '2026-09-16').where((o) => o.isRefill).single.date,
      '2026-09-18',
    );
    expect(cycleRemainingMl(delayed, '2026-09-18'), 0);
    expect(c.refillDeferredUntil, isNull);
    expect(
      () => delayMaintenanceCycle(c, 0, '2026-09-16'),
      throwsFormatException,
    );
  });

  test('sub-day, exact integer, month/year and leap-day arithmetic', () {
    expect(cycle(volume: 40, flow: 84).refillDate, '2026-09-08');
    expect(cycle(flow: 100).refillDate, '2026-09-12');
    expect(cycle(volume: 510, flow: 100).refillDate, '2026-09-13');
    expect(cycle(date: '2026-12-29', flow: 100).refillDate, '2027-01-02');
    expect(cycle(date: '2028-02-27', flow: 100).refillDate, '2028-03-02');
    expect(
      cycleRemainingMl(cycle(date: '2028-02-27', flow: 100), '2028-03-01'),
      200,
    );
    expect(cycle(date: '2026-09-29', flow: 100).refillDate, '2026-10-03');
    expect(() => cycle(date: '2026-02-29'), throwsFormatException);
    expect(() => cycle(date: '0000-01-01'), throwsFormatException);
    expect(() => cycle(date: '9999-12-31'), throwsFormatException);
  });

  test('KH residual uses previous equivalent when switching 6 to 8 stock', () {
    final old = cycle(chemical: DosingChemical.kh, flow: 100);
    final next = cycle(
      id: 'two',
      chemical: DosingChemical.kh,
      flow: 100,
      strength: 8,
      date: '2026-09-10',
      previous: old,
      retained: 300,
    );
    expect(next.addedStockMl, closeTo(160, 1e-9));
    expect(next.addedWaterMl, closeTo(40, 1e-9));
    expect(next.effectPerMl, closeTo(old.effectPerMl, 1e-12));
    expect(next.previousCycleId, old.id);
    expect(next.retainedMl, 300);
    expect(cycleRemainingMl(next, '2026-09-11'), 400);
    expect(next.retainedMl, 300);
    validateMaintenanceCycle(next);
  });

  test(
    'residual rejects wrong scope, volume, concentration and old snapshot',
    () {
      final old = cycle();
      expect(
        () => cycle(tank: 'tank-b', previous: old, retained: 100),
        throwsFormatException,
      );
      expect(
        () => cycle(chemical: DosingChemical.kh, previous: old),
        throwsFormatException,
      );
      expect(
        () => cycle(previous: old, date: '2026-09-07'),
        throwsFormatException,
      );
      expect(
        () => cycle(previous: old.copyWith(closedOnDate: '2026-09-09')),
        throwsFormatException,
      );
      for (final invalid in [-1.0, double.nan, double.infinity, 501.0]) {
        expect(
          () => cycle(previous: old, retained: invalid),
          throwsFormatException,
        );
      }
      expect(() => cycle(retained: 100), throwsFormatException);
      expect(
        () => cycle(previous: old, retained: 500, dailyChange: 0.001),
        throwsFormatException,
      );
      final kh = cycle(chemical: DosingChemical.kh, flow: 100);
      expect(
        () => cycle(
          chemical: DosingChemical.kh,
          flow: 100,
          previous: kh,
          retained: 490,
          strength: 8,
          dailyChange: 0.55,
        ),
        throwsFormatException,
      );
      expect(() => cycle(dailyChange: 0), throwsFormatException);
      expect(
        () => cycle(chemical: DosingChemical.kh, dailyChange: 2),
        throwsFormatException,
      );
    },
  );

  test(
    'closure removes old delayed reminder and keeps earlier true cycle dates',
    () {
      final old = delayMaintenanceCycle(
        cycle(),
        3,
        '2026-09-13',
      ).copyWith(closedOnDate: '2026-09-11');
      final kh = cycle(id: 'kh', chemical: DosingChemical.kh);
      final other = cycle(id: 'other', tank: 'tank-b');
      final rows = occurrences([old, kh, other], today: '2026-09-16');
      expect(rows.where((r) => r.cycle.id == old.id), hasLength(3));
      expect(
        rows.where((r) => r.cycle.id == old.id).every((r) => r.isCompleted),
        isTrue,
      );
      expect(
        rows.where((r) => r.cycle.id == 'kh' && r.isRefill).single.date,
        '2026-09-16',
      );
      expect(rows.any((r) => r.cycle.id == 'other'), isFalse);
      expect(
        () => delayMaintenanceCycle(old, 1, '2026-09-16'),
        throwsFormatException,
      );
    },
  );

  test(
    'input snapshot round trips exact unrounded values and validates dates',
    () {
      final c = cycle();
      final input = MaintenanceDosingInput.fromJson(c.input.toJson());
      expect(input.toJson(), c.input.toJson());
      expect(c.addedStockMl, closeTo(2.380952380952381, 1e-12));
      validateMaintenanceCycle(c);
      expect(
        () => validateMaintenanceCycle(
          c.copyWith(refillDeferredUntil: '2026-09-12'),
        ),
        throwsFormatException,
      );
      expect(
        () => validateMaintenanceCycle(c.copyWith(closedOnDate: '2026-09-07')),
        throwsFormatException,
      );
      expect(
        () => MaintenanceDosingInput.fromJson({
          ...c.input.toJson(),
          'unit': 'g/s',
        }),
        throwsFormatException,
      );
    },
  );
}
