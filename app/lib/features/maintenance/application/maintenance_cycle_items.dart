import '../../../data/database/app_database.dart';
import '../../calculators/domain/maintenance_cycle.dart';
import '../data/maintenance_repository.dart';

MaintenanceTaskItem cycleOccurrenceItem(MaintenanceCycleOccurrence occurrence) {
  final cycle = occurrence.cycle, date = DateTime.parse(occurrence.date);
  final task = MaintenanceTask(
    id: 'cycle-${cycle.id}',
    tankId: cycle.tankId,
    title: occurrence.title,
    notes: '${occurrence.remainingLabel}\n${occurrence.detail}',
    intervalAmount: 1,
    intervalUnit: 'day',
    dueAt: DateTime(date.year, date.month, date.day, 9).toUtc(),
    preferredReminderTime: '09:00',
    status: occurrence.isCompleted ? 'completed' : 'enabled',
    isOneOff: true,
    source: 'maintenance-cycle',
    notificationId: cycle.notificationId,
    createdAt: DateTime.parse(cycle.startDate).toUtc(),
    updatedAt: DateTime.parse(cycle.startDate).toUtc(),
  );
  return MaintenanceTaskItem(
    task: task,
    occurrenceDate: date,
    cycleOccurrence: occurrence,
    state: occurrence.isCompleted
        ? MaintenanceTaskViewState.completed
        : occurrence.isDue
        ? MaintenanceTaskViewState.overdue
        : MaintenanceTaskViewState.upcoming,
  );
}

List<MaintenanceTaskItem> maintenanceCycleItems(
  List<MaintenanceCycle> cycles, {
  required String tankId,
  required DateTime start,
  required int days,
  required DateTime now,
}) => maintenanceCycleOccurrences(
  cycles,
  tankId: tankId,
  start: start,
  days: days,
  now: now,
).map(cycleOccurrenceItem).toList();

List<MaintenanceTaskItem> maintenanceCycleNotificationItems(
  List<MaintenanceCycle> cycles,
  DateTime now,
) {
  final result = <MaintenanceTaskItem>[];
  for (final cycle in cycles) {
    final theory = cycle.theory;
    if (theory != null &&
        !cycleNeedsRefill(cycle) &&
        cycle.closedOnDate == null &&
        cycleDateKey(now).compareTo(theory.endDate) <= 0) {
      final occurrence = MaintenanceCycleOccurrence(
        cycle: cycle,
        date: theory.endDate,
        today: cycleDateKey(now),
      );
      final item = cycleOccurrenceItem(occurrence);
      result.add(
        MaintenanceTaskItem(
          task: item.task.copyWith(
            status: 'enabled',
            title: '${cycle.chemical.name.toUpperCase()} 理论计划 · 计划结束',
          ),
          state: MaintenanceTaskViewState.upcoming,
          occurrenceDate: item.occurrenceDate,
          cycleOccurrence: occurrence,
        ),
      );
      continue;
    }
    final date = maintenanceReminderDate(cycle, cycleDateKey(now));
    final occurrences = maintenanceCycleItems(
      [cycle],
      tankId: cycle.tankId,
      start: DateTime.parse(date),
      days: 1,
      now: now,
    );
    if (occurrences.isNotEmpty &&
        cycle.closedOnDate == null &&
        cycleNeedsRefill(cycle)) {
      result.add(occurrences.single);
    } else if (cycle.notificationId != null) {
      final d = DateTime.parse(date);
      result.add(
        MaintenanceTaskItem(
          task: MaintenanceTask(
            id: 'cycle-${cycle.id}',
            tankId: cycle.tankId,
            title: '已结束滴定周期',
            intervalAmount: 1,
            intervalUnit: 'day',
            dueAt: d.toUtc(),
            preferredReminderTime: '09:00',
            status: 'disabled',
            isOneOff: true,
            source: 'maintenance-cycle',
            notificationId: cycle.notificationId,
            createdAt: d.toUtc(),
            updatedAt: d.toUtc(),
          ),
          state: MaintenanceTaskViewState.disabled,
          cycleOccurrence: MaintenanceCycleOccurrence(
            cycle: cycle,
            date: date,
            today: cycleDateKey(now),
          ),
        ),
      );
    }
  }
  return result;
}
