import 'package:flutter/material.dart';

import '../domain/salinity_calculator.dart';

class SalinityCalculatorPage extends StatefulWidget {
  const SalinityCalculatorPage({super.key});

  @override
  State<SalinityCalculatorPage> createState() => _SalinityCalculatorPageState();
}

class _SalinityCalculatorPageState extends State<SalinityCalculatorPage> {
  final _initial = TextEditingController(text: '0');
  final _target = TextEditingController(text: '1.025');
  final _volume = TextEditingController(text: '20');
  final _saltPerLitre = TextEditingController(text: '38.2');
  final _labelReference = TextEditingController(text: '1.0255');
  SalinityCalculationResult? _result;
  String? _error;

  @override
  void dispose() {
    _initial.dispose();
    _target.dispose();
    _volume.dispose();
    _saltPerLitre.dispose();
    _labelReference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('海盐配制计算器')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '这里的 1.025 是比重 SG',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '初始值 0 表示 RO/DI 无盐水，计算时按 SG 1.000 起点处理。不同海盐品牌所需克数不同，请按包装修改校准值。',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _numberField(
                  key: const Key('salinity-initial'),
                  controller: _initial,
                  label: '初始比重（SG）',
                  helper: '0 = RO/DI 无盐水',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberField(
                  key: const Key('salinity-target'),
                  controller: _target,
                  label: '目标比重（SG）',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _numberField(
            key: const Key('salinity-volume'),
            controller: _volume,
            label: '需要配制的水量（L）',
            helper: '加入海盐前的起始水量',
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            key: const Key('salinity-label-calibration'),
            tilePadding: EdgeInsets.zero,
            title: const Text('海盐包装校准'),
            subtitle: const Text('已带 Red Sea 示例值，请按自己的包装修改'),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _numberField(
                      controller: _saltPerLitre,
                      label: '包装每升用盐量（g/L）',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _numberField(
                      controller: _labelReference,
                      label: '对应包装比重',
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              key: const Key('salinity-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('calculate-salinity'),
            onPressed: _calculate,
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('计算需要多少海盐'),
          ),
          if (_result case final result?) ...[
            const SizedBox(height: 16),
            _ResultCard(
              title: '估算海盐总量',
              value: _mass(result.requiredSaltGrams),
              detail:
                  '${result.waterVolumeLitres.g} L · SG ${result.targetSpecificGravity.toStringAsFixed(3)} · 计算值 ${result.requiredSaltGrams.toStringAsFixed(2)} g',
            ),
            const SizedBox(height: 10),
            _ResultCard(
              title: '建议先加入 90%',
              value: _mass(result.initialAdditionGrams),
              detail:
                  '预留 ${_mass(result.reservedAdjustmentGrams)}，完全溶解并复测后逐步微调。',
            ),
            const SizedBox(height: 10),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '先量取 RO/DI 水，再把盐逐步加入水中并持续循环。达到产品标注温度后，用校准的盐度计或折射仪复测；不要在有鱼或珊瑚的展示缸中直接混盐。',
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            '结果按比重差作比例估算，不是跨品牌精确保证；以实际海盐包装和校准量具读数为准。',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _numberField({
    Key? key,
    required TextEditingController controller,
    required String label,
    String? helper,
  }) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, helperText: helper),
    );
  }

  void _calculate() {
    try {
      final result = calculateSaltMix(
        initialSpecificGravity: _number(_initial),
        targetSpecificGravity: _number(_target),
        waterVolumeLitres: _number(_volume),
        labelReferenceSpecificGravity: _number(_labelReference),
        saltGramsPerLitreAtReference: _number(_saltPerLitre),
      );
      setState(() {
        _result = result;
        _error = null;
      });
    } on FormatException catch (error) {
      setState(() {
        _result = null;
        _error = error.message;
      });
    }
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
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

String _mass(double grams) => grams >= 1000
    ? '${(grams / 1000).toStringAsFixed(3)} kg'
    : '${grams.toStringAsFixed(1)} g';

extension on double {
  String get g => this == roundToDouble()
      ? toStringAsFixed(0)
      : toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}
