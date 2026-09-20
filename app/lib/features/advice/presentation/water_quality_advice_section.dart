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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('根据最近检测', style: Theme.of(context).textTheme.labelMedium),
        Text(
          '建议先做这些',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        advice.when(
          data: (items) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in items) _AdviceCard(advice: item),
              if (items.isNotEmpty)
                Material(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    key: const Key('home-advice-basis'),
                    title: const Text('查看建议依据'),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    children: [
                      for (final item in items) _AdviceBasis(advice: item),
                    ],
                  ),
                ),
            ],
          ),
          error: (error, _) => Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('无法生成维护建议'),
              subtitle: Text('$error'),
            ),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: Key('advice-card-${advice.parameterCode}'),
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      color: Color.alphaBlend(color.withValues(alpha: .035), scheme.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    foregroundColor: color,
                    backgroundColor: color.withValues(alpha: .13),
                    child: Icon(_statusIcon(advice.status), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${advice.parameterCode} · 目标 ${_targetText(advice)}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          advice.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                advice.summary,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              for (final action in advice.actions)
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Icon(Icons.circle, size: 5),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(action)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdviceBasis extends StatelessWidget {
  const _AdviceBasis({required this.advice});
  final WaterQualityAdvice advice;
  @override
  Widget build(BuildContext context) => Padding(
    key: Key('advice-basis-${advice.parameterCode}'),
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${advice.parameterCode} · ${advice.parameterName}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        _FactRow(label: '触发记录', value: _recordText(advice)),
        _FactRow(label: '用户目标', value: _targetText(advice)),
        _FactRow(label: '判断依据', value: advice.trigger),
        const SizedBox(height: 10),
        for (final source in advice.sources)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SelectableText('${source.title}\n${source.url}'),
          ),
        const SizedBox(height: 10),
        const Text('异常时先复测，并观察生物状态；需要时咨询专业人士。'),
      ],
    ),
  );
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
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (status) {
    WaterQualityAdviceStatus.withinTarget =>
      dark ? const Color(0xFF8DE1BC) : const Color(0xFF247A5D),
    WaterQualityAdviceStatus.aboveTarget => scheme.error,
    WaterQualityAdviceStatus.belowTarget =>
      dark ? const Color(0xFFEACB7F) : const Color(0xFF8A661E),
    WaterQualityAdviceStatus.retestRequired =>
      dark ? const Color(0xFFF6C78D) : Colors.orange.shade800,
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
