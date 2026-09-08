import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanjiao_water_quality/features/trends/data/record_history_source.dart';
import 'package:lanjiao_water_quality/features/trends/presentation/database_record_history_widgets.dart';
import '../../support/record_history_fixture.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/trends/domain/trend_series.dart';
import 'package:lanjiao_water_quality/features/trends/presentation/record_history_widgets.dart';
import 'package:lanjiao_water_quality/features/calculators/presentation/maintenance_dosing_page.dart';

TestRecord record(int i, {double? point}) => TestRecord(
  id: 'r$i',
  tankId: 'tank',
  parameterId: 'NO3',
  confirmedMinValue: 10,
  confirmedMaxValue: 25,
  confirmedInterpolation: point,
  unit: 'mg/L',
  measuredAt: DateTime(2026, 9, 1).add(Duration(days: i)),
  wasManuallyEdited: false,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  notes: '不在列表显示的说明',
);
void main() {
  testWidgets(
    'database history requests ten rows only, then pages on scroll and resets on reopen',
    (tester) async {
      final records = List.generate(25, record);
      final source = FixtureRecordHistorySource(records);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [recordHistorySourceProvider.overrideWithValue(source)],
          child: MaterialApp(
            home: Scaffold(
              body: DatabaseRecordHistory(
                scope: (tankId: 'tank', parameterId: 'NO3'),
                overview: RecordHistoryOverview(
                  count: records.length,
                  latest: records.last,
                ),
                onOpen: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(source.requestedPageLimits, [10]);
      expect(find.text('已加载 10 / 共 25 条'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(source.requestedPageLimits, [10, 10]);
      expect(find.text('已加载 20 / 共 25 条'), findsOneWidget);
      await tester.tap(find.text('检测记录'));
      await tester.pumpAndSettle();
      expect(source.requestedPageLimits, [10, 10]);
      await tester.tap(find.text('检测记录'));
      await tester.pumpAndSettle();
      expect(source.requestedPageLimits, [10, 10, 10]);
      expect(find.text('已加载 10 / 共 25 条'), findsOneWidget);
    },
  );
  testWidgets(
    'history loads ten at a time within its own scroll and collapses/reset',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PagedRecordHistory(
              records: List.generate(25, record),
              onOpen: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('已加载 10 / 共 25 条'), findsOneWidget);
      expect(find.textContaining('不在列表显示'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(find.text('已加载 20 / 共 25 条'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.text('已加载 25 / 共 25 条'), findsOneWidget);
      await tester.tap(find.text('检测记录'));
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNothing);
      await tester.tap(find.text('检测记录'));
      await tester.pumpAndSettle();
      expect(find.text('已加载 10 / 共 25 条'), findsOneWidget);
    },
  );
  testWidgets(
    'line and bar charts show five slots, open latest and scroll to older history',
    (tester) async {
      for (final bars in [false, true]) {
        final data = List.generate(
          12,
          (i) => TrendDatum(record: record(i, point: i == 5 ? null : 18)),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 375,
                child: ScrollableRecordChart(
                  key: ValueKey(bars),
                  data: data,
                  bars: bars,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
        expect(scroll.position.pixels, greaterThan(0));
        final before = scroll.position.pixels;
        await tester.tap(find.text('← 较早'));
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, lessThan(before));
        expect(data[5].point, isNull);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'reservoir volume and flow update rounded days and three significant figures',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MaintenanceDosingPage()));
      await tester.enterText(find.byKey(const Key('dosing-volume')), '560');
      await tester.pump();
      expect(find.text('预计可用 7 天（6.67 天）'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('dosing-volume')), '0');
      await tester.pump();
      expect(find.byKey(const Key('dosing-error')), findsOneWidget);
      expect(find.byKey(const Key('dosing-days')), findsNothing);
    },
  );
}
