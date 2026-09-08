import 'package:drift/native.dart';
import 'package:lanjiao_water_quality/features/trends/data/record_history_source.dart';
import '../../support/record_history_fixture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/app/lanjiao_app.dart';
import 'package:lanjiao_water_quality/app/router.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/aquarium/application/aquarium_providers.dart';
import 'package:lanjiao_water_quality/features/aquarium/domain/fish_stock.dart';
import 'package:lanjiao_water_quality/features/calculators/application/maintenance_cycle_providers.dart';
import 'package:lanjiao_water_quality/features/tanks/application/tank_providers.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_providers.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_notification_providers.dart';
import 'package:lanjiao_water_quality/features/test_records/application/test_record_providers.dart';

void main() {
  testWidgets('首页建议卡展示触发记录、用户目标、规则来源和安全边界', (tester) async {
    final now = DateTime.utc(2026, 8, 10, 8, 30);
    await tester.pumpWidget(
      _testApp(
        now: now,
        record: TestRecord(
          id: 'record-1',
          tankId: AppDatabase.defaultTankId,
          parameterId: AppDatabase.no3Id,
          estimatedMinValue: 100,
          estimatedMaxValue: 100,
          estimationMethod: 'unverified-test-estimate',
          confirmedMinValue: 5,
          unit: 'mg/L',
          measuredAt: now,
          wasManuallyEdited: false,
          createdAt: now,
          updatedAt: now,
        ),
        target: WaterQualityTarget(
          id: 'target-1',
          tankId: AppDatabase.defaultTankId,
          parameterId: AppDatabase.no3Id,
          minValue: 4,
          maxValue: 6,
          unit: 'mg/L',
          updatedAt: now,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-aquarium-card')));
    await _scrollIntoView(tester, find.text('NO3 · 5 mg/L'));
    await _scrollIntoView(tester, find.byKey(const Key('advice-card-NO3')));

    expect(find.text('NO3 位于目标范围内'), findsOneWidget);
    expect(find.textContaining('人工确认 5 mg/L'), findsOneWidget);
    expect(find.text('4–6 mg/L'), findsOneWidget);
    expect(find.textContaining('100'), findsNothing);

    final basis = find.byKey(const Key('advice-basis-NO3'));
    await _scrollIntoView(tester, basis);
    expect(basis.hitTestable(), findsOneWidget);
    await tester.tap(basis.hitTestable());
    await tester.pumpAndSettle();
    final source = find.textContaining('Red Sea · Algae Management Program');
    expect(source, findsOneWidget);
    await _scrollIntoView(tester, source);

    expect(
      find.textContaining('Red Sea · Algae Management Program'),
      findsOneWidget,
    );
    expect(find.textContaining('不能替代规范复测、专业诊断'), findsOneWidget);
    expect(find.textContaining('不会自动控制设备'), findsOneWidget);
    await _disposeApp(tester);
  });

  testWidgets('范围记录与目标部分重叠时首页只提示复测', (tester) async {
    final now = DateTime.utc(2026, 8, 10);
    await tester.pumpWidget(
      _testApp(
        now: now,
        record: TestRecord(
          id: 'record-range',
          tankId: AppDatabase.defaultTankId,
          parameterId: AppDatabase.no3Id,
          confirmedMinValue: 8,
          confirmedMaxValue: 15,
          unit: 'mg/L',
          measuredAt: now,
          wasManuallyEdited: false,
          createdAt: now,
          updatedAt: now,
        ),
        target: WaterQualityTarget(
          id: 'target-range',
          tankId: AppDatabase.defaultTankId,
          parameterId: AppDatabase.no3Id,
          minValue: 5,
          maxValue: 10,
          unit: 'mg/L',
          updatedAt: now,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-aquarium-card')));
    await _scrollIntoView(tester, find.text('NO3 · 8–15 mg/L'));
    await _scrollIntoView(tester, find.byKey(const Key('advice-card-NO3')));

    expect(find.text('NO3 需要复测确认'), findsOneWidget);
    expect(find.textContaining('不能判定偏高或偏低'), findsOneWidget);
    expect(find.text('NO3 高于目标'), findsNothing);
    expect(find.text('NO3 低于目标'), findsNothing);
    await _disposeApp(tester);
  });
}

Widget _testApp({
  required DateTime now,
  required TestRecord record,
  required WaterQualityTarget target,
}) {
  final tank = Tank(
    id: AppDatabase.defaultTankId,
    name: '我的海缸',
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
  final parameter = WaterParameter(
    id: AppDatabase.no3Id,
    code: 'NO3',
    displayName: '硝酸盐',
    unit: 'mg/L',
    isBuiltIn: true,
    photoSupported: true,
    createdAt: now,
  );
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWith((ref) {
        final db = AppDatabase(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
      recordHistorySourceProvider.overrideWithValue(
        FixtureRecordHistorySource([record]),
      ),
      notificationsEnabledProvider.overrideWithValue(false),
      maintenanceClockProvider.overrideWith((ref) => Stream.value(now)),
      // Advice fixtures contain no dosing cycles. Keep this new homepage
      // dependency isolated just like the task/record/stock fixture streams.
      maintenanceCyclesProvider.overrideWith(
        (ref, tankId) => Stream.value(const []),
      ),
      allMaintenanceTaskItemsProvider.overrideWith(
        (ref) => Stream.value(const []),
      ),
      currentTankProvider.overrideWith((ref) => Stream.value(tank)),
      enabledParametersProvider.overrideWith(
        (ref, tankId) => Stream.value([parameter]),
      ),
      waterQualityTargetsProvider.overrideWith(
        (ref, tankId) => Stream.value([target]),
      ),
      latestTestRecordsProvider.overrideWith(
        (ref, tankId) => Stream.value([record]),
      ),
      maintenanceTaskItemsProvider.overrideWith(
        (ref, tankId) => Stream.value(const []),
      ),
      fishStockProvider.overrideWith(
        (ref, tankId) => Stream.value(const <FishStockItem>[]),
      ),
    ],
    child: LanjiaoApp(router: createAppRouter()),
  );
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('等待组件超时：$finder');
}

Future<void> _disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // Flush asynchronous subscription/database cleanup before test invariants.
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _scrollIntoView(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable);
  expect(scrollable, findsWidgets);
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: scrollable.first,
    maxScrolls: 20,
  );
  expect(finder, findsOneWidget);
  await tester.pump();
  await tester.ensureVisible(finder);
  await tester.pump();
}
