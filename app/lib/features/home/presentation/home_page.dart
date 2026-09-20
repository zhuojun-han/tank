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
import '../../maintenance/domain/rolling_schedule.dart';
import '../../maintenance/presentation/task_schedule_dialogs.dart';
import '../../calculators/application/maintenance_cycle_providers.dart';
import '../../calculators/domain/maintenance_cycle.dart';
import '../../tanks/application/tank_providers.dart';
import '../../tanks/domain/tank_age.dart';
import '../../settings/presentation/settings_entry_dialog.dart';
import '../../settings/presentation/settings_page.dart';
import '../../test_records/application/test_record_providers.dart';
import '../../trends/data/record_history_source.dart';
import '../../trends/presentation/database_record_history_widgets.dart';
import '../../trends/presentation/record_history_widgets.dart';

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
    final latestByParameter = <String, TestRecord>{};
    for (final record in records) {
      final previous = latestByParameter[record.parameterId];
      if (previous == null ||
          record.measuredAt.isAfter(previous.measuredAt) ||
          (record.measuredAt.isAtSameMomentAs(previous.measuredAt) &&
              record.updatedAt.isAfter(previous.updatedAt))) {
        latestByParameter[record.parameterId] = record;
      }
    }
    final targetByParameter = {
      for (final target in targets) target.parameterId: target,
    };
    final taskState = ref.watch(todayMaintenanceTasksProvider(tank.id));
    final cycles = maintenanceCycleOccurrences(
      ref.watch(maintenanceCyclesProvider(tank.id)).value ?? const [],
      tankId: tank.id,
      start: now,
      days: 1,
      now: now,
    );
    final refillCount = cycles.where((item) => item.isDue).length;
    final taskCount = (taskState.value?.length ?? 0) + refillCount;
    return ListView(
      key: const Key('home-scroll'),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
      children: [
        ref
            .watch(fishStockProvider(tank.id))
            .when(
              loading: () => const SizedBox(
                height: 278,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text('无法读取鱼类档案：$error'),
              data: (items) => AquariumCard(
                tankName: tank.name,
                runningDays: tankAgeDays(tank.startedOn, now),
                onManageTank: () => showTankEditor(context, tank: tank),
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
        const SizedBox(height: 20),
        Text(
          '今日 · ${_date(now)}',
          key: const Key('device-date'),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 5),
        Text(
          '${tank.name}\n水质改善建议',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            key: const Key('home-metric-grid'),
            spacing: 12,
            runSpacing: 12,
            children: [
              for (
                var index = 0;
                index < parameters.length && index < 4;
                index++
              )
                SizedBox(
                  width: (constraints.maxWidth - 12) / 2,
                  child: _MetricCard(
                    parameter: parameters[index],
                    record: latestByParameter[parameters[index].id],
                    target: targetByParameter[parameters[index].id],
                    coral: index.isEven,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        WaterQualityAdviceSection(
          key: const Key('home-advice-section'),
          tankId: tank.id,
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          key: const Key('home-manage-parameters'),
          icon: const Icon(Icons.add),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ParameterSettingsPage(tank: tank),
            ),
          ),
          label: Text('管理 ${tank.name} 的关注指标', textAlign: TextAlign.center),
        ),
        _HomeCycles(tankId: tank.id, date: now),
        const SizedBox(height: 22),
        _HomeSectionTitle(
          key: const Key('home-todos-heading'),
          eyebrow: '仅今天 · $taskCount 项',
          title: '今日待办',
          action: TextButton(
            onPressed: () => context.go('/maintenance'),
            child: const Text('查看任务'),
          ),
        ),
        const SizedBox(height: 10),
        _HomeCycles(tankId: tank.id, date: now, dueOnly: true),
        taskState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('无法读取维护任务：$error'),
          data: (items) => items.isEmpty && refillCount == 0
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline),
                        SizedBox(width: 12),
                        Expanded(child: Text('当前没有未完成维护事项')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (final item in items)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: _HomeTaskTile(
                          item: item,
                          onComplete: () =>
                              _completeHomeTask(context, ref, item),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 22),
        const _HomeSectionTitle(
          key: Key('home-trends-heading'),
          eyebrow: '最近检测',
          title: '水质趋势',
        ),
        const SizedBox(height: 10),
        for (final parameter in parameters)
          _LatestRecordCard(
            parameter: parameter,
            record: latestByParameter[parameter.id],
            target: targetByParameter[parameter.id],
            tankId: tank.id,
          ),
      ],
    );
  }
}

Future<void> _completeHomeTask(
  BuildContext context,
  WidgetRef ref,
  MaintenanceTaskItem item,
) async {
  final schedule = rollingSchedule(item.task);
  final completed = await showTaskCompletionDate(
    context,
    firstDate: DateTime.parse(schedule.startDate),
  );
  if (completed == null) return;
  try {
    await ref
        .read(maintenanceRepositoryProvider)
        .complete(
          tankId: item.task.tankId,
          taskId: item.task.id,
          completedDate: completed,
          expectedRevision: schedule.revision,
          occurrenceDate: item.occurrenceDate,
        );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('完成任务失败：$error')));
    }
  }
}

class _HomeSectionTitle extends StatelessWidget {
  const _HomeSectionTitle({
    required this.eyebrow,
    required this.title,
    this.action,
    super.key,
  });
  final String eyebrow, title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 8,
    children: [
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow, style: Theme.of(context).textTheme.labelMedium),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
      ?action,
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.parameter,
    required this.record,
    required this.target,
    required this.coral,
  });
  final WaterParameter parameter;
  final TestRecord? record;
  final WaterQualityTarget? target;
  final bool coral;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark
        ? (coral ? const Color(0xFFFFE7DE) : const Color(0xFFD9F2EC))
        : (coral ? const Color(0xFF733D32) : const Color(0xFF195F5A));
    final colors = dark
        ? (coral
              ? const [Color(0xFF513A32), Color(0xFF603E33)]
              : const [Color(0xFF214944), Color(0xFF235950)])
        : (coral
              ? const [Color(0xFFFFF0E6), Color(0xFFF9D4C4)]
              : const [Color(0xFFD9F2EC), Color(0xFFBDE2D8)]);
    return Semantics(
      button: true,
      label:
          '${parameter.code}，${record == null ? '暂无记录' : '${_recordValue(record!)} ${parameter.unit}'}，查看趋势',
      child: Material(
        key: Key('home-metric-${parameter.id}'),
        borderRadius: BorderRadius.circular(23),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: InkWell(
            onTap: () => context.go('/trends?parameterId=${parameter.id}'),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 168),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: foreground),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            parameter.code,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: dark ? .1 : .6,
                              ),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              child: Text('最近', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        record == null ? '--' : _recordValue(record!),
                        style: const TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        parameter.unit,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        record == null
                            ? '暂无检测记录'
                            : _targetDescription(record!, target),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTaskTile extends ConsumerWidget {
  const _HomeTaskTile({required this.item, required this.onComplete});
  final MaintenanceTaskItem item;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planned = isChemicalPlan(item.task) || !item.task.isOneOff;
    Future<void> change(bool delay) async {
      try {
        final revision = rollingSchedule(item.task).revision;
        final repo = ref.read(maintenanceRepositoryProvider);
        if (delay) {
          final days = await showTaskDelayDays(context);
          if (days == null) return;
          await repo.delayTask(
            tankId: item.task.tankId,
            taskId: item.task.id,
            days: days,
            expectedRevision: revision,
          );
        } else {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialog) => AlertDialog(
              title: Text(planned ? '停止后续计划？' : '跳过任务？'),
              content: Text(planned ? '今天及后续未完成事项将停止，历史记录保留。' : '此任务将标记为跳过。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: const Text('确认'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
          await repo.skip(
            tankId: item.task.tankId,
            taskId: item.task.id,
            expectedRevision: revision,
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('操作失败：$error')));
        }
      }
    }

    return Padding(
      key: Key('home-maintenance-${item.task.id}'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isChemicalPlan(item.task)
                ? '${item.task.source == 'alkalinity-plan' ? 'KH' : 'PO4'} 总计划 · 今日事项'
                : item.task.title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(_dateTime(item.task.dueAt)),
          if (item.task.notes?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(item.task.notes!),
          ],
          const SizedBox(height: 8),
          FilledButton(onPressed: onComplete, child: const Text('完成任务')),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => change(true),
                  child: const Text('延迟'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => change(false),
                  child: Text(planned ? '停止后续计划' : '跳过'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeCycles extends ConsumerWidget {
  const _HomeCycles({
    required this.tankId,
    required this.date,
    this.dueOnly = false,
  });
  final String tankId;
  final DateTime date;
  final bool dueOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(maintenanceCyclesProvider(tankId))
      .when(
        loading: () => const SizedBox.shrink(),
        error: (error, _) => Text('无法读取每日平衡：$error'),
        data: (cycles) {
          final items = maintenanceCycleOccurrences(
            cycles,
            tankId: tankId,
            start: date,
            days: 1,
            now: date,
          ).where((item) => dueOnly ? item.isDue : item.isCompleted).toList();
          if (items.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!dueOnly) ...[
                const SizedBox(height: 22),
                const _HomeSectionTitle(
                  key: Key('home-dosing-heading'),
                  eyebrow: '今日状态',
                  title: '每日平衡',
                ),
                const SizedBox(height: 10),
              ],
              for (final item in items)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    key: Key('home-cycle-${item.cycle.id}'),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(item.remainingLabel),
                        Text(item.detail),
                        const SizedBox(height: 8),
                        if (item.isCompleted)
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 18),
                              const SizedBox(width: 4),
                              const Text('已完成'),
                              if (item.cycle.closedOnDate == null)
                                TextButton(
                                  onPressed: () => context.push(
                                    '/maintenance-dosing?chemical=${item.cycle.chemical.name}',
                                  ),
                                  child: const Text('提前配液'),
                                ),
                            ],
                          )
                        else ...[
                          FilledButton(
                            onPressed: () => context.push(
                              '/maintenance-dosing?chemical=${item.cycle.chemical.name}',
                            ),
                            child: const Text('添加滴定液'),
                          ),
                          OutlinedButton(
                            onPressed: () async {
                              final days = await showTaskDelayDays(context);
                              if (days == null) return;
                              try {
                                await ref
                                    .read(maintenanceCycleRepositoryProvider)
                                    .delay(
                                      item.cycle.id,
                                      days,
                                      expectedDeferredUntil:
                                          item.cycle.refillDeferredUntil,
                                    );
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('延迟失败：$error')),
                                  );
                                }
                              }
                            },
                            child: const Text('延迟'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );
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
      margin: const EdgeInsets.only(bottom: 14),
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
              if (item != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${_dateTime(item.measuredAt)} · ${_targetDescription(item, target)}',
                ),
              ],
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
  final min = target?.minValue;
  final max = target?.maxValue;
  if (target == null || (min == null && max == null)) return '尚未设置目标范围';
  final lower = record.confirmedMinValue;
  final upper = record.confirmedMaxValue ?? lower;
  final status = min != null && upper < min
      ? '低于目标'
      : max != null && lower > max
      ? '高于目标'
      : (min == null || lower >= min) && (max == null || upper <= max)
      ? '目标范围内'
      : '部分跨越目标范围';
  final bounds = min == null
      ? '≤${_number(max!)}'
      : max == null
      ? '≥${_number(min)}'
      : '${_number(min)}–${_number(max)}';
  return '$status · 目标 $bounds ${target.unit}';
}

String _recordValue(TestRecord record) => recordTrendValue(record);

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
