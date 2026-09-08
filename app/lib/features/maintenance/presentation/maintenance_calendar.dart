import 'package:flutter/material.dart';

import '../data/maintenance_repository.dart';

class MaintenanceCalendar extends StatelessWidget {
  const MaintenanceCalendar({
    required this.month,
    required this.selectedDate,
    required this.items,
    required this.onMonthChanged,
    required this.onDateSelected,
    required this.onComplete,
    required this.onSkip,
    this.onSnooze,
    this.onReopen,
    this.onStop,
    this.onCorrect,
    super.key,
  });

  final DateTime month;
  final DateTime selectedDate;
  final List<MaintenanceTaskItem> items;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<MaintenanceTaskItem> onComplete;
  final ValueChanged<MaintenanceTaskItem> onSkip;
  final ValueChanged<MaintenanceTaskItem>? onSnooze,
      onReopen,
      onStop,
      onCorrect;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final gridStart = DateTime(first.year, first.month, 2 - first.weekday);
    final days = [
      for (var i = 0; i < 42; i += 1)
        DateTime(gridStart.year, gridStart.month, gridStart.day + i),
    ];
    final selectedItems =
        items
            .where((item) => _sameDate(item.task.dueAt.toLocal(), selectedDate))
            .toList()
          ..sort((a, b) => a.task.dueAt.compareTo(b.task.dueAt));

    return Card(
      key: const Key('maintenance-calendar'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: '上个月',
                  onPressed: () =>
                      onMonthChanged(DateTime(month.year, month.month - 1)),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${month.year} 年 ${month.month} 月',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: '下个月',
                  onPressed: () =>
                      onMonthChanged(DateTime(month.year, month.month + 1)),
                  icon: const Icon(Icons.chevron_right),
                ),
                TextButton(
                  onPressed: () {
                    final now = DateTime.now();
                    onMonthChanged(DateTime(now.year, now.month));
                    onDateSelected(DateTime(now.year, now.month, now.day));
                  },
                  child: const Text('今天'),
                ),
              ],
            ),
            Row(
              children: [
                for (final label in ['一', '二', '三', '四', '五', '六', '日'])
                  Expanded(child: Center(child: Text(label))),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.82,
              children: [
                for (final day in days)
                  _CalendarDay(
                    day: day,
                    inMonth: day.month == month.month,
                    selected: _sameDate(day, selectedDate),
                    taskCount: items
                        .where(
                          (item) => _sameDate(item.task.dueAt.toLocal(), day),
                        )
                        .length,
                    onTap: () => onDateSelected(day),
                  ),
              ],
            ),
            const Divider(),
            Text(
              '${selectedDate.month} 月 ${selectedDate.day} 日待办',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (selectedItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('当天没有已安排的事项。'),
              )
            else
              for (final item in selectedItems) ...[
                _CalendarTask(
                  item: item,
                  onComplete: () => onComplete(item),
                  onSkip: () => onSkip(item),
                  onSnooze: onSnooze == null ? null : () => onSnooze!(item),
                  onReopen: onReopen == null ? null : () => onReopen!(item),
                  onStop: onStop == null ? null : () => onStop!(item),
                  onCorrect: onCorrect == null ? null : () => onCorrect!(item),
                ),
                if (item != selectedItems.last) const Divider(height: 16),
              ],
          ],
        ),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.taskCount,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final int taskCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: Key('maintenance-calendar-day-${_dateKey(day)}'),
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(10),
          border: selected ? Border.all(color: scheme.primary) : null,
        ),
        child: Column(
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: inMonth ? null : scheme.outline,
                fontWeight: selected ? FontWeight.bold : null,
              ),
            ),
            if (taskCount > 0) ...[
              const SizedBox(height: 3),
              Container(
                constraints: const BoxConstraints(minWidth: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$taskCount',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onPrimary, fontSize: 10),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalendarTask extends StatelessWidget {
  const _CalendarTask({
    required this.item,
    required this.onComplete,
    required this.onSkip,
    this.onSnooze,
    this.onReopen,
    this.onStop,
    this.onCorrect,
  });

  final MaintenanceTaskItem item;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback? onSnooze, onReopen, onStop, onCorrect;

  @override
  Widget build(BuildContext context) {
    final enabled =
        item.task.status == MaintenanceTaskStatus.enabled.name &&
        item.state != MaintenanceTaskViewState.completed;
    final lanthanum = isChemicalPlan(item.task);
    final cycle = item.cycleOccurrence != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          item.task.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        if (item.task.notes != null) ...[
          const SizedBox(height: 4),
          ExpansionTile(
            title: const Text('查看执行说明'),
            tilePadding: EdgeInsets.zero,
            children: [Text(item.task.notes!)],
          ),
        ],
        const SizedBox(height: 8),
        if (enabled)
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: Key('calendar-complete-${item.task.id}'),
                  onPressed: onComplete,
                  icon: const Icon(Icons.check),
                  label: Text(cycle ? '添加滴定液' : '完成本次'),
                ),
              ),
              const SizedBox(height: 8),
              if (item.state == MaintenanceTaskViewState.snoozed)
                Text('已推迟至 ${item.latestEvent?.snoozedUntil?.toLocal()}'),
              Row(
                children: [
                  if (onSnooze != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onSnooze,
                        child: const Text('延迟'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (!cycle)
                    Expanded(
                      child: OutlinedButton(
                        key: Key('calendar-skip-${item.task.id}'),
                        onPressed: onSkip,
                        child: Text(lanthanum ? '停止当天及后续' : '停止'),
                      ),
                    ),
                ],
              ),
            ],
          )
        else
          Wrap(
            children: [
              const Text('已完成'),
              if (onCorrect != null && item.canEditCompletion)
                TextButton(onPressed: onCorrect, child: const Text('修改完成日期')),
              if (onReopen != null && item.canReopen)
                TextButton(onPressed: onReopen, child: const Text('撤销完成')),
            ],
          ),
      ],
    );
  }
}

bool _sameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _dateKey(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
