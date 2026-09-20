import 'dart:math' as math;

import 'lanthanum_calculator.dart';
import 'maintenance_dosing.dart';

/// The selected channel's recipe inputs. The other channel cannot invalidate it.
class MaintenanceDosingInput {
  const MaintenanceDosingInput({
    this.waterL = 200,
    this.volumeMl = 500,
    required this.dailyChange,
    this.flow = 1.4,
    this.minutes = 1,
    this.unit = PumpFlowUnit.mlPerSecond,
    this.khStrength = 6,
    this.khPurity = 100,
    this.temperature = 20,
  });

  final double waterL, volumeMl, dailyChange, flow, minutes;
  final PumpFlowUnit unit;
  final int khStrength;
  final double khPurity, temperature;

  MaintenanceDosingResult calculate(DosingChemical chemical) =>
      calculateMaintenanceDosing(
        chemical: chemical,
        waterL: waterL,
        volumeMl: volumeMl,
        dailyChange: dailyChange,
        flow: flow,
        minutes: minutes,
        unit: unit,
        khStrength: khStrength,
        khPurity: khPurity,
        temperature: temperature,
      );

  Map<String, Object> toJson() => {
    'waterL': waterL,
    'volumeMl': volumeMl,
    'dailyChange': dailyChange,
    'flow': flow,
    'minutes': minutes,
    'unit': unit == PumpFlowUnit.mlPerSecond ? 'ml/s' : 'ml/min',
    'khStrength': khStrength,
    'khPurity': khPurity,
    'temperature': temperature,
  };

  factory MaintenanceDosingInput.fromJson(Map<String, dynamic> json) {
    double number(String key) {
      final value = json[key];
      if (value is! num || !value.isFinite) {
        throw const FormatException('配液输入快照无效。');
      }
      return value.toDouble();
    }

    final unit = json['unit'];
    final strength = number('khStrength');
    if (!{'ml/s', 'ml/min'}.contains(unit) || strength != strength.round()) {
      throw const FormatException('配液输入快照无效。');
    }
    return MaintenanceDosingInput(
      waterL: number('waterL'),
      volumeMl: number('volumeMl'),
      dailyChange: number('dailyChange'),
      flow: number('flow'),
      minutes: number('minutes'),
      unit: unit == 'ml/s'
          ? PumpFlowUnit.mlPerSecond
          : PumpFlowUnit.mlPerMinute,
      khStrength: strength.toInt(),
      khPurity: number('khPurity'),
      temperature: number('temperature'),
    );
  }
}

/// A finite correction course. Older steady recipes have no theory metadata.
class MaintenanceTheory {
  const MaintenanceTheory({
    required this.planId,
    required this.source,
    required this.target,
    required this.planStartDate,
    required this.endDate,
    required this.lastDayRatio,
  });
  final String planId, source, planStartDate, endDate;
  final double target, lastDayRatio;

  Map<String, Object> toJson() => {
    'planId': planId,
    'source': source,
    'target': target,
    'planStartDate': planStartDate,
    'endDate': endDate,
    'lastDayRatio': lastDayRatio,
  };

  factory MaintenanceTheory.fromJson(Map<String, dynamic> value) {
    for (final key in ['planId', 'source', 'planStartDate', 'endDate']) {
      if (value[key] is! String || (value[key] as String).isEmpty) {
        throw const FormatException('理论计划信息无效。');
      }
    }
    for (final key in ['target', 'lastDayRatio']) {
      if (value[key] is! num || !(value[key] as num).isFinite) {
        throw const FormatException('理论计划数值无效。');
      }
    }
    final theory = MaintenanceTheory(
      planId: value['planId'],
      source: value['source'],
      target: (value['target'] as num).toDouble(),
      planStartDate: value['planStartDate'],
      endDate: value['endDate'],
      lastDayRatio: (value['lastDayRatio'] as num).toDouble(),
    );
    final length =
        _ordinal(theory.endDate) - _ordinal(theory.planStartDate) + 1;
    if (theory.planId.length > 200 ||
        !{'lanthanum-plan', 'alkalinity-plan'}.contains(theory.source) ||
        theory.target <= 0 ||
        theory.lastDayRatio <= 0 ||
        theory.lastDayRatio > 1 ||
        length < 1 ||
        length > 3650) {
      throw const FormatException('理论计划范围无效。');
    }
    return theory;
  }
}

class MaintenanceCycle {
  const MaintenanceCycle({
    required this.id,
    required this.tankId,
    required this.chemical,
    required this.input,
    required this.startDate,
    required this.refillDate,
    required this.solutionMl,
    required this.dailyLiquidMl,
    required this.effectPerMl,
    required this.retainedMl,
    required this.addedStockMl,
    required this.addedWaterMl,
    this.previousCycleId,
    this.closedOnDate,
    this.refillDeferredUntil,
    this.notificationId,
    this.theory,
  });

  final String id, tankId;
  final DosingChemical chemical;
  final MaintenanceDosingInput input;
  final String startDate, refillDate;
  final double solutionMl, dailyLiquidMl, effectPerMl;
  final double retainedMl, addedStockMl, addedWaterMl;
  final String? previousCycleId, closedOnDate, refillDeferredUntil;
  final int? notificationId;
  final MaintenanceTheory? theory;

  MaintenanceCycle copyWith({
    String? closedOnDate,
    String? refillDeferredUntil,
  }) => MaintenanceCycle(
    id: id,
    tankId: tankId,
    chemical: chemical,
    input: input,
    startDate: startDate,
    refillDate: refillDate,
    solutionMl: solutionMl,
    dailyLiquidMl: dailyLiquidMl,
    effectPerMl: effectPerMl,
    retainedMl: retainedMl,
    addedStockMl: addedStockMl,
    addedWaterMl: addedWaterMl,
    previousCycleId: previousCycleId,
    closedOnDate: closedOnDate ?? this.closedOnDate,
    refillDeferredUntil: refillDeferredUntil ?? this.refillDeferredUntil,
    notificationId: notificationId,
    theory: theory,
  );
}

String cycleDateKey(DateTime date) {
  final local = date.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

int _ordinal(String date) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
    throw const FormatException('请核对配液日期。');
  }
  final value = DateTime.tryParse('${date}T00:00:00Z');
  if (value == null ||
      value.year < 1 ||
      value.year > 9999 ||
      value.toIso8601String().substring(0, 10) != date) {
    throw const FormatException('请核对配液日期。');
  }
  return value.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
}

String _dateFromOrdinal(int day) {
  if (day > _ordinal('9999-12-31') || day < _ordinal('0001-01-01')) {
    throw const FormatException('日期超出可用范围，请核对输入。');
  }
  return DateTime.fromMillisecondsSinceEpoch(
    day * Duration.millisecondsPerDay,
    isUtc: true,
  ).toIso8601String().substring(0, 10);
}

double _cycleConsumedDays(MaintenanceCycle cycle, String date) {
  final theory = cycle.theory;
  final until =
      theory != null &&
          cycle.closedOnDate != null &&
          date.compareTo(cycle.closedOnDate!) > 0
      ? cycle.closedOnDate!
      : date;
  final elapsed = math.max(0, _ordinal(until) - _ordinal(cycle.startDate));
  if (theory == null) return elapsed.toDouble();
  final length = _ordinal(theory.endDate) - _ordinal(cycle.startDate) + 1;
  return math.min(elapsed, length) -
      (elapsed >= length ? 1 - theory.lastDayRatio : 0);
}

double cycleRemainingMl(MaintenanceCycle cycle, String date) => math.max(
  0,
  cycle.solutionMl - _cycleConsumedDays(cycle, date) * cycle.dailyLiquidMl,
);

bool cycleNeedsRefill(MaintenanceCycle cycle) {
  final theory = cycle.theory;
  if (theory == null) return true;
  final days =
      _ordinal(theory.endDate) -
      _ordinal(cycle.startDate) +
      theory.lastDayRatio;
  final required = days * cycle.dailyLiquidMl;
  return required >
      cycle.solutionMl +
          1e-10 * math.max(1, math.max(required, cycle.solutionMl));
}

double cycleRemainingDays(MaintenanceCycle cycle, String date) =>
    cycleRemainingMl(cycle, date) / cycle.dailyLiquidMl;

MaintenanceCycle? currentMaintenanceCycle(
  Iterable<MaintenanceCycle> cycles,
  String tankId,
  DosingChemical chemical,
) {
  MaintenanceCycle? current;
  for (final cycle in cycles) {
    if (cycle.tankId == tankId &&
        cycle.chemical == chemical &&
        cycle.closedOnDate == null) {
      current = cycle;
    }
  }
  return current;
}

MaintenanceCycle prepareMaintenanceCycle({
  required MaintenanceDosingInput input,
  required DosingChemical chemical,
  required String tankId,
  required String startDate,
  required String id,
  MaintenanceCycle? previous,
  double retainedMl = 0,
  MaintenanceTheory? theory,
}) {
  final start = _ordinal(startDate);
  if (theory != null) {
    MaintenanceTheory.fromJson(theory.toJson());
    if (theory.source !=
            (chemical == DosingChemical.po4
                ? 'lanthanum-plan'
                : 'alkalinity-plan') ||
        startDate.compareTo(theory.planStartDate) < 0 ||
        startDate.compareTo(theory.endDate) > 0) {
      throw const FormatException('理论计划药剂或日期不匹配。');
    }
  }
  final result = input.calculate(chemical);
  if (result.dailyStockMl <= 0) {
    throw const FormatException('每日变化为 0，无需添加滴定周期。');
  }
  if (!result.feasible) {
    throw const FormatException('所需母液超过容量，请调整配方。');
  }
  if (!retainedMl.isFinite || retainedMl < 0 || retainedMl > result.volumeMl) {
    throw const FormatException('残液体积须在 0 与新配液总体积之间。');
  }
  if (previous != null &&
      (previous.tankId != tankId ||
          previous.chemical != chemical ||
          previous.closedOnDate != null ||
          startDate.compareTo(previous.startDate) < 0)) {
    throw const FormatException('上次配液记录不匹配，请重新打开配方。');
  }
  if (retainedMl > 0 &&
      (previous == null || retainedMl > previous.solutionMl)) {
    throw const FormatException('残液体积不能超过上次配液体积。');
  }
  final stockEffect = chemical == DosingChemical.po4
      ? stockPo4RemovalMgPerMl
      : 0.1 / input.khStrength;
  final effectPerMl = result.stockMl * stockEffect / result.volumeMl;
  // Use old chemical equivalents, not old stock mL: KH strength may change.
  final addedStock =
      (effectPerMl * result.volumeMl -
          retainedMl * (previous?.effectPerMl ?? 0)) /
      stockEffect;
  final water = result.volumeMl - retainedMl - addedStock;
  if (!effectPerMl.isFinite || !addedStock.isFinite || !water.isFinite) {
    throw const FormatException('输入超出可计算范围，请核对数值。');
  }
  if (addedStock < -1e-8) {
    throw const FormatException('残液中的药量已超过新配方需要，请减少保留残液或增加总体积。');
  }
  if (water < -1e-8) {
    throw const FormatException('残液加所需母液超过容量，请减少保留残液或增加总体积。');
  }
  if (result.actualDays > _ordinal('9999-12-31') - start + 1 + 1e-10) {
    throw const FormatException('预计补液日期超出可用范围，请核对流速。');
  }
  return MaintenanceCycle(
    id: id,
    tankId: tankId,
    chemical: chemical,
    input: input,
    startDate: startDate,
    refillDate: _dateFromOrdinal(
      start + math.max(0, (result.actualDays - 1e-10).ceil() - 1),
    ),
    solutionMl: result.volumeMl,
    dailyLiquidMl: result.dailyLiquidMl,
    effectPerMl: effectPerMl,
    retainedMl: retainedMl,
    addedStockMl: math.max(0, addedStock),
    addedWaterMl: math.max(0, water),
    previousCycleId: previous?.id,
    theory: theory,
  );
}

String maintenanceReminderDate(MaintenanceCycle cycle, String today) {
  _ordinal(today);
  return [
    cycle.refillDate,
    cycle.refillDeferredUntil ?? cycle.refillDate,
    today,
  ].reduce((a, b) => a.compareTo(b) > 0 ? a : b);
}

/// Shared by persistence and backup import; validates the saved recipe without
/// inventing a previous snapshot when only this row is being read.
void validateMaintenanceCycle(MaintenanceCycle cycle) {
  _ordinal(cycle.startDate);
  _ordinal(cycle.refillDate);
  if (cycle.closedOnDate case final closed?) {
    _ordinal(closed);
    if (closed.compareTo(cycle.startDate) < 0) {
      throw const FormatException('周期关闭日期早于配液日期。');
    }
  }
  if (cycle.refillDeferredUntil case final deferred?) {
    _ordinal(deferred);
    if (deferred.compareTo(cycle.refillDate) < 0) {
      throw const FormatException('补液延迟日期无效。');
    }
  }
  if (cycle.id.isEmpty ||
      cycle.tankId.isEmpty ||
      cycle.previousCycleId == cycle.id ||
      [
        cycle.solutionMl,
        cycle.dailyLiquidMl,
        cycle.effectPerMl,
      ].any((v) => !v.isFinite || v <= 0) ||
      [
        cycle.retainedMl,
        cycle.addedStockMl,
        cycle.addedWaterMl,
      ].any((v) => !v.isFinite || v < 0)) {
    throw const FormatException('配液周期数值无效。');
  }
  final base = prepareMaintenanceCycle(
    input: cycle.input,
    chemical: cycle.chemical,
    tankId: cycle.tankId,
    startDate: cycle.startDate,
    id: cycle.id,
    theory: cycle.theory,
  );
  bool close(double a, double b) =>
      (a - b).abs() <= 1e-8 * math.max(1, math.max(a.abs(), b.abs()));
  if (cycle.refillDate != base.refillDate ||
      !close(cycle.solutionMl, base.solutionMl) ||
      !close(cycle.dailyLiquidMl, base.dailyLiquidMl) ||
      !close(cycle.effectPerMl, base.effectPerMl) ||
      !close(
        cycle.retainedMl + cycle.addedStockMl + cycle.addedWaterMl,
        cycle.solutionMl,
      ) ||
      (cycle.retainedMl > 0 && cycle.previousCycleId == null)) {
    throw const FormatException('配液周期与保存的配方不一致。');
  }
  if (cycle.retainedMl == 0 && !close(cycle.addedStockMl, base.addedStockMl)) {
    throw const FormatException('配液母液量与保存的配方不一致。');
  }
}

MaintenanceCycle delayMaintenanceCycle(
  MaintenanceCycle cycle,
  int days,
  String today,
) {
  if (cycle.closedOnDate != null ||
      !cycleNeedsRefill(cycle) ||
      cycle.theory != null && today.compareTo(cycle.theory!.endDate) >= 0) {
    throw const FormatException('补液周期已变化，请重新打开任务。');
  }
  if (days < 1) throw const FormatException('延迟天数须为大于 0 的整数。');
  final target = _dateFromOrdinal(
    _ordinal(maintenanceReminderDate(cycle, today)) + days,
  );
  return cycle.copyWith(
    refillDeferredUntil:
        cycle.theory != null && target.compareTo(cycle.theory!.endDate) > 0
        ? cycle.theory!.endDate
        : target,
  );
}

String formatCycleVolume(double value) => value == 0
    ? '0'
    : value.abs() < 0.001
    ? value.toStringAsExponential(3)
    : value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

class MaintenanceCycleOccurrence {
  const MaintenanceCycleOccurrence({
    required this.cycle,
    required this.date,
    required this.today,
  });
  final MaintenanceCycle cycle;
  final String date, today;
  bool get isRefill =>
      cycleNeedsRefill(cycle) && date.compareTo(cycle.refillDate) >= 0;
  bool get isCompleted =>
      !isRefill ||
      cycle.closedOnDate != null ||
      cycle.theory != null && today.compareTo(cycle.theory!.endDate) > 0;
  bool get isDue => !isCompleted && date.compareTo(today) <= 0;
  String get title =>
      '${cycle.chemical == DosingChemical.po4 ? 'PO₄' : 'KH'} ${cycle.theory == null ? '每日平衡' : '理论计划'}${isRefill ? ' · 添加滴定液' : ''}';
  String get remainingLabel {
    final days = cycleRemainingDays(cycle, date);
    return '预计还可用 ${days.round()} 天（${days.toStringAsPrecision(3)} 天）';
  }

  String get detail {
    final remaining =
        '预计剩余 ${formatCycleVolume(cycleRemainingMl(cycle, date))} mL';
    if (cycle.theory != null && today.compareTo(cycle.theory!.endDate) > 0) {
      return '$remaining · 计划已结束';
    }
    if (cycle.closedOnDate != null) {
      return '$remaining · 已于 ${cycle.closedOnDate} 续配';
    }
    if (cycle.theory != null && !cycleNeedsRefill(cycle)) {
      return '$remaining · ${cycle.theory!.endDate} 计划结束';
    }
    if (date.compareTo(cycle.refillDate) > 0) {
      return '$remaining · $date 提醒配液${date.compareTo(today) <= 0 ? '，补液已逾期' : ''}';
    }
    return '$remaining · ${cycle.refillDate} ${isRefill ? '需配液' : '补液'}';
  }
}

/// Finite daily status and a single rolling refill reminder; no persisted daily tasks.
List<MaintenanceCycleOccurrence> maintenanceCycleOccurrences(
  Iterable<MaintenanceCycle> cycles, {
  required String tankId,
  required DateTime start,
  required int days,
  required DateTime now,
}) {
  final first = _ordinal(cycleDateKey(start));
  final today = cycleDateKey(now);
  final result = <MaintenanceCycleOccurrence>[];
  for (var day = 0; day < days; day++) {
    final date = _dateFromOrdinal(first + day);
    for (final cycle in cycles) {
      if (cycle.tankId != tankId ||
          date.compareTo(cycle.startDate) < 0 ||
          cycle.theory != null && date.compareTo(cycle.theory!.endDate) > 0) {
        continue;
      }
      final occurs = cycle.closedOnDate != null
          ? date.compareTo(cycle.closedOnDate!) < 0 &&
                date.compareTo(cycle.refillDate) <= 0
          : !cycleNeedsRefill(cycle) ||
                date.compareTo(cycle.refillDate) < 0 ||
                date == maintenanceReminderDate(cycle, today);
      if (occurs) {
        result.add(
          MaintenanceCycleOccurrence(cycle: cycle, date: date, today: today),
        );
      }
    }
  }
  return result;
}
