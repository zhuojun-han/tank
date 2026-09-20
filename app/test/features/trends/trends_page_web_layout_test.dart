import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanjiao_water_quality/app/theme.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/tanks/application/tank_providers.dart';
import 'package:lanjiao_water_quality/features/trends/data/record_history_source.dart';
import 'package:lanjiao_water_quality/features/trends/presentation/trends_page.dart';
import '../../support/record_history_fixture.dart';

void main() {
  final now = DateTime(2026, 9, 9);
  final tank = Tank(
    id: 'a',
    name: '当前缸',
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
  WaterParameter parameter(String id) => WaterParameter(
    id: id,
    code: id,
    displayName: id == 'NO3' ? '硝酸盐' : '磷酸盐',
    unit: 'mg/L',
    isBuiltIn: true,
    photoSupported: true,
    createdAt: now,
  );
  TestRecord record(
    int index, {
    String parameterId = 'NO3',
    String tankId = 'a',
  }) => TestRecord(
    id: '$tankId-$parameterId-$index',
    tankId: tankId,
    parameterId: parameterId,
    confirmedMinValue: parameterId == 'NO3' ? 10 : .03,
    confirmedMaxValue: parameterId == 'NO3' ? 25 : .1,
    confirmedInterpolation: parameterId == 'NO3' ? 18 : .07,
    unit: 'mg/L',
    measuredAt: now.subtract(Duration(days: index)),
    wasManuallyEdited: false,
    createdAt: now,
    updatedAt: now,
  );

  testWidgets('网页层级、十条记录、按指标切换及添加入口保持当前范围', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = FixtureRecordHistorySource([
      ...List.generate(25, (i) => record(i)),
      record(0, parameterId: 'PO4'),
      record(-1, tankId: 'other'),
    ]);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: TrendsPage()),
        ),
        GoRoute(
          path: '/test-flow',
          builder: (_, state) => Scaffold(
            body: Text('检测 ${state.uri.queryParameters['parameterId']}'),
          ),
        ),
      ],
    );
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentTankProvider.overrideWith((ref) => Stream.value(tank)),
            enabledParametersProvider(tank.id).overrideWith(
              (ref) => Stream.value([parameter('NO3'), parameter('PO4')]),
            ),
            waterQualityTargetsProvider(
              tank.id,
            ).overrideWith((ref) => Stream.value([])),
            recordHistorySourceProvider.overrideWithValue(source),
          ],
          child: MaterialApp.router(
            theme: LanjiaoTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('水质变化'), findsOneWidget);
      expect(find.text('已加载 10 / 共 25 条'), findsOneWidget);
      expect(source.requestedPageLimits, [10]);
      expect(
        tester.getTopLeft(find.byKey(const Key('trend-parameter-selector'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('trend-summary'))).dy),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('trend-summary'))).dy,
        lessThan(tester.getTopLeft(find.text('检测记录')).dy),
      );
      expect(find.byKey(const Key('trend-record-a-NO3-0')), findsOneWidget);
      expect(find.byKey(const Key('trend-record-other-NO3--1')), findsNothing);
      final firstCard = find.byKey(const Key('trend-record-a-NO3-0'));
      expect(
        find.descendant(of: firstCard, matching: find.text('NO3')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: firstCard, matching: find.text('2026-09-09')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('trend-parameter-PO4')));
      await tester.pumpAndSettle();
      expect(find.text('已加载 1 / 共 1 条'), findsOneWidget);
      expect(find.byKey(const Key('trend-record-a-NO3-0')), findsNothing);
      expect(find.byKey(const Key('trend-record-a-PO4-0')), findsOneWidget);
      await tester.tap(find.byKey(const Key('trend-add-record')));
      await tester.pumpAndSettle();
      expect(find.text('检测 PO4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      router.dispose();
    }
  });

  testWidgets('窄屏大字体记录与目标编辑可见，取消保持参数与结果', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = FixtureRecordHistorySource([record(0)]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTankProvider.overrideWith((ref) => Stream.value(tank)),
          enabledParametersProvider(
            tank.id,
          ).overrideWith((ref) => Stream.value([parameter('NO3')])),
          waterQualityTargetsProvider(
            tank.id,
          ).overrideWith((ref) => Stream.value([])),
          recordHistorySourceProvider.overrideWithValue(source),
        ],
        child: MaterialApp(
          theme: LanjiaoTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: const Scaffold(body: TrendsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('trend-target-editor')));
    await tester.tap(find.byKey(const Key('trend-target-editor')));
    await tester.pumpAndSettle();
    expect(find.text('NO3 目标范围'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('target-min-value')), '2');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('尚未设置目标范围'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('trend-record-a-NO3-0')));
    await tester.pumpAndSettle();
    expect(find.text('2026-09-09'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
