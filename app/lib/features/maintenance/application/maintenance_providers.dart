import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tanks/application/tank_providers.dart';
import '../data/maintenance_repository.dart';
import '../domain/recurrence.dart';
import 'maintenance_clock.dart';

final maintenanceClockProvider = StreamProvider<DateTime>((ref) {
  final clock = MaintenanceClock();
  ref.listen(
    allMaintenanceTaskItemsProvider,
    (_, value) => value.whenData(clock.update),
    fireImmediately: true,
  );
  ref.onDispose(clock.dispose);
  return clock.stream;
});

final maintenanceDateProvider = Provider<DateTime>(
  (ref) => ref.watch(
    maintenanceClockProvider.select(
      (value) => localDate(value.value ?? DateTime.now()),
    ),
  ),
);

final todayMaintenanceTasksProvider =
    Provider.family<AsyncValue<List<MaintenanceTaskItem>>, String>((
      ref,
      tankId,
    ) {
      final now = ref.watch(maintenanceClockProvider).value ?? DateTime.now();
      return ref
          .watch(
            maintenanceTaskItemsProvider((
              tankId: tankId,
              filter: MaintenanceTaskFilter.all,
            )),
          )
          .whenData(
            (items) => calendarOccurrences(items, localDate(now), 1, now: now)
                .where(
                  (i) =>
                      i.state != MaintenanceTaskViewState.completed &&
                      i.state != MaintenanceTaskViewState.skipped,
                )
                .toList(),
          );
    });

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  return MaintenanceRepository(ref.watch(appDatabaseProvider));
});

final maintenanceTaskItemsProvider = StreamProvider.family((
  ref,
  ({String tankId, MaintenanceTaskFilter filter}) query,
) {
  return ref
      .watch(maintenanceRepositoryProvider)
      .watchTaskItems(query.tankId, query.filter);
});

final pendingMaintenanceTasksProvider = StreamProvider.family((
  ref,
  String tankId,
) {
  return ref.watch(maintenanceRepositoryProvider).watchPendingTasks(tankId);
});

final completedMaintenanceEventsProvider = StreamProvider.family((
  ref,
  String tankId,
) {
  return ref.watch(maintenanceRepositoryProvider).watchCompletedEvents(tankId);
});

final handledMaintenanceEventsProvider = StreamProvider.family((
  ref,
  String tankId,
) {
  return ref.watch(maintenanceRepositoryProvider).watchHandledEvents(tankId);
});

final allMaintenanceTasksProvider = StreamProvider.family((ref, String tankId) {
  return ref.watch(maintenanceRepositoryProvider).watchAllTasks(tankId);
});

final enabledMaintenanceTasksProvider = StreamProvider((ref) {
  return ref.watch(maintenanceRepositoryProvider).watchEnabledTasks();
});

final allMaintenanceTaskItemsProvider = StreamProvider((ref) {
  return ref.watch(maintenanceRepositoryProvider).watchAllTaskItems();
});
