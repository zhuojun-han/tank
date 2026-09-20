import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart';
import '../features/calculators/data/maintenance_cycle_repository.dart';
import '../features/calculators/domain/maintenance_cycle.dart';
import '../features/calculators/domain/maintenance_dosing.dart';
import '../features/maintenance/domain/rolling_schedule.dart';
import 'native_state_store.dart';

Map<String, dynamic> nativeCycleToWeb(MaintenanceCycleRow row) {
  final cycle = maintenanceCycleFromRow(row), input = cycle.input;
  final chemical = cycle.chemical.name;
  return {
    'id': cycle.id,
    'tankId': cycle.tankId,
    'chemical': chemical,
    'startDate': cycle.startDate,
    'refillDate': cycle.refillDate,
    'solutionMl': cycle.solutionMl,
    'dailyLiquidMl': cycle.dailyLiquidMl,
    'effectPerMl': cycle.effectPerMl,
    'retainedMl': cycle.retainedMl,
    'addedStockMl': cycle.addedStockMl,
    'addedWaterMl': cycle.addedWaterMl,
    if (cycle.theory != null) 'theory': cycle.theory!.toJson(),
    if (cycle.previousCycleId != null) 'previousCycleId': cycle.previousCycleId,
    if (cycle.closedOnDate != null) 'closedOnDate': cycle.closedOnDate,
    if (cycle.refillDeferredUntil != null)
      'refillDeferredUntil': cycle.refillDeferredUntil,
    'input': {
      'solutionMl': input.volumeMl,
      'waterL': input.waterL,
      'po4Rise': chemical == 'po4' ? input.dailyChange : 0,
      'khDrop': chemical == 'kh' ? input.dailyChange : 0,
      'po4Flow': chemical == 'po4' ? input.flow : 1.4,
      'khFlow': chemical == 'kh' ? input.flow : 1.4,
      'po4Minutes': chemical == 'po4' ? input.minutes : 1,
      'khMinutes': chemical == 'kh' ? input.minutes : 1,
      'po4Unit': chemical == 'po4' && input.unit == PumpFlowUnit.mlPerMinute
          ? 'ml/min'
          : 'ml/s',
      'khUnit': chemical == 'kh' && input.unit == PumpFlowUnit.mlPerMinute
          ? 'ml/min'
          : 'ml/s',
      'khStrength': input.khStrength,
      'khPurity': input.khPurity,
      'temperature': input.temperature,
    },
  };
}

MaintenanceDosingInput nativeCycleInput(Map<String, dynamic> row) {
  final input = stateMap(row['input']), chemical = row['chemical'];
  if (!{'po4', 'kh'}.contains(chemical)) throw const FormatException('配液药剂无效。');
  return MaintenanceDosingInput.fromJson({
    'waterL': input['waterL'],
    'volumeMl': input['solutionMl'] ?? 500,
    'dailyChange': input[chemical == 'po4' ? 'po4Rise' : 'khDrop'],
    'flow': input['${chemical}Flow'],
    'minutes': input['${chemical}Minutes'],
    'unit': input['${chemical}Unit'],
    'khStrength': input['khStrength'],
    'khPurity': input['khPurity'],
    'temperature': input['temperature'],
  });
}

Future<void> saveNativeCycles(
  AppDatabase db,
  Map<String, dynamic> state,
  Map<String, dynamic> prior,
  Set<String> tanks,
) async {
  final rows = stateRows(state, 'maintenanceCycles'),
      oldRows = stateRows(prior, 'maintenanceCycles');
  if (nativeStateEqual(rows, oldRows)) return;
  final repository = MaintenanceCycleRepository(db);
  final oldById = {for (final row in oldRows) row['id']: row};
  // A new recipe is recomputed and committed by the existing native repository.
  // It also closes exactly the previous same-tank/chemical cycle atomically.
  final closedBySuccessor = <String>{};
  for (final row in rows.where((r) => !oldById.containsKey(r['id']))) {
    final tank = stateId(row['tankId']);
    if (!tanks.contains(tank)) throw const FormatException('配液海缸不存在。');
    final chemical = DosingChemical.values
        .where((c) => c.name == row['chemical'])
        .firstOrNull;
    if (chemical == null ||
        row['closedOnDate'] != null ||
        row['refillDeferredUntil'] != null) {
      throw const FormatException('新配液周期无效。');
    }
    final cycles = await repository.getCycles(tankId: tank);
    final previous = currentMaintenanceCycle(cycles, tank, chemical);
    if (previous?.id != row['previousCycleId']) {
      throw const FormatException('上次配液归属或版本不匹配。');
    }
    final calculated = prepareMaintenanceCycle(
      input: nativeCycleInput(row),
      chemical: chemical,
      tankId: tank,
      startDate: stateDate(row['startDate']),
      id: stateId(row['id']),
      previous: previous,
      retainedMl: stateNumber(row['retainedMl'])!,
      theory: row['theory'] == null
          ? null
          : MaintenanceTheory.fromJson(stateMap(row['theory'])),
    );
    for (final entry in {
      'solutionMl': calculated.solutionMl,
      'dailyLiquidMl': calculated.dailyLiquidMl,
      'effectPerMl': calculated.effectPerMl,
      'addedStockMl': calculated.addedStockMl,
      'addedWaterMl': calculated.addedWaterMl,
    }.entries) {
      final proposed = stateNumber(row[entry.key])!;
      if ((proposed - entry.value).abs() > 1e-7 * (1 + entry.value.abs())) {
        throw const FormatException('配液计算结果已变化，请重新计算。');
      }
    }
    if (row['refillDate'] != calculated.refillDate) {
      throw const FormatException('配液日期与计算结果不一致。');
    }
    await repository.confirm(calculated);
    // A pump course replaces manual aliquot reminders for the same chemical.
    // This shares the state-save transaction, retaining past completion history.
    {
      final now = DateTime.now();
      final tasks =
          await (db.select(db.maintenanceTasks)..where(
                (t) =>
                    t.tankId.equals(tank) &
                    t.source.equals(
                      calculated.chemical == DosingChemical.po4
                          ? 'lanthanum-plan'
                          : 'alkalinity-plan',
                    ) &
                    t.status.equals('enabled'),
              ))
              .get();
      for (final task in tasks) {
        final events = await (db.select(
          db.taskEvents,
        )..where((e) => e.taskId.equals(task.id))).get();
        final initialized = initializeRollingTask(task, events: events);
        final scheduled = projectRollingDates([initialized], now)[task.id]!;
        if (scheduled.compareTo(calculated.startDate) < 0 ||
            !rollingPendingOnDate(initialized, scheduled, cycleDateKey(now))) {
          continue;
        }
        final stopped = stopRollingTasks([initialized], task.id, now).single;
        await (db.update(
          db.maintenanceTasks,
        )..where((t) => t.id.equals(task.id))).write(
          MaintenanceTasksCompanion(
            status: Value(stopped.status),
            rollingJson: Value(stopped.rollingJson),
            updatedAt: Value(now.toUtc()),
          ),
        );
        await db
            .into(db.taskEvents)
            .insert(
              TaskEventsCompanion.insert(
                id: const Uuid().v4(),
                taskId: task.id,
                type: 'skipped',
                occurredAt: now.toUtc(),
                note: const Value('已改用滴定配液周期'),
              ),
            );
        await (db.delete(db.taskEvents)..where(
              (e) =>
                  e.taskId.equals(task.id) &
                  e.note.equals('webview-reminder-only'),
            ))
            .go();
      }
    }
    if (previous != null) closedBySuccessor.add(previous.id);
  }
  for (final row in rows) {
    final old = oldById[row['id']];
    if (old == null || nativeStateEqual(row, old)) continue;
    if (row['tankId'] != old['tankId'] || row['chemical'] != old['chemical']) {
      throw const FormatException('配液周期归属不匹配。');
    }
    final expected = Map<String, dynamic>.from(old);
    if (closedBySuccessor.contains(row['id'])) {
      expected['closedOnDate'] = row['closedOnDate'];
    }
    if (row['refillDeferredUntil'] != old['refillDeferredUntil']) {
      final current = (await repository.getCycles()).singleWhere(
        (c) => c.id == row['id'],
      );
      final target = stateDate(row['refillDeferredUntil']);
      final baseline = maintenanceReminderDate(
        current,
        cycleDateKey(DateTime.now()),
      );
      await repository.delay(
        current.id,
        calendarDayDifference(target, baseline),
        expectedDeferredUntil: old['refillDeferredUntil'] as String?,
      );
      expected['refillDeferredUntil'] = target;
    }
    // The shared form keeps both reagent inputs, while native storage records
    // only this cycle's reagent. Ignore the other channel's presentation values
    // without rewriting the original recipe or relaxing its value/date checks.
    final comparable = {...row, 'input': nativeCycleInput(row).toJson()};
    final expectedRecipe = {
      ...expected,
      'input': nativeCycleInput(expected).toJson(),
    };
    if (!nativeStateEqual(comparable, expectedRecipe)) {
      throw const FormatException('已记录的配方不可被快照改写，请重新配液。');
    }
    if (closedBySuccessor.contains(row['id'])) {
      final stored = (await repository.getCycles()).singleWhere(
        (c) => c.id == row['id'],
      );
      if (row['closedOnDate'] != stored.closedOnDate) {
        throw const FormatException('原配液结束日期不匹配。');
      }
    }
  }
  if (oldRows.any((old) => !rows.any((r) => r['id'] == old['id']))) {
    throw const FormatException('历史配液周期不可删除。');
  }
}
