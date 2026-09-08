import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/water_quality_advice_provider.dart';
import '../domain/water_quality_advice.dart';

class WaterQualityAdviceSection extends ConsumerWidget {
  const WaterQualityAdviceSection({required this.tankId, super.key});

  final String tankId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advice = ref.watch(waterQualityAdviceProvider(tankId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('水质维护建议', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        advice.when(
          data: (items) => Column(
            children: [for (final item in items) _AdviceCard(advice: item)],
          ),
          error: (error, _) => Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('无法生成维护建议'),
              subtitle: Text('$error'),
            ),
          ),
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.advice});

  final WaterQualityAdvice advice;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, advice.status);
    return Card(
      key: Key('advice-card-${advice.parameterCode}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  foregroundColor: color,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(_statusIcon(advice.status)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${advice.parameterCode} · ${advice.parameterName}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        advice.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(advice.summary),
            const SizedBox(height: 12),
            _FactRow(label: '触发记录', value: _recordText(advice)),
            _FactRow(label: '用户目标', value: _targetText(advice)),
            const SizedBox(height: 12),
            Text('建议检查', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            for (final action in advice.actions)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(action)),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            ExpansionTile(
              key: Key('advice-basis-${advice.parameterCode}'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text('建议依据'),
              children: [
                _FactRow(label: '判断依据', value: advice.trigger),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    advice.sources.isEmpty ? '暂无专用规则来源' : '规则来源',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                if (advice.sources.isNotEmpty)
                  for (final source in advice.sources)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SelectableText('${source.title}\n${source.url}'),
                      ),
                    ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: const Text('异常时先复测，并观察生物状态；需要时咨询专业人士。'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

String _recordText(WaterQualityAdvice advice) {
  final record = advice.latestConfirmedRecord;
  if (record == null) return '暂无人工确认记录';
  final value = record.maxValue == null
      ? _number(record.minValue)
      : '${_number(record.minValue)}–${_number(record.maxValue!)}';
  return '人工确认 $value ${record.unit} · ${_dateTime(record.measuredAt)}';
}

String _targetText(WaterQualityAdvice advice) {
  final target = advice.userTarget;
  if (target == null) return '尚未设置';
  return '${_number(target.minValue)}–${_number(target.maxValue)} ${target.unit}';
}

Color _statusColor(BuildContext context, WaterQualityAdviceStatus status) {
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    WaterQualityAdviceStatus.withinTarget => Colors.green.shade700,
    WaterQualityAdviceStatus.aboveTarget => scheme.error,
    WaterQualityAdviceStatus.belowTarget => Colors.blue.shade700,
    WaterQualityAdviceStatus.retestRequired => Colors.orange.shade800,
    WaterQualityAdviceStatus.insufficientData ||
    WaterQualityAdviceStatus.unsupportedParameter => scheme.outline,
  };
}

IconData _statusIcon(WaterQualityAdviceStatus status) => switch (status) {
  WaterQualityAdviceStatus.withinTarget => Icons.check,
  WaterQualityAdviceStatus.aboveTarget => Icons.arrow_upward,
  WaterQualityAdviceStatus.belowTarget => Icons.arrow_downward,
  WaterQualityAdviceStatus.retestRequired => Icons.replay,
  WaterQualityAdviceStatus.insufficientData ||
  WaterQualityAdviceStatus.unsupportedParameter => Icons.info_outline,
};

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value
          .toStringAsFixed(3)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
