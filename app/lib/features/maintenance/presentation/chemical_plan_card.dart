import 'package:flutter/material.dart';
import '../data/maintenance_repository.dart';

class ChemicalPlanCard extends StatelessWidget {
  const ChemicalPlanCard({
    required this.items,
    required this.onStop,
    this.onComplete,
    this.onDelay,
    super.key,
  });
  final List<MaintenanceTaskItem> items;
  final ValueChanged<MaintenanceTaskItem> onStop;
  final ValueChanged<MaintenanceTaskItem>? onComplete, onDelay;
  @override
  Widget build(BuildContext context) {
    final sorted = [...items]
      ..sort((a, b) => a.task.dueAt.compareTo(b.task.dueAt));
    final pending = sorted.where((i) => i.task.status == 'enabled').toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${items.first.task.source == 'alkalinity-plan' ? 'KH' : 'PO4'} 总计划 · 剩余 ${pending.length} 天',
            ),
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialog) => AlertDialog(
                  title: const Text('每日安排'),
                  content: SizedBox(
                    width: 500,
                    height: 400,
                    child: ListView(
                      children: [
                        for (final item in sorted)
                          ListTile(
                            title: Text(
                              '${item.task.dueAt.toLocal().toString().substring(0, 10)} · ${item.task.title}',
                            ),
                            subtitle: Text(
                              '${item.task.status == 'completed'
                                  ? '已完成'
                                  : item.task.status == 'skipped'
                                  ? '已停止'
                                  : '待完成'}\n${item.task.notes ?? ''}',
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: const Text('关闭'),
                    ),
                  ],
                ),
              ),
              child: const Text('查看每日安排'),
            ),
            if (pending.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (onComplete != null)
                    FilledButton(
                      onPressed: () => onComplete!(pending.first),
                      child: const Text('完成本次'),
                    ),
                  Row(
                    children: [
                      if (onDelay != null) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => onDelay!(pending.first),
                            child: const Text('延迟'),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onStop(pending.first),
                          child: const Text('停止后续计划'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
