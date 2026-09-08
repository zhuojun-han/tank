import 'package:flutter/material.dart';
import '../../maintenance/data/maintenance_repository.dart';

enum ChemicalPlanAction { add, replace, preview }

Future<ChemicalPlanAction?> confirmChemicalPlan(
  BuildContext context,
  MaintenanceRepository repository, {
  required String tankId,
  required String source,
  required DateTime start,
  required int days,
}) async {
  final overlap = await repository.hasChemicalPlanFromDate(
    tankId,
    source,
    start,
  );
  if (!context.mounted) return null;
  final accepted = await showDialog<ChemicalPlanAction>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(overlap ? '覆盖同类旧计划？' : '加入全部分日任务？'),
      content: Text(
        '${overlap ? '替换开始日及之后尚未处理的同类计划，已完成历史保留。\n' : ''}'
        '从今天起创建 $days 个任务。每天先复测并观察生物，再决定是否执行；停止时一并停止后续计划。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('取消'),
        ),
        if (overlap)
          TextButton(
            onPressed: () => Navigator.pop(dialog, ChemicalPlanAction.preview),
            child: const Text('仅计算，不覆盖原计划'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(
            dialog,
            overlap ? ChemicalPlanAction.replace : ChemicalPlanAction.add,
          ),
          child: Text(overlap ? '确认覆盖' : '确认加入'),
        ),
      ],
    ),
  );
  return accepted;
}
