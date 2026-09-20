import 'package:drift/drift.dart';

import '../data/database/app_database.dart';
import '../features/aquarium/domain/fish_stock.dart';
import '../features/maintenance/application/maintenance_notification_coordinator.dart';
import '../features/test_timer/application/test_workflow_controller.dart';
import 'native_state_store.dart';

/// Destructive operations are explicit commands, never inferred from a snapshot.
class NativeDataRemoval {
  NativeDataRemoval(this.database);
  final AppDatabase database;

  Future<Set<int>> execute(
    Map<String, dynamic> params, {
    required bool reset,
  }) => database.transaction(() async {
    if (params['confirmed'] != true) throw const FormatException('请先确认删除范围。');
    final before = await NativeStateStore(database).readState();
    if (params['expectedRevision'] != before['revision']) {
      throw const FormatException('数据已变化，请重新打开后确认。');
    }
    final id = params['tankId'];
    if (!reset &&
        (id is! String ||
            !(await database.select(database.tanks).get()).any(
              (t) => t.id == id,
            ))) {
      throw const FormatException('海缸已不存在，请重新打开。');
    }
    final tasks = (await database.select(database.maintenanceTasks).get())
        .where((t) => reset || t.tankId == id)
        .toList();
    final cycles = (await database.select(database.maintenanceCycles).get())
        .where((c) => reset || c.tankId == id);
    final sessions = (await database.select(database.activeTestSessions).get())
        .where((s) => reset || s.tankId == id);
    final reminders = <int>{
      for (final s in sessions) testTimerNotificationId(s.id),
    };
    for (final notificationId in [
      ...tasks.map((t) => t.notificationId),
      ...cycles.map((c) => c.notificationId),
    ]) {
      if (notificationId == null) continue;
      reminders.add(notificationId);
      try {
        reminders.add(maintenanceDailyNotificationId(notificationId));
        reminders.addAll(finiteMaintenanceNotificationIds(notificationId));
      } on ArgumentError {
        /* Older backups may contain non-current notification IDs. */
      }
    }
    if (reset) {
      await database.resetForOnboarding();
    } else {
      final tankId = id as String;
      await (database.delete(
        database.taskEvents,
      )..where((e) => e.taskId.isIn(tasks.map((t) => t.id)))).go();
      await (database.delete(
        database.maintenanceCycles,
      )..where((t) => t.tankId.equals(tankId))).go();
      await (database.delete(
        database.activeTestSessions,
      )..where((t) => t.tankId.equals(tankId))).go();
      await (database.delete(
        database.testRecords,
      )..where((t) => t.tankId.equals(tankId))).go();
      await (database.delete(
        database.maintenanceTasks,
      )..where((t) => t.tankId.equals(tankId))).go();
      await (database.delete(
        database.testTimerDefaults,
      )..where((t) => t.tankId.equals(tankId))).go();
      await (database.delete(
        database.waterQualityTargets,
      )..where((t) => t.tankId.equals(tankId))).go();
      await (database.delete(
        database.tankParameters,
      )..where((t) => t.tankId.equals(tankId))).go();
      final prefs = await database.select(database.appPreferences).getSingle();
      final remaining = (await database.select(database.tanks).get()).where(
        (t) => t.id != tankId && !t.isArchived,
      );
      await database
          .update(database.appPreferences)
          .write(
            AppPreferencesCompanion(
              currentTankId: Value(
                prefs.currentTankId == tankId
                    ? remaining.firstOrNull?.id
                    : prefs.currentTankId,
              ),
              fishStockJson: Value(
                FishStockCodec.encode(
                  FishStockCodec.decode(
                    prefs.fishStockJson,
                  ).where((f) => f.tankId != tankId).toList(),
                ),
              ),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
      await (database.delete(
        database.tanks,
      )..where((t) => t.id.equals(tankId))).go();
    }
    return reminders;
  });
}
