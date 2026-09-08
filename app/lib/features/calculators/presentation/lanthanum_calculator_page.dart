import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/database/app_database.dart';

import '../../maintenance/application/maintenance_providers.dart';
import '../../tanks/application/tank_providers.dart';
import '../domain/lanthanum_calculator.dart';
import 'plan_confirmation.dart';

class LanthanumCalculatorPage extends ConsumerStatefulWidget {
  const LanthanumCalculatorPage({super.key});

  @override
  ConsumerState<LanthanumCalculatorPage> createState() =>
      _LanthanumCalculatorPageState();
}

class _LanthanumCalculatorPageState
    extends ConsumerState<LanthanumCalculatorPage> {
  final _currentPo4 = TextEditingController();
  final _targetPo4 = TextEditingController(text: '0.03');
  final _netVolume = TextEditingController(text: '200');
  final _dailyDrop = TextEditingController(text: '0.1');
  final _stockVolume = TextEditingController(text: '500');
  LanthanumPlan? _plan;
  String? _planTankId;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _currentPo4.dispose();
    _targetPo4.dispose();
    _netVolume.dispose();
    _dailyDrop.dispose();
    _stockVolume.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tank = ref.watch(currentTankProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('氯化镧降低 PO4')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '理论化学计量，不是安全承诺',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '固定使用纯度 99.9% 的七水合氯化镧 LaCl₃·7H₂O。海水副反应、过滤效率和生物反应都会让实际结果偏离，必须每日先复测再决定是否执行。',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(
                  key: const Key('lanthanum-current-po4'),
                  controller: _currentPo4,
                  label: '当前 PO4（mg/L）',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  key: const Key('lanthanum-target-po4'),
                  controller: _targetPo4,
                  label: '精确目标 PO4',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(
                  key: const Key('lanthanum-net-volume'),
                  controller: _netVolume,
                  label: '实际净水量（L）',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  key: const Key('lanthanum-daily-drop'),
                  controller: _dailyDrop,
                  label: '单日最大降幅',
                  helper: '0.1–0.5 mg/L',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _field(controller: _stockVolume, label: '母液最终体积（mL）'),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              key: const Key('lanthanum-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('calculate-lanthanum'),
            onPressed: _saving || tank == null ? null : _calculate,
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('计算母液用量与计划天数'),
          ),
          if (_plan case final plan?) ...[
            const SizedBox(height: 16),
            _PlanCard(
              title: '${plan.stockFinalVolumeMl} mL 母液',
              value: '${plan.solidMassToWeighG.toStringAsFixed(6)} g',
              detail:
                  'LaCl₃·7H₂O，纯度 99.9%；定容至最终 ${plan.stockFinalVolumeMl} mL。每 1 mL 母液理论处理 10 mg PO4。',
            ),
            const SizedBox(height: 10),
            _PlanCard(
              title: '全部理论计划',
              value: '${plan.days} 天',
              detail:
                  '理论共需母液 ${plan.totalStockRequiredMl.toStringAsFixed(2)} mL，需 ${plan.stockBatchesRequired} 批；每日事项会分别加入系统任务和通知。',
            ),
            const SizedBox(height: 10),
            for (final day in plan.dailyPlan)
              Card(
                child: ListTile(
                  title: Text('第 ${day.day} 天'),
                  subtitle: Text(
                    'PO4 理论 ${day.startingPo4MgL.toStringAsFixed(3)} → ${day.endingPo4MgL.toStringAsFixed(3)} mg/L\n'
                    '取母液 ${day.stockToUseMl.toStringAsFixed(2)} mL，RO/DI 水定容至最终 500 mL',
                  ),
                  isThreeLine: true,
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('save-lanthanum-plan'),
              onPressed: _saving || tank == null ? null : _savePlan,
              icon: const Icon(Icons.event_available_outlined),
              label: Text(
                _saving
                    ? '正在保存…'
                    : tank == null
                    ? '请先选择海缸'
                    : '加入 ${tank.name} 的每日任务',
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            '达到目标、读数异常、持续浑浊或鱼和珊瑚出现异常时，应停止当天及全部后续计划。任务只是条件提醒，不会自动投药。',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _field({
    Key? key,
    required TextEditingController controller,
    required String label,
    String? helper,
  }) => TextField(
    key: key,
    controller: controller,
    enabled: !_saving,
    onChanged: (_) => setState(() => _plan = null),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, helperText: helper),
  );

  Future<void> _calculate() async {
    final tank = ref.read(currentTankProvider).value;
    if (tank == null || _saving) return;
    setState(() {
      _saving = true;
      _plan = null;
      _planTankId = null;
    });
    try {
      final result = calculateLanthanumPlan(
        currentPo4MgL: _number(_currentPo4),
        targetPo4MgL: _number(_targetPo4),
        netWaterVolumeL: _number(_netVolume),
        maxDailyPo4DropMgL: _number(_dailyDrop),
        stockFinalVolumeMl: _number(_stockVolume),
      );
      await ref
          .read(maintenanceRepositoryProvider)
          .validateChemicalTarget(
            tankId: tank.id,
            parameterId: AppDatabase.po4Id,
            targetValue: result.targetPo4MgL,
          );
      if (!mounted) return;
      if (ref.read(currentTankProvider).value?.id != tank.id) {
        throw const FormatException('当前海缸已改变，请重新计算。');
      }
      setState(() {
        _plan = result;
        _planTankId = tank.id;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _plan = null;
          _error = error is FormatException ? error.message : '$error';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _savePlan() async {
    final plan = _plan;
    final tank = ref.read(currentTankProvider).value;
    if (plan == null || tank == null) return;
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(maintenanceRepositoryProvider);
      if (_planTankId != tank.id) throw const FormatException('当前海缸已改变，请重新计算。');
      await repository.validateChemicalTarget(
        tankId: tank.id,
        parameterId: AppDatabase.po4Id,
        targetValue: plan.targetPo4MgL,
      );
      if (!mounted) return;
      final start = DateTime.now();
      final replace = await confirmChemicalPlan(
        context,
        repository,
        tankId: tank.id,
        source: 'lanthanum-plan',
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
      await repository.createLanthanumPlanTasks(
        tankId: tank.id,
        plan: plan,
        startDate: start,
        replaceExisting: replace == ChemicalPlanAction.replace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已加入 ${plan.days} 个分日任务')));
      context.go('/maintenance');
    } catch (error) {
      if (mounted) {
        setState(() {
          _plan = null;
          _planTankId = null;
          _error = '保存计划失败：$error';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.value,
    required this.detail,
  });

  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(detail),
          ],
        ),
      ),
    );
  }
}

double _number(TextEditingController controller) =>
    double.tryParse(controller.text.trim()) ?? double.nan;
