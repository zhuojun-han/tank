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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tank.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('trend-parameter-selector'),
                  initialValue: selectedId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '趋势参数'),
                  items: [
                    for (final item in parameters)
                      DropdownMenuItem(
                        value: item.id,
                        child: Text(
                          '${item.code} · ${item.displayName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) onParameterChanged(value);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${parameter.code} 趋势',
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${overview.count} 条记录'),
                TextButton(
                  onPressed: () =>
                      context.push('/test-flow?parameterId=${parameter.id}'),
                  child: const Text('添加检测'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: overview.count == 0
                ? Column(
                    children: [
                      const Icon(Icons.show_chart, size: 40),
                      const SizedBox(height: 8),
                      Text('${parameter.code} 暂无趋势数据'),
                      const SizedBox(height: 4),

                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => parameter.code.toUpperCase() == 'KH'
                            ? context.push(
                                '/test-flow?parameterId=${parameter.id}',
                              )
                            : context.go('/test'),
                        child: Text(
                          parameter.code.toUpperCase() == 'KH'
                              ? '开始 KH 检测'
                              : '手动添加记录',
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_targetLabel(target)),
                      const SizedBox(height: 12),
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
        if (overview.count > 0)
          DatabaseRecordHistory(
            key: ValueKey('${tank.id}:${parameter.id}'),
            overview: overview,
            scope: (tankId: tank.id, parameterId: parameter.id),
            onOpen: (record) => showScopedTestRecordDetails(
              context: context,
              ref: ref,
              record: record,
              tank: tank,
              parameter: parameter,
            ),
          ),
      ],
    );
  }
}
