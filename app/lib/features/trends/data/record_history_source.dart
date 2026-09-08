import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/app_database.dart';
import '../../tanks/application/tank_providers.dart';

typedef RecordHistoryScope = ({String tankId, String? parameterId});

class RecordHistoryOverview {
  const RecordHistoryOverview({
    required this.count,
    this.latest,
    this.maximum = 0,
    this.pointMaximum = 0,
  });
  final int count;
  final TestRecord? latest;
  final double maximum, pointMaximum;
}

class IndexedHistoryRecord {
  const IndexedHistoryRecord(this.index, this.record);
  final int index;
  final TestRecord record;
}

abstract interface class RecordHistorySource {
  Stream<RecordHistoryOverview> watchOverview(RecordHistoryScope scope);
  Future<List<TestRecord>> readPage(
    RecordHistoryScope scope, {
    TestRecord? after,
    int limit = 10,
  });
  Future<List<IndexedHistoryRecord>> readChartWindow(
    RecordHistoryScope scope,
    int start,
    int count,
  );
}

final recordHistorySourceProvider = Provider<RecordHistorySource>(
  (ref) => DatabaseRecordHistorySource(ref.watch(appDatabaseProvider)),
);
final recordHistoryOverviewProvider = StreamProvider.autoDispose.family(
  (ref, RecordHistoryScope scope) =>
      ref.watch(recordHistorySourceProvider).watchOverview(scope),
);

/// Stable measuredAt/updatedAt/id ordering prevents duplicates at page ties.
/// Full records (notes and estimation metadata) are read only for requested pages.
class DatabaseRecordHistorySource implements RecordHistorySource {
  DatabaseRecordHistorySource(this.database);
  final AppDatabase database;
  $TestRecordsTable get _table => database.testRecords;
  Expression<bool> _scope(RecordHistoryScope scope) =>
      _table.tankId.equals(scope.tankId) &
      (scope.parameterId == null
          ? const Constant(true)
          : _table.parameterId.equals(scope.parameterId!));
  Expression<bool> _older(TestRecord row) =>
      _table.measuredAt.isSmallerThanValue(row.measuredAt) |
      (_table.measuredAt.equals(row.measuredAt) &
          (_table.updatedAt.isSmallerThanValue(row.updatedAt) |
              (_table.updatedAt.equals(row.updatedAt) &
                  _table.id.isSmallerThanValue(row.id))));
  List<OrderingTerm> _order({bool descending = true}) => [
    for (final column in [_table.measuredAt, _table.updatedAt, _table.id])
      OrderingTerm(
        expression: column,
        mode: descending ? OrderingMode.desc : OrderingMode.asc,
      ),
  ];
  Expression<bool> get _hasPoint =>
      _table.confirmedInterpolation.isNotNull() |
      _table.confirmedMaxValue.isNull() |
      _table.confirmedMaxValue.equalsExp(_table.confirmedMinValue);

  @override
  Stream<RecordHistoryOverview> watchOverview(RecordHistoryScope scope) {
    final count = _table.id.count();
    final maximum = const CustomExpression<double>(
      'COALESCE(confirmed_max_value, confirmed_min_value)',
    ).max();
    final pointMaximum = const CustomExpression<double>(
      'COALESCE(confirmed_interpolation, CASE WHEN confirmed_max_value IS NULL '
      'OR confirmed_max_value = confirmed_min_value THEN confirmed_min_value END)',
    ).max();
    final query = database.selectOnly(_table)
      ..addColumns([count, maximum, pointMaximum])
      ..where(_scope(scope));
    // Do not distinct by count: an edit must refresh a visible older page too.
    return query.watchSingle().asyncMap((row) async {
      final latest =
          await (database.select(_table)
                ..where((_) => _scope(scope))
                ..orderBy([
                  (t) => OrderingTerm.desc(t.measuredAt),
                  (t) => OrderingTerm.desc(t.updatedAt),
                  (t) => OrderingTerm.desc(t.id),
                ])
                ..limit(1))
              .getSingleOrNull();
      return RecordHistoryOverview(
        count: row.read(count) ?? 0,
        latest: latest,
        maximum: row.read(maximum) ?? 0,
        pointMaximum: row.read(pointMaximum) ?? 0,
      );
    });
  }

  @override
  Future<List<TestRecord>> readPage(
    RecordHistoryScope scope, {
    TestRecord? after,
    int limit = 10,
  }) {
    if (limit <= 0 || limit > 100) throw ArgumentError('分页须为 1–100 条');
    final query = database.select(_table)
      ..where(
        (_) =>
            _scope(scope) &
            (after == null ? const Constant(true) : _older(after)),
      )
      ..orderBy([for (final term in _order()) (_) => term])
      ..limit(limit);
    return query.get();
  }

  @override
  Future<List<IndexedHistoryRecord>> readChartWindow(
    RecordHistoryScope scope,
    int start,
    int count,
  ) => database.transaction(() async {
    if (start < 0 || count <= 0 || count > 100) throw ArgumentError('图表窗口无效');
    final records =
        await (database.select(_table)
              ..where((_) => _scope(scope))
              ..orderBy([
                for (final term in _order(descending: false)) (_) => term,
              ])
              ..limit(count, offset: start))
            .get();
    if (records.isEmpty) return const <IndexedHistoryRecord>[];
    final result = [
      for (var i = 0; i < records.length; i++)
        IndexedHistoryRecord(start + i, records[i]),
    ];
    // The nearest point outside each edge keeps a line continuous even when
    // many range-only records separate two interpolated values.
    for (final before in [true, false]) {
      final edge = before ? records.first : records.last;
      final condition = before
          ? _older(edge)
          : (_older(edge).not() & _table.id.equals(edge.id).not());
      final neighbor =
          await (database.select(_table)
                ..where((_) => _scope(scope) & condition & _hasPoint)
                ..orderBy([
                  for (final term in _order(descending: before)) (_) => term,
                ])
                ..limit(1))
              .getSingleOrNull();
      if (neighbor == null) continue;
      final aggregate = _table.id.count();
      final indexRow =
          await (database.selectOnly(_table)
                ..addColumns([aggregate])
                ..where(_scope(scope) & _older(neighbor)))
              .getSingle();
      result.add(IndexedHistoryRecord(indexRow.read(aggregate) ?? 0, neighbor));
    }
    result.sort((a, b) => a.index.compareTo(b.index));
    return result;
  });
}
