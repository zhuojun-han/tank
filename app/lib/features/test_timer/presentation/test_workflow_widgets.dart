import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/database/app_database.dart';

/// The web detection page's panel, with native text scaling and tap targets.
class TestPanel extends StatelessWidget {
  const TestPanel({required this.child, this.tinted = false, super.key});
  final Widget child;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tinted ? colors.primaryContainer : colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(28),
      ),
      child: child,
    );
  }
}

class TestParameterTabs extends StatelessWidget {
  const TestParameterTabs({
    required this.parameters,
    required this.selectedId,
    required this.onSelected,
    this.onManage,
    super.key,
  });
  final List<WaterParameter> parameters;
  final String selectedId;
  final ValueChanged<String>? onSelected;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      key: const Key('test-parameter-tabs'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final parameter in parameters)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: Semantics(
                selected: selectedId == parameter.id,
                child: OutlinedButton(
                  key: Key('workflow-parameter-${parameter.id}'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: selectedId == parameter.id
                        ? colors.primary
                        : colors.surface,
                    foregroundColor: selectedId == parameter.id
                        ? colors.onPrimary
                        : colors.onSurface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onSelected == null
                      ? null
                      : () => onSelected!(parameter.id),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parameter.code,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        parameter.displayName,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (onManage != null)
            IconButton.outlined(
              tooltip: '管理关注指标',
              onPressed: onManage,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
    );
  }
}

class TestTimerDial extends StatelessWidget {
  const TestTimerDial({
    required this.remaining,
    required this.total,
    required this.label,
    this.completed = false,
    super.key,
  });
  final int remaining, total;
  final String label;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final clock =
        '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}';
    return Center(
      child: SizedBox.square(
        dimension: 204,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CircularProgressIndicator(
                value: completed
                    ? 1.0
                    : (total <= 0 ? 0.0 : remaining / total).clamp(0.0, 1.0),
                strokeWidth: 9,
                color: const Color(0xffee7b66),
                backgroundColor: colors.surfaceContainerHighest,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    completed ? '已完成' : clock,
                    key: const Key('test-timer-countdown'),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TestEntryCard extends StatelessWidget {
  const TestEntryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    super.key,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: colors.onSecondaryContainer),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class TestDurationEditor extends StatefulWidget {
  const TestDurationEditor({
    required this.seconds,
    required this.onChanged,
    this.onValidityChanged,
    super.key,
  });
  final int seconds;
  final ValueChanged<int> onChanged;
  final ValueChanged<bool>? onValidityChanged;
  @override
  State<TestDurationEditor> createState() => _TestDurationEditorState();
}

class _TestDurationEditorState extends State<TestDurationEditor> {
  late final _minutes = TextEditingController(text: '${widget.seconds ~/ 60}');
  late final _seconds = TextEditingController(text: '${widget.seconds % 60}');
  int? _lastSubmitted;
  String? _error;
  final _minutesFocus = FocusNode();
  final _secondsFocus = FocusNode();

  @override
  void didUpdateWidget(TestDurationEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seconds != oldWidget.seconds &&
        widget.seconds != _lastSubmitted &&
        !_minutesFocus.hasFocus &&
        !_secondsFocus.hasFocus) {
      _minutes.text = '${widget.seconds ~/ 60}';
      _seconds.text = '${widget.seconds % 60}';
      _error = null;
    }
  }

  void _change() {
    final minutes = int.tryParse(_minutes.text);
    final seconds = int.tryParse(_seconds.text);
    final duration = minutes == null || seconds == null
        ? null
        : minutes * 60 + seconds;
    if (duration == null || seconds! > 59 || duration < 10 || duration > 3600) {
      setState(() => _error = '请输入 10 秒至 60 分钟');
      widget.onValidityChanged?.call(false);
      return;
    }
    setState(() => _error = null);
    _lastSubmitted = duration;
    widget.onValidityChanged?.call(true);
    widget.onChanged(duration);
  }

  @override
  void dispose() {
    _minutes.dispose();
    _seconds.dispose();
    _minutesFocus.dispose();
    _secondsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final seconds in const [180, 300, 600])
            ChoiceChip(
              label: Text('${seconds ~/ 60} 分钟'),
              selected: widget.seconds == seconds,
              onSelected: (_) {
                _lastSubmitted = seconds;
                setState(() {
                  _minutes.text = '${seconds ~/ 60}';
                  _seconds.text = '0';
                  _error = null;
                });
                widget.onValidityChanged?.call(true);
                widget.onChanged(seconds);
              },
            ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('custom-duration-minutes'),
              controller: _minutes,
              focusNode: _minutesFocus,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '自定义默认时间',
                suffixText: '分',
              ),
              onChanged: (_) => _change(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: const Key('custom-duration-seconds'),
              controller: _seconds,
              focusNode: _secondsFocus,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '秒',
                suffixText: '秒',
              ),
              onChanged: (_) => _change(),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        _error ?? '10 秒–60 分钟，自动保存默认时间。',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: _error == null ? null : Theme.of(context).colorScheme.error,
        ),
      ),
    ],
  );
}
