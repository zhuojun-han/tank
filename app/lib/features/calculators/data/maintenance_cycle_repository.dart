import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../data/database/app_database.dart';
import '../domain/maintenance_cycle.dart';
import '../domain/maintenance_dosing.dart';

MaintenanceCycle maintenanceCycleFromRow(MaintenanceCycleRow row) {
  final chemical = DosingChemical.values
      .where((v) => v.name == row.chemical)
      .firstOrNull;
  if (chemical == null) throw const FormatException('配液药剂无效。');
  final input = jsonDecode(row.inputJson);
  if (input is! Map<String, dynamic>) {
    throw const FormatException('配液输入快照无效。');
  }
  final cycle = MaintenanceCycle(
    id: row.id,
    tankId: row.tankId,
    chemical: chemical,
    input: MaintenanceDosingInput.fromJson(input),
    startDate: row.startDate,
    refillDate: row.refillDate,
    solutionMl: row.solutionMl,
    dailyLiquidMl: row.dailyLiquidMl,
    effectPerMl: row.effectPerMl,
    retainedMl: row.retainedMl,
    addedStockMl: row.addedStockMl,
    addedWaterMl: row.addedWaterMl,
    previousCycleId: row.previousCycleId,
    closedOnDate: row.closedOnDate,
    refillDeferredUntil: row.refillDeferredUntil,
    notificationId: row.notificationId,
  );
  validateMaintenanceCycle(cycle);
  return cycle;
}

class MaintenanceCycleRepository {
  MaintenanceCycleRepository(this.database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final AppDatabase database;
  final DateTime Function() _now;
  DateTime get now => _now();

  SimpleSelectStatement<MaintenanceCycles, MaintenanceCycleRow> _query(
    String? tankId,
  ) {
    final query = database.select(database.maintenanceCycles);
    if (tankId != null) query.where((t) => t.tankId.equals(tankId));
    query.orderBy([
      (t) => OrderingTerm.asc(t.createdAt),
      (t) => OrderingTerm.asc(t.id),
    ]);
    return query;
  }

  Stream<List<MaintenanceCycle>> watchCycles({String? tankId}) => _query(
    tankId,
  ).watch().map((rows) => rows.map(maintenanceCycleFromRow).toList());

  Future<List<MaintenanceCycle>> getCycles({String? tankId}) async =>
      (await _query(tankId).get()).map(maintenanceCycleFromRow).toList();

  /// No writes for preview/cancel. Re-read the old cycle and validate the recipe
  /// within the same transaction that closes it and inserts its successor.
  Future<void> confirm(MaintenanceCycle preview) =>
      database.transaction(() async {
        validateMaintenanceCycle(preview);
        final date = cycleDateKey(now);
        if (preview.startDate.compareTo(date) > 0 ||
            preview.closedOnDate != null ||
            preview.refillDeferredUntil != null) {
          throw const FormatException('请选择不晚于今天的实际配液日期。');
        }
        final tank = await (database.select(
          database.tanks,
        )..where((t) => t.id.equals(preview.tankId))).getSingleOrNull();
        if (tank == null || tank.isArchived) {
          throw const FormatException('海缸已变化，请重新打开配方。');
        }
        final cycles = await getCycles(tankId: preview.tankId);
        final current = currentMaintenanceCycle(
          cycles,
          preview.tankId,
          preview.chemical,
        );
        if (current?.id != preview.previousCycleId ||
            cycles.any((c) => c.id == preview.id)) {
          throw const FormatException('配液周期已变化，请重新计算。');
        }
        final confirmed = prepareMaintenanceCycle(
          input: preview.input,
          chemical: preview.chemical,
          tankId: preview.tankId,
          startDate: preview.startDate,
          id: preview.id,
          previous: current,
          retainedMl: preview.retainedMl,
        );
        final timestamp = now.toUtc();
        if (current != null) {
          await (database.update(
            database.maintenanceCycles,
          )..where((t) => t.id.equals(current.id))).write(
            MaintenanceCyclesCompanion(
              closedOnDate: Value(confirmed.startDate),
              updatedAt: Value(timestamp),
            ),
          );
        }
        await database
            .into(database.maintenanceCycles)
            .insert(
              MaintenanceCyclesCompanion.insert(
                id: confirmed.id,
                tankId: confirmed.tankId,
                chemical: confirmed.chemical.name,
                inputJson: jsonEncode(confirmed.input.toJson()),
                startDate: confirmed.startDate,
                refillDate: confirmed.refillDate,
                solutionMl: confirmed.solutionMl,
                dailyLiquidMl: confirmed.dailyLiquidMl,
                effectPerMl: confirmed.effectPerMl,
                retainedMl: confirmed.retainedMl,
                addedStockMl: confirmed.addedStockMl,
                addedWaterMl: confirmed.addedWaterMl,
                previousCycleId: Value(confirmed.previousCycleId),
                createdAt: timestamp,
                updatedAt: timestamp,
              ),
            );
      });

  Future<void> delay(
    String cycleId,
    int days, {
    String? expectedDeferredUntil,
  }) => database.transaction(() async {
    final row = await (database.select(
      database.maintenanceCycles,
    )..where((t) => t.id.equals(cycleId))).getSingleOrNull();
    if (row == null ||
        row.closedOnDate != null ||
        row.refillDeferredUntil != expectedDeferredUntil) {
      throw const FormatException('补液周期已变化，请重新打开任务。');
    }
    final next = delayMaintenanceCycle(
      maintenanceCycleFromRow(row),
      days,
      cycleDateKey(now),
    );
    await (database.update(
      database.maintenanceCycles,
    )..where((t) => t.id.equals(cycleId))).write(
      MaintenanceCyclesCompanion(
        refillDeferredUntil: Value(next.refillDeferredUntil),
        updatedAt: Value(now.toUtc()),
      ),
    );
  });

  Future<void> setNotificationId(String id, int notificationId) async {
    await (database.update(
      database.maintenanceCycles,
    )..where((t) => t.id.equals(id))).write(
      MaintenanceCyclesCompanion(notificationId: Value(notificationId)),
    );
  }
}
