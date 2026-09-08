import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../tanks/application/tank_providers.dart';
import '../../tanks/domain/tank_age.dart';

Future<void> showTankEditor(BuildContext context, {Tank? tank}) =>
    showDialog<void>(
      context: context,
      builder: (_) => SettingsEntryDialog.tank(tank: tank),
    );

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
  String? _startedOn;
  late final TextEditingController _volume;
  bool get _parameter => widget.tankId != null;

  @override
  void initState() {
    super.initState();
    _startedOn = widget.tank?.startedOn;
    final volumeLiters = widget.tank?.volumeLiters;
    _volume = TextEditingController(
      text: volumeLiters == null
          ? ''
          : volumeLiters.toString().replaceFirst(RegExp(r'\.0$'), ''),
    );
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
    _volume.dispose();
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
              if (!_parameter) ...[
                TextField(
                  key: const Key('tank-volume-liters'),
                  controller: _volume,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: '水体积（L，可选）'),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('开缸日期（可选）'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('tank-start-date'),
                        onPressed: _saving ? null : _pickStartedOn,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(_startedOn ?? '选择日期'),
                      ),
                    ),
                    if (_startedOn != null)
                      IconButton(
                        key: const Key('clear-tank-start-date'),
                        tooltip: '清除开缸日期',
                        onPressed: _saving
                            ? null
                            : () => setState(() => _startedOn = null),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ],
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

  Future<void> _pickStartedOn() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final previous = DateTime.tryParse(_startedOn ?? '');
    final selected = await showDatePicker(
      context: context,
      initialDate:
          previous != null &&
              !previous.isAfter(today) &&
              !previous.isBefore(DateTime(1))
          ? previous
          : today,
      firstDate: DateTime(1),
      lastDate: today,
      currentDate: today,
      helpText: '选择开缸日期',
    );
    if (!mounted || selected == null) return;
    setState(() {
      _startedOn =
          '${selected.year.toString().padLeft(4, '0')}-'
          '${selected.month.toString().padLeft(2, '0')}-'
          '${selected.day.toString().padLeft(2, '0')}';
      _error = null;
    });
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
        final startedOn = validateTankStartDate(_startedOn, DateTime.now());
        await repository.updateTank(
          tankId: tank.id,
          name: values[0],
          notes: values[1],
          startedOn: Value(startedOn),
          volumeLiters: Value(_volumeLiters()),
        );
      } else {
        final startedOn = validateTankStartDate(_startedOn, DateTime.now());
        await repository.createTank(
          name: values[0],
          notes: values[1],
          startedOn: startedOn,
          volumeLiters: _volumeLiters(),
          makeCurrent: true,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException ? error.message : '$error',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double? _volumeLiters() {
    final text = _volume.text.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || !value.isFinite || value <= 0) {
      throw const FormatException('请输入大于 0 的水体积。');
    }
    return value;
  }
}
