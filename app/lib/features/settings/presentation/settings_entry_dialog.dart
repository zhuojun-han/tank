import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../tanks/application/tank_providers.dart';

/// Controllers belong to the dialog route and survive its reverse transition.
class SettingsEntryDialog extends ConsumerStatefulWidget {
  const SettingsEntryDialog.tank({this.tank, super.key}) : tankId = null;
  const SettingsEntryDialog.parameter({required this.tankId, super.key})
    : tank = null;
  final Tank? tank;
  final String? tankId;

  @override
  ConsumerState<SettingsEntryDialog> createState() =>
      _SettingsEntryDialogState();
}

class _SettingsEntryDialogState extends ConsumerState<SettingsEntryDialog> {
  late final List<TextEditingController> _fields;
  bool _saving = false;
  String? _error;
  bool get _parameter => widget.tankId != null;

  @override
  void initState() {
    super.initState();
    _fields = [
      for (final value
          in _parameter
              ? ['', '', '']
              : [widget.tank?.name ?? '', widget.tank?.notes ?? ''])
        TextEditingController(text: value),
    ];
  }

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = _parameter ? ['简称', '名称', '单位'] : ['名称', '备注（可选）'];
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(
          _parameter
              ? '自定义参数'
              : widget.tank == null
              ? '添加海缸'
              : '编辑海缸',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _fields.length; i++)
                TextField(
                  controller: _fields[i],
                  enabled: !_saving,
                  decoration: InputDecoration(labelText: labels[i]),
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '正在保存…' : '保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final values = _fields.map((field) => field.text).toList();
    try {
      final repository = ref.read(tankRepositoryProvider);
      if (_parameter) {
        await repository.createCustomParameter(
          tankId: widget.tankId!,
          code: values[0],
          displayName: values[1],
          unit: values[2],
        );
      } else if (widget.tank case final tank?) {
        await repository.updateTank(
          tankId: tank.id,
          name: values[0],
          notes: values[1],
        );
      } else {
        await repository.createTank(name: values[0], notes: values[1]);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
