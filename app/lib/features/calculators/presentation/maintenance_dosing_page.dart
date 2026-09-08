import 'package:flutter/material.dart';

import '../domain/alkalinity_calculator.dart';
import '../domain/maintenance_dosing.dart';

class MaintenanceDosingPage extends StatefulWidget {
  const MaintenanceDosingPage({super.key, this.previousKh, this.tankName});
  final AlkalinityPlan? previousKh;
  final String? tankName;
  @override
  State<MaintenanceDosingPage> createState() => _MaintenanceDosingPageState();
}

class _MaintenanceDosingPageState extends State<MaintenanceDosingPage> {
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

  @override
  void initState() {
    super.initState();
    final plan = widget.previousKh;
    if (plan != null) {
      _water.text = plan.netWaterVolumeL.toString();
      _changes[1].text = plan.dailyDkhConsumption.toString();
      _purity.text = plan.purityPercent.toString();
      _temperature.text = plan.stockTemperatureC.toString();
      _strength = plan.stockMlPerPointOne;
    }
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
    String? error;
    try {
      result = calculateMaintenanceDosing(
        chemical: _chemical,
        waterL: _number(_water),
        volumeMl: _number(_volume),
        dailyChange: _number(_changes[index]),
        flow: _number(_flows[index]),
        minutes: _number(_minutes[index]),
        unit: _units[index],
        khStrength: _strength,
        khPurity: _number(_purity),
        temperature: _number(_temperature),
      );
    } on FormatException catch (e) {
      error = e.message;
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
            onSelectionChanged: (v) => setState(() => _chemical = v.single),
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
                    else ...[
                      Text(
                        '取母液 ${_fmt(result.stockMl)} ml',
                        key: const Key('dosing-stock'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text('加 RO/DI 水定容至 ${_volume.text} ml'),
                      Text(
                        '每日母液 ${_fmt(result.dailyStockMl)} ml · 每日泵出 ${_fmt(result.dailyLiquidMl)} ml',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ExpansionTile(
            key: const Key('dosing-details'),
            tilePadding: EdgeInsets.zero,
            title: const Text('母液设置与使用说明'),
            children: [
              if (kh) ...[
                _field('dosing-purity', _purity, '母液原料纯度（%）'),
                _field('dosing-temperature', _temperature, '最低保存温度（°C）'),
                const Text(
                  '沿用 KH 计划浓度与 20% 溶解度余量检查。4 ml 档更浓，低温可能不满足余量；请按实际保存温度填写（0–40°C）。',
                ),
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
                '每日复测 PO₄、KH/pH；PO₄ ≤ 0.03 mg/L、浑浊或生物异常时停止氯化镧，并通过机械过滤/蛋分捕获沉淀。理论计算沿用原氯化镧与 KH 计划规则，不能替代专业诊断，不自动投药。',
              ),
            ],
          ),
        ],
      ),
    );
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
