import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/database/app_database.dart';
import '../../maintenance/application/maintenance_providers.dart';
import '../../tanks/application/tank_providers.dart';
import '../domain/alkalinity_calculator.dart';
import '../domain/calculator_session.dart';
import '../domain/target_default.dart';
import 'plan_confirmation.dart';

class AlkalinityCalculatorPage extends ConsumerStatefulWidget {
  const AlkalinityCalculatorPage({super.key});
  @override
  ConsumerState<AlkalinityCalculatorPage> createState() =>
      _AlkalinityCalculatorPageState();
}

class _AlkalinityCalculatorPageState
    extends ConsumerState<AlkalinityCalculatorPage> {
  final _fields = [
    for (final value in ['', '8', '200', '100', '0.5', '0.5', '500', '20'])
      TextEditingController(text: value),
  ];
  int _strength = 6;
  AlkalinityPlan? _plan;
  String? _planTankId;
  String? _error;
  bool _saving = false;
  String? _targetTankId;
  bool _targetEdited = false;
  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tank = ref.watch(currentTankProvider).value;
    final targets = tank == null
        ? null
        : ref.watch(waterQualityTargetsProvider(tank.id)).value;
    if (tank != null && targets != null) {
      if (_targetTankId != tank.id) {
        _targetTankId = tank.id;
        _targetEdited = false;
        _plan = null;
      }
      if (!_targetEdited) {
        final target = targets
            .where((row) => row.parameterId == AppDatabase.khId)
            .firstOrNull;
        final text = calculatorTargetDefault(
          kh: true,
          minimum: target?.minValue,
          maximum: target?.maxValue,
        );
        if (_fields[1].text != text) {
          _fields[1].text = text;
          _plan = null;
        }
      }
    }
    const labels = [
      '当前 KH（dKH）',
      '目标 KH（dKH）',
      '实际净水量（L）',
      '包装纯度（%）',
      '计划单日净升幅（dKH）',
      '每日 KH 消耗（dKH）',
      '母液最终体积（mL）',
      '母液最低温度（0–40°C）',
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('碳酸氢钠补 KH')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('使用未烘焙 NaHCO₃。每天先复测 KH/pH，再计算当天用量。'),
          for (var i = 0; i < _fields.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                key: Key('alkalinity-input-$i'),
                controller: _fields[i],
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: labels[i]),
                onChanged: (_) => setState(() {
                  if (i == 1) _targetEdited = true;
                  _plan = null;
                }),
              ),
            ),
          DropdownButtonFormField<int>(
            initialValue: _strength,
            decoration: const InputDecoration(
              labelText: '每 100 L 提升 0.1 dKH 所需母液',
            ),
            items: [
              for (final ml in alkalinityStockMlOptions)
                DropdownMenuItem(value: ml, child: Text('$ml mL')),
            ],
            onChanged: _saving
                ? null
                : (v) => setState(() {
                    _strength = v!;
                    _plan = null;
                  }),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('calculate-alkalinity'),
            onPressed: _saving || tank == null || targets == null
                ? null
                : _calculate,
            child: const Text('计算 KH 母液与分日计划'),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_plan case final plan?) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '称取 ${plan.solidMassToWeighG.toStringAsFixed(4)} g，溶解后定容至 ${plan.stockFinalVolumeMl} mL。\n'
                  '浓度 ${plan.stockConcentrationGPerL.toStringAsFixed(3)} g/L。\n'
                  '${plan.days} 天，共 ${plan.totalStockRequiredMl.toStringAsFixed(2)} mL，需 ${plan.stockBatchesRequired} 批；缺口 ${plan.stockShortfallMl.toStringAsFixed(2)} mL。',
                ),
              ),
            ),
            for (final day in plan.dailyPlan)
              Card(
                child: ListTile(
                  title: Text(
                    '第 ${day.day} 天 · ${day.stockMl.toStringAsFixed(2)} mL',
                  ),
                  subtitle: Text(
                    '净提升 ${day.netRise.toStringAsFixed(3)} + 消耗 ${day.consumption.toStringAsFixed(3)} = 投加当量 ${day.doseDkh.toStringAsFixed(3)} dKH\n'
                    '投加后瞬时理论 KH ${day.postDoseDkh.toStringAsFixed(3)}；预计日末 ${day.endingDkh.toStringAsFixed(3)} dKH',
                  ),
                ),
              ),
            FilledButton(
              key: const Key('save-alkalinity-plan'),
              onPressed: _saving || tank == null ? null : _save,
              child: Text(_saving ? '正在保存…' : '加入每日任务'),
            ),
          ],
          const SizedBox(height: 12),
          const Text('完全溶解后，在强水流处缓慢分次添加，勿与钙镁浓缩液混合。达到目标或 KH/pH、生物状态异常时停止。'),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('计算依据'),
            children: [
              const Text(
                'NaHCO₃ 84.007 g/mol；1 meq/L = 2.8 dKH。100 L 提升 1 dKH 约需 3.00025 g 纯品。溶解度按 PubChem 数据保守筛查。',
              ),
              if (_plan case final plan?)
                Text(
                  '最低温度下的浓度筛查上限：${plan.conservativeLimitGPerL.toStringAsFixed(3)} g/L，已预留 20% 余量。',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _calculate() async {
    final tank = ref.read(currentTankProvider).value;
    if (tank == null || _saving) return;
    setState(() {
      _saving = true;
      _plan = null;
      _planTankId = null;
    });
    final n = _fields
        .map((f) => double.tryParse(f.text.trim()) ?? double.nan)
        .toList();
    try {
      final plan = calculateAlkalinityPlan(
        currentDkh: n[0],
        targetDkh: n[1],
        netWaterVolumeL: n[2],
        purityPercent: n[3],
        maxDailyDkhRise: n[4],
        dailyDkhConsumption: n[5],
        stockFinalVolumeMl: n[6],
        stockTemperatureC: n[7],
        stockMlPerPointOne: _strength,
      );
      await ref
          .read(maintenanceRepositoryProvider)
          .validateChemicalTarget(
            tankId: tank.id,
            parameterId: AppDatabase.khId,
            targetValue: plan.targetDkh,
          );
      if (!mounted) return;
      if (ref.read(currentTankProvider).value?.id != tank.id) {
        throw const FormatException('当前海缸已改变，请重新计算。');
      }
      setState(() {
        _plan = plan;
        _planTankId = tank.id;
        _error = null;
      });
      ref.read(calculatorSessionProvider).rememberKh(tank.id, plan);
    } catch (e) {
      if (mounted) {
        setState(() {
          _plan = null;
          _error = e is FormatException ? e.message : '$e';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final tank = ref.read(currentTankProvider).value;
    final plan = _plan;
    if (tank == null || plan == null || _saving) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      if (_planTankId != tank.id) throw const FormatException('当前海缸已改变，请重新计算。');
      await repo.validateChemicalTarget(
        tankId: tank.id,
        parameterId: AppDatabase.khId,
        targetValue: plan.targetDkh,
      );
      if (!mounted) return;
      final start = DateTime.now();
      final replace = await confirmChemicalPlan(
        context,
        repo,
        tankId: tank.id,
        source: 'alkalinity-plan',
        start: start,
        days: plan.days,
      );
      if (replace == null || !mounted) return;
      if (replace == ChemicalPlanAction.preview) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('仅计算：原计划已保留，可查看下方分日结果')));
        return;
      }
      if (ref.read(currentTankProvider).value?.id != tank.id) {
        throw const FormatException('当前海缸已改变，请重新计算。');
      }
      await repo.createAlkalinityPlanTasks(
        tankId: tank.id,
        plan: plan,
        startDate: start,
        replaceExisting: replace == ChemicalPlanAction.replace,
      );
      if (mounted) context.go('/maintenance');
    } catch (e) {
      if (mounted) {
        setState(() {
          _plan = null;
          _planTankId = null;
          _error = '保存失败：$e';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
