import 'record_history_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error_view.dart';
import '../../../data/database/app_database.dart';
import '../../tanks/application/tank_providers.dart';
import '../../test_records/presentation/test_records_page.dart';
import '../data/record_history_source.dart';
import 'database_record_history_widgets.dart';

String _targetLabel(WaterQualityTarget? target) {
  final lower = target?.minValue;
  final upper = target?.maxValue;
  if (target == null || (lower == null && upper == null)) return '尚未设置目标范围';
  final bounds = lower == null
      ? '≤${trendNumber(upper!)}'
      : upper == null
      ? '≥${trendNumber(lower)}'
      : '${trendNumber(lower)}–${trendNumber(upper)}';
  return '目标 $bounds ${target.unit}';
}

class TrendsPage extends ConsumerStatefulWidget {
  const TrendsPage({this.initialParameterId, super.key});

  final String? initialParameterId;

  @override
  ConsumerState<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends ConsumerState<TrendsPage> {
  String? _selectedParameterId;

  @override
  void initState() {
    super.initState();
    _selectedParameterId = widget.initialParameterId;
  }

  @override
  void didUpdateWidget(covariant TrendsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialParameterId != oldWidget.initialParameterId) {
      _selectedParameterId = widget.initialParameterId;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(currentTankProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppErrorView(message: '无法读取当前海缸：$error'),
          data: (tank) {
            if (tank == null) return const AppErrorView(message: '请先创建海缸。');
            return ref
                .watch(enabledParametersProvider(tank.id))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => AppErrorView(message: '无法读取趋势参数：$error'),
                  data: (parameters) {
                    if (parameters.isEmpty) {
                      return const AppErrorView(message: '当前海缸没有启用的检测参数。');
                    }
                    final selectedId =
                        parameters.any(
                          (item) => item.id == _selectedParameterId,
                        )
                        ? _selectedParameterId!
                        : parameters.first.id;
                    final parameter = parameters.firstWhere(
                      (item) => item.id == selectedId,
                    );
                    return ref
                        .watch(
                          recordHistoryOverviewProvider((
                            tankId: tank.id,
                            parameterId: selectedId,
                          )),
                        )
                        .when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, _) =>
                              AppErrorView(message: '无法读取趋势记录：$error'),
                          data: (overview) => ref
                              .watch(waterQualityTargetsProvider(tank.id))
                              .when(
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (error, _) =>
                                    AppErrorView(message: '无法读取目标范围：$error'),
                                data: (targets) {
                                  final target = targets
                                      .where(
                                        (item) =>
                                            item.parameterId == selectedId,
                                      )
                                      .firstOrNull;
                                  return _TrendContent(
                                    tank: tank,
                                    parameters: parameters,
                                    parameter: parameter,
                                    selectedId: selectedId,
                                    overview: overview,
                                    target: target,
                                    onParameterChanged: (value) {
                                      setState(
                                        () => _selectedParameterId = value,
                                      );
                                    },
                                  );
                                },
                              ),
                        );
                  },
                );
          },
        );
  }
}

class _TrendContent extends ConsumerWidget {
  const _TrendContent({
    required this.tank,
    required this.parameters,
    required this.parameter,
    required this.selectedId,
    required this.overview,
    required this.target,
    required this.onParameterChanged,
  });

  final Tank tank;
  final List<WaterParameter> parameters;
  final WaterParameter parameter;
  final String selectedId;
  final RecordHistoryOverview overview;
  final WaterQualityTarget? target;
  final ValueChanged<String> onParameterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final latest = overview.latest;
    void addRecord() => context.push('/test-flow?parameterId=${parameter.id}');
    void openRecord(TestRecord record) => showScopedTestRecordDetails(
      context: context,
      ref: ref,
      record: record,
      tank: tank,
      parameter: parameter,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text('历史趋势', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text('水质变化', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text('选择关注指标查看历史', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 18),
        SingleChildScrollView(
          key: const Key('trend-parameter-selector'),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in parameters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ParameterCard(
                    parameter: item,
                    selected: item.id == selectedId,
                    onTap: () => onParameterChanged(item.id),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Card(
          key: const Key('trend-summary'),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('当前结果', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 4),
                        Text(
                          latest == null
                              ? '暂无记录'
                              : '${recordTrendValue(latest)} ${latest.unit}',
                          style: theme.textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    TextButton(
                      key: const Key('trend-target-editor'),
                      onPressed: () => showWaterQualityTargetEditor(
                        context,
                        ref,
                        tankId: tank.id,
                        parameter: parameter,
                        target: target,
                      ),
                      child: Text(_targetLabel(target)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (overview.count == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.show_chart,
                          size: 40,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text('${parameter.code} 暂无趋势数据'),
                      ],
                    ),
                  )
                else
                  DatabaseRecordChart(
                    key: const Key('trend-chart'),
                    overview: overview,
                    scope: (tankId: tank.id, parameterId: parameter.id),
                    target: target,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        DatabaseRecordHistory(
          key: ValueKey('${tank.id}:${parameter.id}'),
          overview: overview,
          scope: (tankId: tank.id, parameterId: parameter.id),
          headerTrailing: TextButton.icon(
            key: const Key('trend-add-record'),
            onPressed: addRecord,
            icon: const Icon(Icons.add),
            label: const Text('添加'),
          ),
          onOpen: openRecord,
          rowBuilder: (record) => TrendRecordCard(
            record: record,
            parameter: parameter,
            onTap: () => openRecord(record),
          ),
        ),
      ],
    );
  }
}

class _ParameterCard extends StatelessWidget {
  const _ParameterCard({
    required this.parameter,
    required this.selected,
    required this.onTap,
  });
  final WaterParameter parameter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: parameter.displayName,
      selected: selected,
      button: true,
      child: Material(
        color: selected ? scheme.secondaryContainer : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: InkWell(
          key: Key('trend-parameter-${parameter.id}'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parameter.code,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  parameter.unit,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A record is a separate tappable card; only its result and date are repeated here.
class TrendRecordCard extends StatelessWidget {
  const TrendRecordCard({
    required this.record,
    required this.parameter,
    required this.onTap,
    super.key,
  });
  final TestRecord record;
  final WaterParameter parameter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range =
        record.confirmedMaxValue != null &&
        record.confirmedMaxValue != record.confirmedMinValue;
    final point =
        record.confirmedInterpolation ??
        (range ? null : record.confirmedMinValue);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        key: Key('trend-record-${record.id}'),
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 76),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  parameter.code,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${recordTrendValue(record)} ${record.unit}',
                      style: theme.textTheme.titleMedium,
                    ),
                    if (range)
                      Text(
                        '插值 / 单值：${point == null ? '未填' : '${trendNumber(point)} ${record.unit}'}',
                      ),
                    const SizedBox(height: 5),
                    Text(
                      recordDate(record.measuredAt),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
