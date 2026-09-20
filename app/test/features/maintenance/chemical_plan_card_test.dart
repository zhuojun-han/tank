import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/app/theme.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/maintenance/data/maintenance_repository.dart';
import 'package:lanjiao_water_quality/features/maintenance/presentation/chemical_plan_card.dart';

void main() {
  testWidgets('总计划摘要只显示待处理日期，详情保留完成和停止历史', (tester) async {
    MaintenanceTaskItem item(int day, String status) => MaintenanceTaskItem(
      task: MaintenanceTask(
        id: 'day-$day',
        tankId: 'a',
        title: '第 $day 日剂量',
        intervalAmount: 1,
        intervalUnit: 'day',
        dueAt: DateTime(2026, 9, day, 9).toUtc(),
        preferredReminderTime: '09:00',
        status: status,
        isOneOff: true,
        source: 'alkalinity-plan',
        planId: 'kh-plan',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      state: status == 'completed'
          ? MaintenanceTaskViewState.completed
          : status == 'skipped'
          ? MaintenanceTaskViewState.skipped
          : MaintenanceTaskViewState.upcoming,
    );
    final items = [
      item(7, 'completed'),
      item(10, 'enabled'),
      item(11, 'enabled'),
      item(15, 'skipped'),
    ];
    String? stopped;
    await tester.pumpWidget(
      MaterialApp(
        theme: LanjiaoTheme.light,
        home: Scaffold(
          body: ChemicalPlanCard(
            items: items,
            onStop: (item) => stopped = item.task.id,
          ),
        ),
      ),
    );
    expect(find.text('KH 总计划 · 剩余 2 天'), findsOneWidget);
    expect(find.text('2026-09-10 — 2026-09-11'), findsOneWidget);
    expect(find.text('2026-09-07 — 2026-09-15'), findsNothing);
    await tester.tap(find.text('查看每日安排'));
    await tester.pumpAndSettle();
    expect(find.text('2026-09-07 · 第 7 日剂量'), findsOneWidget);
    expect(find.text('2026-09-15 · 第 15 日剂量'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('停止后续计划'));
    expect(stopped, 'day-10');
    expect(items.map((item) => item.task.status), [
      'completed',
      'enabled',
      'enabled',
      'skipped',
    ]);
    expect(tester.takeException(), isNull);
  });
}
