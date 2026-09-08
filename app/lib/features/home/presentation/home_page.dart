import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error_view.dart';
import '../../../data/database/app_database.dart';
import '../../advice/presentation/water_quality_advice_section.dart';
import '../../aquarium/application/aquarium_providers.dart';
import '../../aquarium/presentation/aquarium_card.dart';
import '../../aquarium/presentation/fish_manager_sheet.dart';
import '../../maintenance/application/maintenance_providers.dart';
import '../../maintenance/data/maintenance_repository.dart';
import '../../tanks/application/tank_providers.dart';
import '../../test_records/application/test_record_providers.dart';
import '../../trends/data/record_history_source.dart';
import '../../trends/presentation/database_record_history_widgets.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clock = ref.watch(maintenanceDateProvider);
    return ref
        .watch(currentTankProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppErrorView(message: '无法读取本地海缸：$error'),
          data: (tank) {
            if (tank == null) {
              return const AppErrorView(message: '没有可用海缸，请前往设置创建。');
            }
            return ref
                .watch(enabledParametersProvider(tank.id))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => AppErrorView(message: '无法读取参数：$error'),
                  data: (parameters) => ref
                      .watch(latestTestRecordsProvider(tank.id))
                      .when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) =>
                            AppErrorView(message: '无法读取最近记录：$error'),
                        data: (records) => ref
                            .watch(waterQualityTargetsProvider(tank.id))
                            .when(
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (error, _) =>
                                  AppErrorView(message: '无法读取目标范围：$error'),
                              data: (targets) => _HomeContent(
                                tank: tank,
                                parameters: parameters,
                                records: records,
                                targets: targets,
                                now: clock,
                              ),
                            ),
                      ),
                );
          },
        );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({
    required this.tank,
    required this.parameters,
    required this.records,
    required this.targets,
    required this.now,
  });

  final Tank tank;
  final List<WaterParameter> parameters;
  final List<TestRecord> records;
  final List<WaterQualityTarget> targets;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabledIds = parameters.map((item) => item.id).toSet();
    final relevantRecords = [
      for (final record in records)
        if (enabledIds.contains(record.parameterId)) record,
    ];
    final latestByParameter = <String, TestRecord>{};
    for (final record in relevantRecords) {
      final current = latestByParameter[record.parameterId];
      if (current == null ||
          record.measuredAt.isAfter(current.measuredAt) ||
          (record.measuredAt.isAtSameMomentAs(current.measuredAt) &&
              record.updatedAt.isAfter(current.updatedAt))) {
        latestByParameter[record.parameterId] = record;
      }
    }
    final targetByParameter = {
      for (final target in targets) target.parameterId: target,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        ref
            .watch(fishStockProvider(tank.id))
            .when(
              loading: () => const Card(
                child: SizedBox(
                  height: 232,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, _) => Card(
                child: SizedBox(
                  height: 232,
                  child: Center(child: Text('无法读取鱼类档案：$error')),
                ),
              ),
              data: (items) => AquariumCard(
                tankName: tank.name,
                items: items,
                onTap: () async {
                  final saved = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => FishManagerSheet(
                      tankId: tank.id,
                      tankName: tank.name,
                      initialItems: items,
                    ),
                  );
                  if (saved == true && context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('鱼类档案已保存')));
                  }
                },
              ),
            ),
        const SizedBox(height: 16),
        Text(
          '今日 · ${_date(now)}',
          key: const Key('device-date'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.set_meal_outlined)),
            title: Text(tank.name),
            subtitle: Text(tank.notes ?? '当前海缸 · 数据仅保存在本机'),
            trailing: const Icon(Icons.settings_outlined),
            onTap: () => context.push('/settings'),
          ),
        ),
        const SizedBox(height: 20),
        Text('今日未完成维护', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Consumer(
          builder: (context, ref, _) => ref
              .watch(todayMaintenanceTasksProvider(tank.id))
              .when(
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (error, _) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text('无法读取维护任务'),
                    subtitle: Text('$error'),
                  ),
                ),
                data: (items) => items.isEmpty
                    ? const Card(
                        child: ListTile(
                          leading: Icon(Icons.task_alt),
                          title: Text('当前没有未完成维护事项'),
                          subtitle: Text('可在“任务”页新增周期维护提醒。'),
                        ),
                      )
                    : Card(
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < items.length;
                              index++
                            ) ...[
                              _HomeTaskTile(
                                item: items[index],
                                onComplete: () async {
                                  try {
                                    await ref
                                        .read(maintenanceRepositoryProvider)
                                        .complete(
                                          tankId: tank.id,
                                          taskId: items[index].task.id,
                                          occurrenceDate:
                                              items[index].occurrenceDate,
                                        );
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('完成任务失败：$error'),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                              if (index < items.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                      ),
              ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('最近检测', style: Theme.of(context).textTheme.titleMedium),
            TextButton(
              onPressed: () => context.go('/test'),
              child: const Text('添加记录'),
            ),
          ],
        ),
        if (relevantRecords.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.science_outlined, size: 40),
                  const SizedBox(height: 8),
                  const Text('还没有检测记录'),
                  const SizedBox(height: 4),
                  const Text('开始第一次检测，或直接添加手动记录。'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go('/test'),
                    child: const Text('手动添加记录'),
                  ),
                ],
              ),
            ),
          ),
        for (final parameter in parameters)
          _LatestRecordCard(
            parameter: parameter,
            record: latestByParameter[parameter.id],
            target: targetByParameter[parameter.id],
            tankId: tank.id,
          ),
        const SizedBox(height: 20),
        WaterQualityAdviceSection(tankId: tank.id),
      ],
    );
  }
}

class _HomeTaskTile extends ConsumerWidget {
  const _HomeTaskTile({required this.item, required this.onComplete});

  final MaintenanceTaskItem item;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue = item.state == MaintenanceTaskViewState.overdue;
    return ListTile(
      key: Key('home-maintenance-${item.task.id}'),
      leading: Icon(
        overdue ? Icons.warning_amber : Icons.schedule,
        color: overdue ? Theme.of(context).colorScheme.error : null,
      ),
      title: Text(
        isChemicalPlan(item.task)
            ? '${item.task.source == 'alkalinity-plan' ? 'KH' : 'PO4'} 总计划 · 今日事项'
            : item.task.title,
      ),
      subtitle: Text(
        '${overdue
            ? '已逾期'
            : item.state == MaintenanceTaskViewState.snoozed
            ? '已稍后提醒'
            : '待处理'}'
        ' · ${_dateTime(item.task.dueAt)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '标记完成',
            onPressed: onComplete,
            icon: const Icon(Icons.check_circle_outline),
          ),
          PopupMenuButton<String>(
            onSelected: (action) async {
              try {
                final repo = ref.read(maintenanceRepositoryProvider);
                if (action == 'snooze') {
                  await repo.snooze(
                    tankId: item.task.tankId,
                    taskId: item.task.id,
                    occurrenceDate: item.occurrenceDate,
                    until: DateTime.now().add(const Duration(hours: 1)),
                  );
                } else {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialog) => AlertDialog(
                      title: const Text('停止后续计划？'),
                      content: const Text('今天及后续未完成事项将停止，历史记录保留。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialog, true),
                          child: const Text('停止计划'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  if (item.task.isOneOff) {
                    await repo.skip(
                      tankId: item.task.tankId,
                      taskId: item.task.id,
                    );
                  } else {
                    await repo.stopRecurring(
                      tankId: item.task.tankId,
                      taskId: item.task.id,
                      from: item.occurrenceDate ?? DateTime.now(),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'snooze', child: Text('稍后 1 小时')),
              if (isChemicalPlan(item.task) || !item.task.isOneOff)
                const PopupMenuItem(value: 'stop', child: Text('停止后续计划')),
            ],
          ),
        ],
      ),
      onTap: () => context.go('/maintenance'),
    );
  }
}

class _LatestRecordCard extends ConsumerWidget {
  const _LatestRecordCard({
    required this.parameter,
    required this.record,
    required this.target,
    required this.tankId,
  });

  final WaterParameter parameter;
  final TestRecord? record;
  final WaterQualityTarget? target;
  final String tankId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = record;
    final scope = (tankId: tankId, parameterId: parameter.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/trends?parameterId=${parameter.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item == null
                          ? '${parameter.code} · ${parameter.displayName}'
                          : '${parameter.code} · ${_recordValue(item)} ${item.unit}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const Icon(Icons.show_chart),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item == null
                    ? '尚无历史记录 · 尚未设置可比较的最近值'
                    : '${_dateTime(item.measuredAt)} · ${_targetDescription(item, target)}',
              ),
              const SizedBox(height: 12),
              if (item == null)
                Container(
                  key: Key('home-trend-empty-${parameter.id}'),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('暂无检测记录'),
                )
              else ...[
                ref
                    .watch(recordHistoryOverviewProvider(scope))
                    .when(
                      data: (overview) => DatabaseRecordChart(
                        key: Key('home-trend-chart-${parameter.id}'),
                        scope: scope,
                        overview: overview,
                        bars: true,
                        target: target,
                      ),
                      loading: () => const SizedBox(
                        height: 170,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, _) => Text('无法读取趋势：$error'),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _targetDescription(TestRecord record, WaterQualityTarget? target) {
  if (target == null) return '尚未设置目标范围';
  final lower = record.confirmedMinValue;
  final upper = record.confirmedMaxValue ?? lower;
  final status = upper < target.minValue
      ? '低于目标'
      : lower > target.maxValue
      ? '高于目标'
      : lower >= target.minValue && upper <= target.maxValue
      ? '目标范围内'
      : '部分跨越目标范围';
  return '$status · 目标 ${_number(target.minValue)}–${_number(target.maxValue)} ${target.unit}';
}

String _recordValue(TestRecord record) => record.confirmedMaxValue == null
    ? _number(record.confirmedMinValue)
    : '${_number(record.confirmedMinValue)}–${_number(record.confirmedMaxValue!)}';

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value
          .toStringAsFixed(3)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.year}年${local.month}月${local.day}日';
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
