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
    this.today,
    super.key,
  });

  final DateTime month;
  final DateTime selectedDate;
  final DateTime? today;
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
                  child: Column(
                    children: [
                      Text(
                        '${month.year} 年 ${month.month} 月',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          final now = today ?? DateTime.now();
                          onMonthChanged(DateTime(now.year, now.month));
                          onDateSelected(
                            DateTime(now.year, now.month, now.day),
                          );
                        },
                        child: const Text('今天'),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '下个月',
                  onPressed: () =>
                      onMonthChanged(DateTime(month.year, month.month + 1)),
                  icon: const Icon(Icons.chevron_right),
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
              mainAxisExtent:
                  24 + MediaQuery.textScalerOf(context).scale(12) * 6,
              children: [
                for (final day in days)
                  _CalendarDay(
                    day: day,
                    inMonth: day.month == month.month,
                    selected: _sameDate(day, selectedDate),
                    today: _sameDate(day, today ?? DateTime.now()),
                    items: items
                        .where(
                          (item) => _sameDate(item.task.dueAt.toLocal(), day),
                        )
                        .toList(),
                    onTap: () => onDateSelected(day),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('当天待办', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${selectedDate.month} 月 ${selectedDate.day} 日待办',
              style: Theme.of(context).textTheme.bodySmall,
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
                if (item != selectedItems.last) const SizedBox(height: 10),
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
    required this.items,
    required this.today,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final List<MaintenanceTaskItem> items;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: selected
            ? scheme.secondaryContainer
            : inMonth
            ? scheme.surface
            : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: InkWell(
          key: Key('maintenance-calendar-day-${_dateKey(day)}'),
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
            child: Column(
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.25,
                    color: today
                        ? scheme.primary
                        : inMonth
                        ? null
                        : scheme.outline,
                    fontWeight: selected || today ? FontWeight.bold : null,
                  ),
                ),
                for (final item in items.take(2))
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${item.state == MaintenanceTaskViewState.completed ? '✓ ' : ''}${item.task.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSecondaryContainer,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ),
                if (items.length > 2)
                  Text(
                    '+${items.length - 2}',
                    style: const TextStyle(fontSize: 12, height: 1.25),
                  ),
              ],
            ),
          ),
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
    return Material(
      color: enabled
          ? Theme.of(context).colorScheme.surface
          : Theme.of(context).colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.task.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (item.task.notes?.isNotEmpty == true) ...[
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
                        if (!cycle) const SizedBox(width: 8),
                      ],
                      if (!cycle)
                        Expanded(
                          child: OutlinedButton(
                            key: Key('calendar-skip-${item.task.id}'),
                            onPressed: onSkip,
                            child: Text(lanthanum ? '停止后续' : '停止'),
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
                    TextButton(
                      onPressed: onCorrect,
                      child: const Text('修改完成日期'),
                    ),
                  if (onReopen != null && item.canReopen)
                    TextButton(onPressed: onReopen, child: const Text('撤销完成')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

bool _sameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _dateKey(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
