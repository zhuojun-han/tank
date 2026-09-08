import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../test_records/application/test_record_providers.dart';
import '../application/test_session_providers.dart';
import '../domain/kh_titration.dart';

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
      if (mounted) widget.onSaved();
    } catch (error) {
      if (mounted) setState(() => _error = '保存失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('kh-titration'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('KH 滴定检测', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text('滴定完成后，填写针筒初始容积和剩余溶剂。'),
      const SizedBox(height: 16),
      for (final field in [
        (controller: _initial, label: '初始容积（mL）', key: 'kh-initial'),
        (controller: _remaining, label: '剩余溶剂（mL）', key: 'kh-remaining'),
      ]) ...[
        TextField(
          key: Key(field.key),
          controller: field.controller,
          enabled: !_busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {
            _result = null;
            _error = null;
          }),
        ),
        const SizedBox(height: 12),
      ],
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
        const SizedBox(height: 16),
        Text(
          '${result.displayDkh} dKH',
          key: const Key('kh-result'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Text('仅供参考'),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('save-kh-titration'),
          onPressed: _busy ? null : _save,
          child: const Text('确认并录入'),
        ),
      ],
      TextButton(
        onPressed: _busy ? null : widget.onCancel,
        child: const Text('本次不记录'),
      ),
      TextButton(
        key: const Key('manual-kh-entry'),
        onPressed: _busy
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
        child: const Text('手动录入 KH'),
      ),
    ],
  );
}
