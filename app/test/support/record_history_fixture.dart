import 'dart:math' as math;
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/trends/data/record_history_source.dart';
import 'package:lanjiao_water_quality/features/trends/domain/trend_series.dart';

class FixtureRecordHistorySource implements RecordHistorySource {
  FixtureRecordHistorySource(this.records);
  final List<TestRecord> records;
  final List<int> requestedPageLimits = [];
  List<TestRecord> _items(RecordHistoryScope scope) {
    final result = records
        .where(
          (r) =>
              r.tankId == scope.tankId &&
              (scope.parameterId == null || r.parameterId == scope.parameterId),
        )
        .toList();
    result.sort((a, b) {
      final measured = b.measuredAt.compareTo(a.measuredAt);
      if (measured != 0) return measured;
      final updated = b.updatedAt.compareTo(a.updatedAt);
      return updated != 0 ? updated : b.id.compareTo(a.id);
    });
    return result;
  }

  @override
  Stream<RecordHistoryOverview> watchOverview(RecordHistoryScope scope) {
    final items = _items(scope);
    return Stream.value(
      RecordHistoryOverview(
        count: items.length,
        latest: items.firstOrNull,
        maximum: items.fold(
          0.0,
          (m, r) => math.max(m, TrendDatum(record: r).upper),
        ),
        pointMaximum: items.fold(
          0.0,
          (m, r) => math.max(m, TrendDatum(record: r).point ?? 0),
        ),
      ),
    );
  }

  @override
  Future<List<TestRecord>> readPage(
    RecordHistoryScope scope, {
    TestRecord? after,
    int limit = 10,
  }) async {
    requestedPageLimits.add(limit);
    final items = _items(scope);
    final start = after == null
        ? 0
        : items.indexWhere((r) => r.id == after.id) + 1;
    return items.skip(start).take(limit).toList();
  }

  @override
  Future<List<IndexedHistoryRecord>> readChartWindow(
    RecordHistoryScope scope,
    int start,
    int count,
  ) async {
    final items = _items(scope).reversed.toList();
    return [
      for (var i = 0; i < items.length; i++) IndexedHistoryRecord(i, items[i]),
    ];
  }
}
