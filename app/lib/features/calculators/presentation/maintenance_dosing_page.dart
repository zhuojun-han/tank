import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../maintenance/application/maintenance_providers.dart';
import '../application/maintenance_cycle_providers.dart';
import '../data/maintenance_cycle_repository.dart';
import '../domain/alkalinity_calculator.dart';
import '../domain/maintenance_cycle.dart';
import '../domain/maintenance_dosing.dart';

class MaintenanceDosingPage extends StatelessWidget {
  const MaintenanceDosingPage({
    super.key,
    this.previousKh,
    this.tankName,
    this.tankId,
    this.initialChemical,
  });
  final AlkalinityPlan? previousKh;
  final String? tankName, tankId;
  final String? initialChemical;
  DosingChemical get _initialChemical =>
      initialChemical == 'kh' ? DosingChemical.kh : DosingChemical.po4;
  @override
  Widget build(BuildContext context) {
    if (tankId == null) {
      return _MaintenanceDosingForm(
        previousKh: previousKh,
        tankName: tankName,
        initialChemical: _initialChemical,
        today: DateTime.now(),
      );
    }
    return Consumer(
      builder: (context, ref, _) {
        final cycles = ref.watch(maintenanceCyclesProvider(tankId!));
        final today = ref.watch(maintenanceDateProvider);
        return cycles.when(
          data: (value) => _MaintenanceDosingForm(
            key: ValueKey(tankId),
            previousKh: previousKh,
            tankName: tankName,
            tankId: tankId,
            initialChemical: _initialChemical,
            cycles: value,
            today: today,
            repository: ref.watch(maintenanceCycleRepositoryProvider),
          ),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: const Text('稳定滴定')),
            body: const Center(child: Text('配液记录暂时无法读取，请重新打开。')),
          ),
        );
      },
    );
  }
}

class _MaintenanceDosingForm extends StatefulWidget {
  const _MaintenanceDosingForm({
    super.key,
    this.previousKh,
    this.tankName,
    this.tankId,
    required this.initialChemical,
    required this.today,
    this.cycles = const [],
    this.repository,
  });
  final AlkalinityPlan? previousKh;
  final String? tankName, tankId;
  final DosingChemical initialChemical;
  final DateTime today;
  final List<MaintenanceCycle> cycles;
  final MaintenanceCycleRepository? repository;
  @override
  State<_MaintenanceDosingForm> createState() => _MaintenanceDosingPageState();
}

class _MaintenanceDosingPageState extends State<_MaintenanceDosingForm> {
  DosingChemical _chemical = DosingChemical.po4;
  final _volume = TextEditingController(text: '500');
  final _water = TextEditingController(text: '200');
  final _changes = [
    TextEditingController(text: '0.02'),
    TextEditingController(text: '0.5'),
  ];
  final _flows = [
    TextEditingController(text: '1.4'),
    TextEditingController(text: '1.4'),
  ];
  final _minutes = [
    TextEditingController(text: '1'),
    TextEditingController(text: '1'),
  ];
  final _units = [PumpFlowUnit.mlPerSecond, PumpFlowUnit.mlPerSecond];
  final _purity = TextEditingController(text: '100');
  final _temperature = TextEditingController(text: '20');
  int _strength = 6;
  final _residual = TextEditingController();
  bool? _keepResidual;
  bool _residualEdited = false;
  String? _preparedDateOverride;
  String? _saveError;
  bool _saving = false;
  String? _expectedPreviousId;

  String get _today => cycleDateKey(widget.today);
  String get _preparedDate => _preparedDateOverride ?? _today;
  MaintenanceCycle? get _previous =>
      currentMaintenanceCycle(widget.cycles, widget.tankId ?? '', _chemical);

  MaintenanceDosingInput get _input => MaintenanceDosingInput(
    waterL: _number(_water),
    volumeMl: _number(_volume),
    dailyChange: _number(_changes[_chemical.index]),
    flow: _number(_flows[_chemical.index]),
    minutes: _number(_minutes[_chemical.index]),
    unit: _units[_chemical.index],
    khStrength: _strength,
    khPurity: _chemical == DosingChemical.kh ? _number(_purity) : 100,
    temperature: _chemical == DosingChemical.kh ? _number(_temperature) : 20,
  );

  void _restoreRecipe(MaintenanceCycle? cycle) {
    if (cycle == null) return;
    final input = cycle.input;
    _water.text = input.waterL.toString();
    _volume.text = input.volumeMl.toString();
    _changes[_chemical.index].text = input.dailyChange.toString();
    _flows[_chemical.index].text = input.flow.toString();
    _minutes[_chemical.index].text = input.minutes.toString();
    _units[_chemical.index] = input.unit;
    _strength = input.khStrength;
    _purity.text = input.khPurity.toString();
    _temperature.text = input.temperature.toString();
  }

  @override
  void initState() {
    super.initState();
    _chemical = widget.initialChemical;
    final plan = widget.previousKh;
    if (plan != null) {
      _water.text = plan.netWaterVolumeL.toString();
      _changes[1].text = plan.dailyDkhConsumption.toString();
      _purity.text = plan.purityPercent.toString();
      _temperature.text = plan.stockTemperatureC.toString();
      _strength = plan.stockMlPerPointOne;
    }
    _restoreRecipe(_previous);
    _expectedPreviousId = _previous?.id;
    _syncResidual();
  }

  void _syncResidual() {
    if (!_residualEdited) {
      final previous = _previous;
      _residual.text = previous == null
          ? '0'
          : _fmt(cycleRemainingMl(previous, _preparedDate));
    }
  }

  @override
  void didUpdateWidget(covariant _MaintenanceDosingForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncResidual();
  }

  @override
  void dispose() {
    for (final controller in [
      _water,
      _volume,
      ..._changes,
      ..._flows,
      ..._minutes,
      _purity,
      _temperature,
      _residual,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = _chemical.index;
    final kh = _chemical == DosingChemical.kh;
    MaintenanceDosingResult? result;
    MaintenanceCycle? recipe;
    String? error;
    String? recipeError;
    final previous = _previous;
    final needsChoice = previous != null && _keepResidual == null;
    final estimatedResidual = previous == null
        ? 0.0
        : cycleRemainingMl(previous, _preparedDate);
    try {
      result = _input.calculate(_chemical);
    } on FormatException catch (e) {
      error = e.message;
    }
    if (widget.tankId != null && result != null && result.dailyStockMl > 0) {
      try {
        if (previous?.id != _expectedPreviousId) {
          throw const FormatException('配液周期已变化，请重新打开配方。');
        }
        if (_preparedDate.compareTo(_today) > 0) {
          throw const FormatException('请选择不晚于今天的实际配液日期。');
        }
        recipe = prepareMaintenanceCycle(
          input: _input,
          chemical: _chemical,
          tankId: widget.tankId!,
          startDate: _preparedDate,
          id: 'preview',
          previous: previous,
          retainedMl: _keepResidual == true
              ? (_residualEdited ? _number(_residual) : estimatedResidual)
              : 0,
        );
      } on FormatException catch (e) {
        recipeError = e.message;
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('稳定滴定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.tankName == null ? '稳定滴定配方' : '${widget.tankName} · 稳定滴定配方',
          ),
          const SizedBox(height: 12),
          SegmentedButton<DosingChemical>(
            key: const Key('dosing-chemical'),
            segments: const [
              ButtonSegment(
                value: DosingChemical.po4,
                label: Text('PO₄ · 氯化镧'),
              ),
              ButtonSegment(value: DosingChemical.kh, label: Text('KH · 碳酸氢钠')),
            ],
            selected: {_chemical},
            onSelectionChanged: _saving
                ? null
                : (v) => setState(() {
                    _chemical = v.single;
                    _keepResidual = null;
                    _residualEdited = false;
                    _saveError = null;
                    _restoreRecipe(_previous);
                    _expectedPreviousId = _previous?.id;
                    _syncResidual();
                  }),
          ),
          if (widget.tankId != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('实际配液日期'),
              subtitle: Text(_preparedDate),
              trailing: const Icon(Icons.calendar_today),
              key: const Key('dosing-prepared-date'),
              onTap: _saving ? null : () => _selectDate(previous),
            ),
          _field('dosing-volume', _volume, '滴定溶液体积（ml）'),
          _field('dosing-water', _water, '净水量（L）'),
          _field(
            'dosing-change-$index',
            _changes[index],
            kh ? '每日 KH 下降（dKH）' : '每日 PO₄ 上升（mg/L）',
          ),
          if (kh)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: DropdownButtonFormField<int>(
                key: const Key('dosing-strength'),
                initialValue: _strength,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'KH 母液浓度'),
                items: [
                  for (final ml in alkalinityStockMlOptions)
                    DropdownMenuItem(
                      value: ml,
                      child: Text('$ml ml / 100 L 提升 0.1 dKH'),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _strength = v);
                },
              ),
            ),
          _field('dosing-flow-$index', _flows[index], '泵流速'),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DropdownButtonFormField<PumpFlowUnit>(
              key: ValueKey('dosing-unit-$index'),
              initialValue: _units[index],
              decoration: const InputDecoration(labelText: '单位'),
              items: const [
                DropdownMenuItem(
                  value: PumpFlowUnit.mlPerSecond,
                  child: Text('ml/秒'),
                ),
                DropdownMenuItem(
                  value: PumpFlowUnit.mlPerMinute,
                  child: Text('ml/分钟'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _units[index] = v);
              },
            ),
          ),
          _field('dosing-minutes-$index', _minutes[index], '每天运行时间（分钟）'),
          const SizedBox(height: 16),
          if (previous != null) ...[
            Text('上次配液：${previous.startDate} · 预计 ${previous.refillDate} 补液'),
            Text(
              MaintenanceCycleOccurrence(
                cycle: previous,
                date: _today,
                today: _today,
              ).remainingLabel,
              key: const Key('dosing-remaining-days'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<bool>(
              key: ValueKey(
                'dosing-residual-choice-${previous.id}-${_chemical.name}',
              ),
              initialValue: _keepResidual,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '上次滴定液还有残留吗？'),
              items: const [
                DropdownMenuItem(value: true, child: Text('有，保留残液继续配制')),
                DropdownMenuItem(value: false, child: Text('没有，或已倒掉残液')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _keepResidual = value;
                      _residualEdited = false;
                      _saveError = null;
                      _syncResidual();
                    }),
            ),
            if (_keepResidual == true) ...[
              TextField(
                key: const Key('dosing-residual'),
                controller: _residual,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '保留残液体积（mL）'),
                onChanged: (value) => setState(() {
                  _residualEdited = true;
                  _saveError = null;
                }),
              ),
              Text('预计剩余 ${_fmt(estimatedResidual)} mL，可按实际修改。'),
            ],
          ],
          if (error != null)
            Text(
              error,
              key: const Key('dosing-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (result != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '预计可用 ${result.actualDays.round()} 天（${result.actualDays.toStringAsPrecision(3)} 天）',
                      key: const Key('dosing-days'),
                    ),
                    if (result.dailyStockMl == 0)
                      const Text('无需添加此药剂')
                    else if (!result.feasible)
                      Text(
                        '母液需 ${_fmt(result.stockMl)} ml，超过 ${_volume.text} ml 容量，请增加每日泵出量。',
                        key: const Key('dosing-capacity-error'),
                      )
                    else if (needsChoice)
                      const Text('选择残液情况后查看续配用量。')
                    else if (widget.tankId == null || recipe != null) ...[
                      if (recipe != null && recipe.retainedMl > 0)
                        Text('保留原滴定液 ${_fmt(recipe.retainedMl)} ml'),
                      Text(
                        '${previous == null ? '取' : '再加'}母液 ${_fmt(recipe?.addedStockMl ?? result.stockMl)} ml',
                        key: const Key('dosing-stock'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        recipe == null
                            ? '加 RO/DI 水定容至 ${_volume.text} ml'
                            : '加 RO/DI 水 ${_fmt(recipe.addedWaterMl)} ml，定容至 ${_volume.text} ml',
                      ),
                      Text(
                        '每日母液 ${_fmt(result.dailyStockMl)} ml · 每日泵出 ${_fmt(result.dailyLiquidMl)} ml',
                      ),
                      if (recipe != null) Text('补液日期：${recipe.refillDate}'),
                    ],
                  ],
                ),
              ),
            ),
          if (!needsChoice && recipeError != null)
            Text(
              recipeError,
              key: const Key('dosing-recipe-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_saveError != null)
            Text(
              _saveError!,
              key: const Key('dosing-save-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (widget.tankId != null) ...[
            FilledButton(
              key: const Key('dosing-confirm'),
              onPressed: _saving || needsChoice || recipe == null
                  ? null
                  : () => _save(previous),
              child: Text(
                _saving
                    ? '正在保存…'
                    : '已配好，${previous == null ? '添加每日平衡' : '开始新周期'}',
              ),
            ),
            const Text('配好后确认；平时显示在已完成，最后一天提醒补液。'),
          ],
          ExpansionTile(
            key: const Key('dosing-details'),
            tilePadding: EdgeInsets.zero,
            title: const Text('母液设置与使用说明'),
            children: [
              if (kh) ...[
                _field('dosing-purity', _purity, '母液原料纯度（%）'),
                _field('dosing-temperature', _temperature, '最低保存温度（°C）'),
                const Text('请填写实际最低保存温度（0–40°C），避免浓度过高析出。'),
                if (result?.khConcentrationGPerL case final concentration?)
                  Text(
                    '此母液每 500 ml 称取 ${_fmt(concentration / 2)} g NaHCO₃ 后定容。',
                  ),
              ] else
                const Text(
                  '氯化镧母液：99.9% LaCl₃·7H₂O，19.571329 g 定容至 500 ml；每 ml 理论处理 10 mg PO₄。每日上升默认 0.02 仅为示例，请填未补偿时实测变化。',
                ),
              const Text('按实际泵出量和溶液体积配制。两种药剂分别配制、独立容器与泵管，不混合。'),
              const Text(
                '每日复测 PO₄、KH/pH；PO₄ ≤ 0.03 mg/L、浑浊或生物异常时停止氯化镧，并通过机械过滤/蛋分捕获沉淀。',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(MaintenanceCycle? previous) async {
    final first = DateTime.parse(previous?.startDate ?? '0001-01-01');
    final last = DateTime.parse(_today);
    final selected = DateTime.parse(_preparedDate);
    final date = await showDatePicker(
      context: context,
      initialDate: selected.isBefore(first)
          ? first
          : selected.isAfter(last)
          ? last
          : selected,
      firstDate: first,
      lastDate: last,
      helpText: '实际配液日期',
    );
    if (!mounted || date == null) return;
    setState(() {
      _preparedDateOverride = cycleDateKey(date);
      _saveError = null;
      _syncResidual();
    });
  }

  Future<void> _save(MaintenanceCycle? previous) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final repository = widget.repository!;
      final today = cycleDateKey(repository.now);
      final date = _preparedDateOverride ?? today;
      if (date.compareTo(today) > 0) {
        throw const FormatException('请选择不晚于今天的实际配液日期。');
      }
      // Recompute auto residual at confirmation: the page may have crossed midnight.
      final retained = _keepResidual == true
          ? _residualEdited
                ? _number(_residual)
                : cycleRemainingMl(previous!, date)
          : 0.0;
      final next = prepareMaintenanceCycle(
        input: _input,
        chemical: _chemical,
        tankId: widget.tankId!,
        startDate: date,
        id: const Uuid().v4(),
        previous: previous,
        retainedMl: retained,
      );
      await repository.confirm(next);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('每日平衡已添加')));
      Navigator.of(context).pop();
    } on FormatException catch (e) {
      if (mounted) setState(() => _saveError = e.message);
    } catch (_) {
      if (mounted) setState(() => _saveError = '保存失败，请重试。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String key, TextEditingController controller, String label) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
          key: ValueKey(key),
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: InputDecoration(labelText: label),
          onChanged: (_) => setState(() {}),
        ),
      );
}

double _number(TextEditingController controller) =>
    double.tryParse(controller.text.trim()) ?? double.nan;
String _fmt(double value) => value == 0
    ? '0'
    : value.abs() < 0.001
    ? value.toStringAsExponential(3)
    : value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
