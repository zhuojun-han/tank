import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../calculators/application/maintenance_cycle_providers.dart';
import '../../calculators/domain/maintenance_dosing.dart';
import '../application/maintenance_cycle_items.dart';
import '../domain/rolling_schedule.dart';
import 'task_schedule_dialogs.dart';

import '../../../core/errors/app_error_view.dart';
import '../../../data/database/app_database.dart';
import '../../tanks/application/tank_providers.dart';
import '../application/maintenance_providers.dart';
import '../data/maintenance_repository.dart';
import 'maintenance_calendar.dart';
import 'chemical_plan_card.dart';
import '../domain/recurrence.dart';

class MaintenancePage extends ConsumerStatefulWidget {
  const MaintenancePage({this.initialTaskId, super.key});

  final String? initialTaskId;

  @override
  ConsumerState<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends ConsumerState<MaintenancePage> {
  MaintenanceTaskFilter _filter = MaintenanceTaskFilter.pending;
  String? _handledInitialTaskId;
  String? _openingInitialTaskId;
  late DateTime _calendarMonth;
  late DateTime _selectedCalendarDate;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _calendarMonth = DateTime(today.year, today.month);
    _selectedCalendarDate = DateTime(today.year, today.month, today.day);
  }

  @override
  void didUpdateWidget(covariant MaintenancePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTaskId != widget.initialTaskId) {
      _handledInitialTaskId = null;
      _openingInitialTaskId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(maintenanceDateProvider, (previous, next) {
      if (previous != null && _selectedCalendarDate == previous) {
        setState(() {
          _selectedCalendarDate = next;
          _calendarMonth = DateTime(next.year, next.month);
        });
      }
    });
    _queueInitialTaskOpen(ref.watch(allMaintenanceTaskItemsProvider));
    return ref
        .watch(currentTankProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppErrorView(message: '无法读取当前海缸：$error'),
          data: (tank) {
            if (tank == null) return const AppErrorView(message: '请先在设置中创建海缸。');
            return _buildForTank(tank);
          },
        );
  }

  void _queueInitialTaskOpen(AsyncValue<List<MaintenanceTaskItem>> taskItems) {
    final taskId = widget.initialTaskId;
    if (taskId == null ||
        taskId.isEmpty ||
        taskId == _handledInitialTaskId ||
        taskId == _openingInitialTaskId) {
      return;
    }
    taskItems.whenData((items) {
      if (!mounted ||
          taskId == _handledInitialTaskId ||
          taskId == _openingInitialTaskId) {
        return;
      }
      _openingInitialTaskId = taskId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_openInitialTask(taskId, items));
      });
    });
  }

  Future<void> _openInitialTask(
    String taskId,
    List<MaintenanceTaskItem> items,
  ) async {
    try {
      if (!mounted || _handledInitialTaskId == taskId) return;
      _handledInitialTaskId = taskId;
      if (taskId.startsWith('cycle-')) {
        final cycles = await ref
            .read(maintenanceCycleRepositoryProvider)
            .getCycles();
        final cycle = cycles
            .where((cycle) => cycle.id == taskId.substring(6))
            .firstOrNull;
        if (!mounted) return;
        if (cycle == null || cycle.closedOnDate != null) {
          _message(context, '该补液周期已结束或不存在');
          return;
        }
        await ref.read(tankRepositoryProvider).switchTank(cycle.tankId);
        if (!mounted) return;
        await context.push(
          '/maintenance-dosing?chemical=${cycle.chemical == DosingChemical.kh ? 'kh' : 'po4'}',
        );
        return;
      }
      final matches = items.where((item) => item.task.id == taskId);
      if (matches.isEmpty) {
        _message(context, '未找到该维护任务，它可能已被删除。');
        return;
      }
      final item = matches.first;
      await ref.read(tankRepositoryProvider).switchTank(item.task.tankId);
      if (!mounted) return;
      if (item.task.recurrenceJson != null || item.task.rollingJson != null) {
        // A stale notification must never complete tomorrow's occurrence.
        final today = localDate(DateTime.now());
        setState(() {
          _calendarMonth = DateTime(today.year, today.month);
          _selectedCalendarDate = today;
        });
        return;
      }
      final targetFilter =
          item.task.status == MaintenanceTaskStatus.enabled.name
          ? MaintenanceTaskFilter.pending
          : MaintenanceTaskFilter.all;
      if (_filter != targetFilter) {
        setState(() => _filter = targetFilter);
      }
      await _openTask(context, item.task.tankId, item);
    } catch (error) {
      if (mounted) _message(context, '无法打开通知对应的维护任务：$error');
    } finally {
      if (_openingInitialTaskId == taskId) {
        _openingInitialTaskId = null;
      }
    }
  }

  Widget _buildForTank(Tank tank) {
    final clock = ref.watch(maintenanceClockProvider).value ?? DateTime.now();
    final cycles = ref.watch(maintenanceCyclesProvider(tank.id)).value ?? [];
    final stored = ref.watch(
      maintenanceTaskItemsProvider((
        tankId: tank.id,
        filter: MaintenanceTaskFilter.all,
      )),
    );
    final gridStart = DateTime(
      _calendarMonth.year,
      _calendarMonth.month,
      2 - DateTime(_calendarMonth.year, _calendarMonth.month).weekday,
    );
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tank.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<MaintenanceTaskFilter>(
                      key: const Key('maintenance-filter'),
                      segments: const [
                        ButtonSegment(
                          value: MaintenanceTaskFilter.pending,
                          label: Text('待处理'),
                        ),
                        ButtonSegment(
                          value: MaintenanceTaskFilter.completed,
                          label: Text('已完成'),
                        ),
                        ButtonSegment(
                          value: MaintenanceTaskFilter.all,
                          label: Text('全部'),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (value) =>
                          setState(() => _filter = value.single),
                    ),
                  ],
                ),
              ),
            ),
            stored.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => AppErrorView(message: '无法读取任务：$error'),
              data: (raw) {
                final all = prepareMaintenanceTaskItems(raw, clock);
                final visible = [
                  ...calendarOccurrences(all, gridStart, 42, now: clock),
                  ...maintenanceCycleItems(
                    cycles,
                    tankId: tank.id,
                    start: gridStart,
                    days: 42,
                    now: clock,
                  ),
                ];
                final selected = [
                  ...calendarOccurrences(
                    all,
                    _selectedCalendarDate,
                    1,
                    now: clock,
                  ),
                  ...maintenanceCycleItems(
                    cycles,
                    tankId: tank.id,
                    start: _selectedCalendarDate,
                    days: 1,
                    now: clock,
                  ),
                ];
                final shown = selected
                    .where(
                      (item) => _filter == MaintenanceTaskFilter.completed
                          ? item.state == MaintenanceTaskViewState.completed
                          : item.state != MaintenanceTaskViewState.completed,
                    )
                    .toList();
                final plans =
                    groupMaintenancePlans(
                          all
                              .where((item) => isChemicalPlan(item.task))
                              .toList(),
                        )
                        .where(
                          (group) => group.any(
                            (item) => item.task.status == 'enabled',
                          ),
                        )
                        .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MaintenanceCalendar(
                      month: _calendarMonth,
                      selectedDate: _selectedCalendarDate,
                      items: visible,
                      onMonthChanged: (month) =>
                          setState(() => _calendarMonth = month),
                      onDateSelected: (date) => setState(() {
                        _selectedCalendarDate = date;
                        _calendarMonth = DateTime(date.year, date.month);
                      }),
                      onComplete: (item) =>
                          _completeCalendarTask(tank.id, item),
                      onSkip: (item) => _skipCalendarTask(tank.id, item),
                      onSnooze: (item) => _delayTask(tank.id, item),
                      onReopen: (item) => _reopen(tank.id, item),
                      onCorrect: (item) => _correctCompletion(tank.id, item),
                      onStop: (item) => _stopRecurring(tank.id, item),
                    ),
                    const SizedBox(height: 12),
                    if (_filter == MaintenanceTaskFilter.all) ...[
                      for (final group in plans)
                        ChemicalPlanCard(
                          items: group,
                          onStop: (item) => _skipCalendarTask(tank.id, item),
                          onComplete: (item) =>
                              _completeCalendarTask(tank.id, item),
                          onDelay: (item) => _delayTask(tank.id, item),
                        ),
                      _TaskList(
                        items: all
                            .where(
                              (item) =>
                                  item.task.status == 'enabled' &&
                                  !isChemicalPlan(item.task),
                            )
                            .toList(),
                        onOpen: (item) => _openTask(context, tank.id, item),
                        onMenuAction: (item, action) =>
                            _handleMenuAction(context, tank.id, item, action),
                      ),
                    ] else ...[
                      Text(dateKey(_selectedCalendarDate)),
                      if (shown.isEmpty)
                        const Card(child: ListTile(title: Text('所选日期没有记录'))),
                      for (final item in shown)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  item.task.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                if (item.cycleOccurrence != null)
                                  Text(item.task.notes ?? ''),
                                if (item.state ==
                                    MaintenanceTaskViewState.completed)
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      const Text('已完成'),
                                      if (item.canEditCompletion)
                                        TextButton(
                                          onPressed: () =>
                                              _correctCompletion(tank.id, item),
                                          child: const Text('修改完成日期'),
                                        ),
                                      if (item.canReopen)
                                        TextButton(
                                          onPressed: () =>
                                              _reopen(tank.id, item),
                                          child: const Text('撤销完成'),
                                        ),
                                    ],
                                  )
                                else ...[
                                  FilledButton(
                                    onPressed: () =>
                                        _completeCalendarTask(tank.id, item),
                                    child: Text(
                                      item.cycleOccurrence != null
                                          ? '添加滴定液'
                                          : '完成本次',
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              _delayTask(tank.id, item),
                                          child: const Text('延迟'),
                                        ),
                                      ),
                                      if (item.cycleOccurrence == null) ...[
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () => _skipCalendarTask(
                                              tank.id,
                                              item,
                                            ),
                                            child: const Text('停止'),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            key: const Key('add-maintenance-task'),
            onPressed: () => _editTask(context, tank.id),
            icon: const Icon(Icons.add_task),
            label: const Text('新增任务'),
          ),
        ),
      ],
    );
  }

  Future<void> _openRefill(MaintenanceTaskItem item) async {
    final cycle = item.cycleOccurrence!.cycle;
    await context.push(
      '/maintenance-dosing?chemical=${cycle.chemical == DosingChemical.kh ? 'kh' : 'po4'}',
    );
  }

  Future<void> _completeCalendarTask(
    String tankId,
    MaintenanceTaskItem item,
  ) async {
    if (item.cycleOccurrence != null) {
      await _openRefill(item);
      return;
    }
    final schedule = rollingSchedule(item.task);
    final date = await showTaskCompletionDate(context);
    if (date == null || !mounted) return;
    try {
      await ref
          .read(maintenanceRepositoryProvider)
          .complete(
            tankId: tankId,
            taskId: item.task.id,
            completedDate: date,
            expectedRevision: schedule.revision,
          );
      if (mounted) _message(context, '已完成，后续日期已更新');
    } catch (error) {
      if (mounted) _message(context, '操作失败：$error');
    }
  }

  Future<void> _delayTask(String tankId, MaintenanceTaskItem item) async {
    final days = await showTaskDelayDays(context);
    if (days == null || !mounted) return;
    try {
      final cycle = item.cycleOccurrence?.cycle;
      if (cycle != null) {
        await ref
            .read(maintenanceCycleRepositoryProvider)
            .delay(
              cycle.id,
              days,
              expectedDeferredUntil: cycle.refillDeferredUntil,
            );
      } else {
        await ref
            .read(maintenanceRepositoryProvider)
            .delayTask(
              tankId: tankId,
              taskId: item.task.id,
              days: days,
              expectedRevision: rollingSchedule(item.task).revision,
            );
      }
      if (mounted) _message(context, '已延迟 $days 天');
    } catch (error) {
      if (mounted) _message(context, '操作失败：$error');
    }
  }

  Future<void> _correctCompletion(
    String tankId,
    MaintenanceTaskItem item,
  ) async {
    final original = item.occurrenceDate ?? item.task.dueAt.toLocal();
    final date = await showTaskCompletionDate(
      context,
      initialDate: original,
      title: '修改完成日期',
    );
    if (date == null || !mounted) return;
    try {
      await ref
          .read(maintenanceRepositoryProvider)
          .correctCompletion(
            tankId: tankId,
            taskId: item.task.id,
            completedDate: original,
            newDate: date,
            expectedRevision: rollingSchedule(item.task).revision,
          );
    } catch (error) {
      if (mounted) _message(context, '修改失败：$error');
    }
  }

  Future<void> _reopen(String tankId, MaintenanceTaskItem item) async {
    try {
      await ref
          .read(maintenanceRepositoryProvider)
          .reopen(
            tankId: tankId,
            taskId: item.task.id,
            occurrenceDate: item.occurrenceDate,
            expectedRevision: rollingSchedule(item.task).revision,
          );
    } catch (e) {
      if (mounted) _message(context, '恢复失败：$e');
    }
  }

  Future<void> _stopRecurring(String tankId, MaintenanceTaskItem item) async {
    if (!await _confirm(
          context,
          title: '停止后续计划？',
          body: '所选日期及以后的执行日会隐藏，之前的逐日记录保留。',
          confirmLabel: '停止计划',
        ) ||
        !mounted) {
      return;
    }
    try {
      await ref
          .read(maintenanceRepositoryProvider)
          .stopRecurring(
            tankId: tankId,
            taskId: item.task.id,
            from: item.occurrenceDate ?? item.task.dueAt,
          );
    } catch (e) {
      if (mounted) _message(context, '停止失败：$e');
    }
  }

  Future<void> _skipCalendarTask(
    String tankId,
    MaintenanceTaskItem item,
  ) async {
    final lanthanum = isChemicalPlan(item.task);
    final confirmed = await _confirm(
      context,
      title: lanthanum ? '停止当天及后续计划？' : '停止任务？',
      body: lanthanum
          ? '会记录当天及同一加药计划全部后续事项为已跳过，并取消对应系统提醒。'
          : item.task.isOneOff
          ? '会保留一次跳过记录，不再产生后续周期。'
          : '后续待办和提醒会停止，已完成历史保留。',
      confirmLabel: lanthanum ? '停止计划' : '停止',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref
          .read(maintenanceRepositoryProvider)
          .skip(
            tankId: tankId,
            taskId: item.task.id,
            occurrenceDate: item.occurrenceDate,
          );
      if (mounted) _message(context, lanthanum ? '已停止当天及后续计划' : '已停止后续任务');
    } catch (error) {
      if (mounted) _message(context, '操作失败：$error');
    }
  }

  Future<void> _editTask(
    BuildContext context,
    String tankId, {
    MaintenanceTask? task,
  }) async {
    final draft = await _showTaskEditor(context, task: task);
    if (draft == null || !context.mounted) return;
    try {
      final repository = ref.read(maintenanceRepositoryProvider);
      if (task == null) {
        await repository.createTask(
          tankId: tankId,
          title: draft.title,
          notes: draft.notes,
          intervalAmount: draft.intervalAmount,
          intervalUnit: draft.intervalUnit,
          dueAt: draft.dueAt,
          preferredReminderTime: draft.reminderTime,
          calendarRecurrence: true,
        );
      } else {
        await repository.updateTask(
          tankId: tankId,
          taskId: task.id,
          title: draft.title,
          notes: draft.notes,
          intervalAmount: draft.intervalAmount,
          intervalUnit: draft.intervalUnit,
          dueAt: draft.dueAt,
          preferredReminderTime: draft.reminderTime,
          calendarRecurrence: true,
        );
      }
      if (context.mounted) {
        _message(context, task == null ? '维护任务已创建' : '维护任务已更新');
      }
    } catch (error) {
      if (context.mounted) _message(context, '保存失败：$error');
    }
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    String tankId,
    MaintenanceTaskItem item,
    _TaskMenuAction action,
  ) async {
    final repository = ref.read(maintenanceRepositoryProvider);
    try {
      switch (action) {
        case _TaskMenuAction.edit:
          await _editTask(context, tankId, task: item.task);
          return;
        case _TaskMenuAction.disable:
          await repository.setEnabled(
            tankId: tankId,
            taskId: item.task.id,
            enabled: false,
          );
          break;
        case _TaskMenuAction.enable:
          await repository.setEnabled(
            tankId: tankId,
            taskId: item.task.id,
            enabled: true,
          );
          break;
        case _TaskMenuAction.archive:
          final confirmed = await _confirm(
            context,
            title: '归档任务？',
            body: '“${item.task.title}”的历史会保留，但不再出现在待处理列表，也不会安排后续通知。',
            confirmLabel: '归档',
          );
          if (!confirmed || !context.mounted) return;
          await repository.archiveTask(tankId: tankId, taskId: item.task.id);
          break;
        case _TaskMenuAction.delete:
          final confirmed = await _confirm(
            context,
            title: '永久删除任务？',
            body:
                '“${item.task.title}”及其全部完成、跳过和稍后提醒历史都会被永久删除，此操作无法撤销。如果只想停止提醒，请选择停用或归档。',
            confirmLabel: '永久删除',
            destructive: true,
          );
          if (!confirmed || !context.mounted) return;
          await repository.deleteTask(tankId: tankId, taskId: item.task.id);
          if (context.mounted) _message(context, '任务已永久删除');
          return;
      }
      if (context.mounted) _message(context, '任务状态已更新');
    } catch (error) {
      if (context.mounted) _message(context, '操作失败：$error');
    }
  }

  Future<void> _openTask(
    BuildContext context,
    String tankId,
    MaintenanceTaskItem item,
  ) async {
    if (item.task.status != MaintenanceTaskStatus.enabled.name) {
      _message(context, '该任务已停用或归档，可从菜单重新启用或查看资料。');
      return;
    }
    final action = await showModalBottomSheet<_TaskDetailAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                item.task.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text('到期：${_dateTime(item.task.dueAt)}'),
              Text(
                item.task.isOneOff
                    ? '一次性任务${item.task.planDayIndex == null ? '' : ' · 第 ${item.task.planDayIndex}/${item.task.planTotalDays} 天'}'
                          ' · 提醒 ${item.task.preferredReminderTime}'
                    : '周期：每 ${item.task.intervalAmount} ${_intervalLabel(item.task.intervalUnit)}'
                          ' · 提醒 ${item.task.preferredReminderTime}',
              ),
              if (item.task.notes != null) ...[
                const SizedBox(height: 8),
                Text(item.task.notes!),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('complete-maintenance-task'),
                onPressed: () =>
                    Navigator.pop(sheetContext, _TaskDetailAction.complete),
                icon: const Icon(Icons.check),
                label: const Text('完成本次'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('snooze-maintenance-task'),
                onPressed: () =>
                    Navigator.pop(sheetContext, _TaskDetailAction.snooze),
                icon: const Icon(Icons.snooze),
                label: const Text('延迟'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('skip-maintenance-task'),
                onPressed: () =>
                    Navigator.pop(sheetContext, _TaskDetailAction.skip),
                icon: const Icon(Icons.skip_next),
                label: Text(
                  isChemicalPlan(item.task)
                      ? '停止当天及后续'
                      : item.task.isOneOff
                      ? '跳过本次'
                      : '跳过本周期',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _TaskDetailAction.complete:
        await _completeCalendarTask(tankId, item);
        break;
      case _TaskDetailAction.snooze:
        await _delayTask(tankId, item);
        break;
      case _TaskDetailAction.skip:
        await _skipCalendarTask(tankId, item);
        break;
    }
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.items,
    required this.onOpen,
    required this.onMenuAction,
  });

  final List<MaintenanceTaskItem> items;
  final ValueChanged<MaintenanceTaskItem> onOpen;
  final void Function(MaintenanceTaskItem, _TaskMenuAction) onMenuAction;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.task_alt, size: 40),
              SizedBox(height: 8),
              Text('当前筛选没有维护任务'),
              SizedBox(height: 4),
              Text('新增任务后会按当前海缸独立保存。'),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _TaskTile(
              item: items[index],
              onTap: () => onOpen(items[index]),
              onMenuAction: (action) => onMenuAction(items[index], action),
            ),
            if (index < items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.item,
    required this.onTap,
    required this.onMenuAction,
  });

  final MaintenanceTaskItem item;
  final VoidCallback onTap;
  final ValueChanged<_TaskMenuAction> onMenuAction;

  @override
  Widget build(BuildContext context) {
    final enabled = item.task.status == MaintenanceTaskStatus.enabled.name;
    return ListTile(
      key: Key('maintenance-task-${item.task.id}'),
      leading: CircleAvatar(
        backgroundColor: _stateColor(
          context,
          item.state,
        ).withValues(alpha: 0.14),
        foregroundColor: _stateColor(context, item.state),
        child: Icon(_stateIcon(item.state)),
      ),
      title: Text(item.task.title),
      subtitle: Text(
        '${_stateLabel(item.state)} · ${_dateTime(item.task.dueAt)}\n'
        '${item.task.isOneOff ? '一次性' : '每 ${item.task.intervalAmount} ${_intervalLabel(item.task.intervalUnit)}'} · '
        '${item.task.preferredReminderTime} 提醒',
      ),
      isThreeLine: true,
      onTap: onTap,
      trailing: PopupMenuButton<_TaskMenuAction>(
        key: Key('maintenance-task-menu-${item.task.id}'),
        onSelected: onMenuAction,
        itemBuilder: (_) => [
          if (item.task.status != MaintenanceTaskStatus.archived.name)
            const PopupMenuItem(value: _TaskMenuAction.edit, child: Text('编辑')),
          if (enabled)
            const PopupMenuItem(
              value: _TaskMenuAction.disable,
              child: Text('停用'),
            )
          else if (item.task.status == MaintenanceTaskStatus.disabled.name)
            const PopupMenuItem(
              value: _TaskMenuAction.enable,
              child: Text('重新启用'),
            ),
          if (item.task.status != MaintenanceTaskStatus.archived.name)
            const PopupMenuItem(
              value: _TaskMenuAction.archive,
              child: Text('归档'),
            ),
          PopupMenuItem(
            key: Key('delete-maintenance-task-${item.task.id}'),
            value: _TaskMenuAction.delete,
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

Future<_TaskDraft?> _showTaskEditor(
  BuildContext context, {
  MaintenanceTask? task,
}) {
  return showDialog<_TaskDraft>(
    context: context,
    builder: (_) => _TaskEditorDialog(task: task),
  );
}

class _TaskEditorDialog extends StatefulWidget {
  const _TaskEditorDialog({this.task});

  final MaintenanceTask? task;

  @override
  State<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<_TaskEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _interval;
  late MaintenanceIntervalUnit _unit;
  late DateTime _dueAt;
  late TimeOfDay _reminder;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    final now = DateTime.now();
    _title = TextEditingController(text: task?.title ?? '');
    _notes = TextEditingController(text: task?.notes ?? '');
    _interval = TextEditingController(
      text: task?.intervalAmount.toString() ?? '1',
    );
    _unit = MaintenanceIntervalUnit.values.firstWhere(
      (value) => value.name == task?.intervalUnit,
      orElse: () => MaintenanceIntervalUnit.week,
    );
    _dueAt = task?.rollingJson != null
        ? DateTime.parse(rollingSchedule(task!).nextDate)
        : task?.dueAt.toLocal() ??
              DateTime(now.year, now.month, now.day + 1, 9);
    _reminder = _parseTime(task?.preferredReminderTime ?? '09:00');
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _interval.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.task == null ? '新增维护任务' : '编辑维护任务'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('maintenance-title'),
                controller: _title,
                maxLength: 120,
                decoration: const InputDecoration(labelText: '任务名称'),
              ),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: '备注（可选）'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _interval,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '每隔'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<MaintenanceIntervalUnit>(
                      initialValue: _unit,
                      decoration: const InputDecoration(labelText: '周期单位'),
                      items: [
                        for (final value in MaintenanceIntervalUnit.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(_intervalLabel(value.name)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _unit = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('开始日期'),
                subtitle: Text(_dateTime(_dueAt)),
                trailing: const Icon(Icons.event),
                onTap: _chooseDueAt,
              ),
              const Text('按实际完成日期安排下一次。'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('每日提醒时间'),
                subtitle: Text(_reminder.format(context)),
                trailing: const Icon(Icons.notifications_outlined),
                onTap: _chooseReminder,
              ),
              if (_errorText != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  Future<void> _chooseDueAt() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 10, 12, 31),
    );
    if (picked != null && mounted) setState(() => _dueAt = picked);
  }

  Future<void> _chooseReminder() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminder,
    );
    if (picked != null && mounted) setState(() => _reminder = picked);
  }

  void _save() {
    final amount = int.tryParse(_interval.text.trim());
    if (_title.text.trim().isEmpty || amount == null || amount <= 0) {
      setState(() => _errorText = '请填写任务名称和大于 0 的重复间隔');
      return;
    }
    Navigator.pop(
      context,
      _TaskDraft(
        title: _title.text,
        notes: _notes.text,
        intervalAmount: amount,
        intervalUnit: _unit,
        dueAt: DateTime(
          _dueAt.year,
          _dueAt.month,
          _dueAt.day,
          _reminder.hour,
          _reminder.minute,
        ).toUtc(),
        reminderTime: _timeString(_reminder),
      ),
    );
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    foregroundColor: Theme.of(
                      dialogContext,
                    ).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;

class _TaskDraft {
  const _TaskDraft({
    required this.title,
    required this.notes,
    required this.intervalAmount,
    required this.intervalUnit,
    required this.dueAt,
    required this.reminderTime,
  });

  final String title;
  final String notes;
  final int intervalAmount;
  final MaintenanceIntervalUnit intervalUnit;
  final DateTime dueAt;
  final String reminderTime;
}

enum _TaskDetailAction { complete, snooze, skip }

enum _TaskMenuAction { edit, disable, enable, archive, delete }

String _stateLabel(MaintenanceTaskViewState state) => switch (state) {
  MaintenanceTaskViewState.upcoming => '待处理',
  MaintenanceTaskViewState.overdue => '已逾期',
  MaintenanceTaskViewState.snoozed => '已稍后提醒',
  MaintenanceTaskViewState.completed => '本周期已完成',
  MaintenanceTaskViewState.skipped => '本周期已跳过',
  MaintenanceTaskViewState.disabled => '已停用',
  MaintenanceTaskViewState.archived => '已归档',
};

IconData _stateIcon(MaintenanceTaskViewState state) => switch (state) {
  MaintenanceTaskViewState.upcoming => Icons.schedule,
  MaintenanceTaskViewState.overdue => Icons.warning_amber,
  MaintenanceTaskViewState.snoozed => Icons.snooze,
  MaintenanceTaskViewState.completed => Icons.check,
  MaintenanceTaskViewState.skipped => Icons.skip_next,
  MaintenanceTaskViewState.disabled => Icons.notifications_off_outlined,
  MaintenanceTaskViewState.archived => Icons.archive_outlined,
};

Color _stateColor(
  BuildContext context,
  MaintenanceTaskViewState state,
) => switch (state) {
  MaintenanceTaskViewState.overdue => Theme.of(context).colorScheme.error,
  MaintenanceTaskViewState.completed => Colors.green.shade700,
  MaintenanceTaskViewState.snoozed => Colors.orange.shade800,
  MaintenanceTaskViewState.upcoming => Theme.of(context).colorScheme.primary,
  MaintenanceTaskViewState.skipped ||
  MaintenanceTaskViewState.disabled ||
  MaintenanceTaskViewState.archived => Theme.of(context).colorScheme.outline,
};

String _intervalLabel(String unit) => switch (unit) {
  'day' => '天',
  'week' => '周',
  'month' => '月',
  _ => unit,
};

TimeOfDay _parseTime(String value) {
  final parts = value.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts.firstOrNull ?? '') ?? 9,
    minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
  );
}

String _timeString(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

void _message(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
