import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/test_timer/domain/kh_titration.dart';
import 'package:lanjiao_water_quality/features/trends/presentation/record_history_widgets.dart';

TestRecord entry(
  String id,
  double value, {
  String parameterId = AppDatabase.khId,
  String? metadata,
  double? maximum,
}) => TestRecord(
  id: id,
  tankId: 'tank',
  parameterId: parameterId,
  confirmedMinValue: value,
  confirmedMaxValue: maximum,
  khTitrationJson: metadata,
  unit: parameterId == AppDatabase.khId ? 'dKH' : 'mg/L',
  measuredAt: DateTime.utc(2026, 9, 8),
  wasManuallyEdited: false,
  createdAt: DateTime.utc(2026, 9, 8),
  updatedAt: DateTime.utc(2026, 9, 8),
);

void main() {
  final original = jsonEncode(calculateKhTitration(1, 0.48).toJson());
  final zero = jsonEncode(calculateKhTitration(1, 0.98).toJson());

  test(
    'KH chart and card labels use confirmed values and titration provenance',
    () {
      for (final (record, expected) in [
        (entry('eight', 8, metadata: original), '8.0'),
        (entry('zero', 0, metadata: zero), '0.0'),
        (entry('equal', 8, maximum: 8, metadata: original), '8.0'),
        (entry('edited', 8.1, metadata: original), '8.1'),
        (entry('manual', 8), '8'),
        (entry('manual-zero', 0), '0'),
        (
          entry('other', 8, parameterId: AppDatabase.no3Id, metadata: original),
          '8',
        ),
      ]) {
        expect(recordTrendNumber(record.confirmedMinValue, record), expected);
        expect(recordTrendValue(record), expected);
      }
      expect(
        recordTrendValue(
          entry('range', 8.45, maximum: 9.125, metadata: original),
        ),
        '8.45–9.125',
      );
      expect(jsonDecode(original)['displayDkh'], '8.0');
    },
  );

  testWidgets(
    'history keeps KH .0 and shows edited values without replacing raw data',
    (tester) async {
      Future<void> show(TestRecord first) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PagedRecordHistory(
                records: [
                  first,
                  entry('zero', 0, metadata: zero),
                ],
                onOpen: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await show(entry('eight', 8, metadata: original));
      expect(find.text('8.0 dKH'), findsOneWidget);
      expect(find.text('0.0 dKH'), findsOneWidget);
      expect(find.text('8–8 dKH'), findsNothing);
      final edited = entry('eight', 8.1, metadata: original);
      await show(edited);
      expect(find.text('8.1 dKH'), findsOneWidget);
      expect(find.text('8.0 dKH'), findsNothing);
      expect(find.text('0.0 dKH'), findsOneWidget);
      expect(edited.khTitrationJson, original);
      expect(jsonDecode(edited.khTitrationJson!)['displayDkh'], '8.0');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manual KH and records changed to another parameter keep normal precision',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PagedRecordHistory(
              records: [
                entry('manual', 8),
                entry(
                  'other',
                  8,
                  parameterId: AppDatabase.no3Id,
                  metadata: original,
                ),
                entry('fraction', 0.123, parameterId: AppDatabase.po4Id),
              ],
              onOpen: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('8 dKH'), findsOneWidget);
      expect(find.text('8 mg/L'), findsOneWidget);
      expect(find.text('0.123 mg/L'), findsOneWidget);
      expect(find.text('8.0 dKH'), findsNothing);
      expect(find.text('8.0 mg/L'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
