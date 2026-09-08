import 'package:flutter/material.dart';

Future<int?> showTaskDelayDays(BuildContext context) =>
    showDialog<int>(context: context, builder: (_) => const _DelayDialog());

class _DelayDialog extends StatefulWidget {
  const _DelayDialog();
  @override
  State<_DelayDialog> createState() => _DelayDialogState();
}

class _DelayDialogState extends State<_DelayDialog> {
  final controller = TextEditingController(text: '1');
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('延迟任务'),
    content: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      autofocus: true,
      decoration: InputDecoration(
        labelText: '延迟天数',
        suffixText: '天',
        errorText: error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          final days = int.tryParse(controller.text.trim());
          if (days == null || days < 1 || days > 3652058) {
            setState(() => error = '请输入有效的正整数天数');
            return;
          }
          Navigator.pop(context, days);
        },
        child: const Text('确认延迟'),
      ),
    ],
  );
}

Future<DateTime?> showTaskCompletionDate(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? firstDate,
  String title = '实际完成日期',
}) {
  final now = DateTime.now(),
      today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
  final first = firstDate == null
      ? DateTime(1900)
      : DateTime(firstDate.year, firstDate.month, firstDate.day);
  if (first.isAfter(today)) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('完成日期不能早于计划开始日期')));
    return Future.value();
  }
  final requested = initialDate ?? now;
  final initial = requested.isAfter(today)
      ? today
      : requested.isBefore(first)
      ? first
      : requested;
  return showDatePicker(
    context: context,
    helpText: title,
    initialDate: initial,
    firstDate: first,
    lastDate: today,
    cancelText: '取消',
    confirmText: '确认',
  );
}
