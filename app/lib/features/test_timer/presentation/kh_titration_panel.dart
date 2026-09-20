import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../test_records/application/test_record_providers.dart';
import '../application/test_session_providers.dart';
import '../domain/kh_titration.dart';
import 'test_workflow_widgets.dart';

class KhTitrationPanel extends ConsumerStatefulWidget {
  const KhTitrationPanel({
    required this.tankId,
    required this.onSaved,
    required this.onCancel,
    required this.onManual,
    super.key,
  });
  final String tankId;
  final VoidCallback onSaved;
  final VoidCallback onCancel;
  final Future<void> Function() onManual;
  @override
  ConsumerState<KhTitrationPanel> createState() => _KhTitrationPanelState();
}

class _KhTitrationPanelState extends ConsumerState<KhTitrationPanel> {
  final _initial = TextEditingController(text: '1');
  final _remaining = TextEditingController();
  KhTitrationResult? _result;
  String? _error;
  bool _busy = true;
  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await ref
          .read(testWorkflowControllerProvider)
          .prepareKhTitration(widget.tankId);
    } catch (error) {
      if (mounted) setState(() => _error = '无法停止原计时：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _initial.dispose();
    _remaining.dispose();
    super.dispose();
  }

  void _calculate() {
    setState(() {
      _result = null;
      _error = null;
      try {
        _result = calculateKhTitration(
          double.tryParse(_initial.text.trim()) ?? double.nan,
          double.tryParse(_remaining.text.trim()) ?? double.nan,
        );
      } on FormatException catch (error) {
        _error = error.message;
      }
    });
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(testRecordRepositoryProvider)
          .createKhTitration(
            tankId: widget.tankId,
            initialMl: result.initialMl,
            remainingMl: result.remainingMl,
            measuredAt: DateTime.now().toUtc(),
          );
      if (mounted) {
        setState(() {
          _remaining.clear();
          _result = null;
        });
        widget.onSaved();
      }
    } catch (error) {
      if (mounted) setState(() => _error = '保存失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _readingField(
    TextEditingController controller,
    String label,
    String key,
  ) => TextField(
    key: Key(key),
    controller: controller,
    enabled: !_busy,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    onChanged: (_) => setState(() {
      _result = null;
      _error = null;
    }),
  );

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('kh-titration'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TestPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('KH 滴定检测', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('填写滴定前后针筒的读数。'),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final fields = [
                  _readingField(_initial, '初始容积（mL）', 'kh-initial'),
                  _readingField(_remaining, '剩余溶剂（mL）', 'kh-remaining'),
                ];
                if (constraints.maxWidth < 330 ||
                    MediaQuery.textScalerOf(context).scale(14) > 18) {
                  return Column(
                    children: [
                      fields.first,
                      const SizedBox(height: 12),
                      fields.last,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: fields.first),
                    const SizedBox(width: 10),
                    Expanded(child: fields.last),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            if (_result == null)
              FilledButton(
                key: const Key('calculate-kh-titration'),
                onPressed: _busy ? null : _calculate,
                child: const Text('计算 KH'),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _error!,
                  key: const Key('kh-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_result case final result?) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('KH 结果'),
                    Text(
                      '${result.displayDkh} dKH',
                      key: const Key('kh-result'),
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const Text('仅供参考'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('save-kh-titration'),
                onPressed: _busy ? null : _save,
                child: const Text('确认并录入'),
              ),
            ],
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {
                        _remaining.clear();
                        _result = null;
                        _error = null;
                      });
                      widget.onCancel();
                    },
              child: const Text('本次不记录'),
            ),
          ],
        ),
      ),
      TestEntryCard(
        key: const Key('manual-kh-entry'),
        title: '手动录入 KH',
        subtitle: '所有关注指标都支持手动记录',
        icon: Icons.keyboard_outlined,
        onTap: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                try {
                  await widget.onManual();
                } catch (error) {
                  if (mounted) setState(() => _error = '无法打开手动录入：$error');
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
      ),
    ],
  );
}
