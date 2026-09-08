import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/app_database.dart';
import '../data/record_history_source.dart';
import '../domain/trend_series.dart';
import 'record_history_widgets.dart';

class DatabaseRecordChart extends ConsumerStatefulWidget {
  const DatabaseRecordChart({
    super.key,
    required this.scope,
    required this.overview,
    this.bars = false,
    this.target,
  });
  final RecordHistoryScope scope;
  final RecordHistoryOverview overview;
  final bool bars;
  final WaterQualityTarget? target;
  @override
  ConsumerState<DatabaseRecordChart> createState() =>
      _DatabaseRecordChartState();
}

class _DatabaseRecordChartState extends ConsumerState<DatabaseRecordChart> {
  List<IndexedHistoryRecord> _window = const [];
  int _generation = 0, _requestedStart = -1;
  String? _error;
  @override
  void initState() {
    super.initState();
    _loadLatest();
  }

  @override
  void didUpdateWidget(DatabaseRecordChart old) {
    super.didUpdateWidget(old);
    if (old.scope != widget.scope || old.overview != widget.overview) {
      if (old.scope != widget.scope) _window = const [];
      final start =
          old.scope != widget.scope ||
              old.overview.count != widget.overview.count
          ? math.max(0, widget.overview.count - 20)
          : math.max(0, _requestedStart);
      _requestedStart = -1;
      _load(start);
    }
  }

  void _loadLatest() => _load(math.max(0, widget.overview.count - 20));
  Future<void> _load(int start) async {
    if (_requestedStart == start) return;
    _requestedStart = start;
    final generation = ++_generation;
    try {
      final result = await ref
          .read(recordHistorySourceProvider)
          .readChartWindow(widget.scope, start, 30);
      if (!mounted || generation != _generation) return;
      setState(() {
        _window = result;
        _error = null;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = '无法读取趋势：$error');
      }
    }
  }

  void _visible(int start, int count) {
    // A small buffer avoids a database read for each scroll frame.
    if (start >= _requestedStart && start + count <= _requestedStart + 30) {
      return;
    }
    _load(math.max(0, start - 8));
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (_error != null)
        TextButton(
          onPressed: () {
            _requestedStart = -1;
            _loadLatest();
          },
          child: Text(_error!),
        ),
      ScrollableRecordChart(
        key: ValueKey(widget.scope),
        data: [for (final item in _window) TrendDatum(record: item.record)],
        indices: [for (final item in _window) item.index],
        totalCount: widget.overview.count,
        maximumValue: widget.bars
            ? widget.overview.pointMaximum
            : widget.overview.maximum,
        bars: widget.bars,
        target: widget.target,
        onWindowChanged: _visible,
      ),
    ],
  );
}

class DatabaseRecordHistory extends ConsumerStatefulWidget {
  const DatabaseRecordHistory({
    super.key,
    required this.scope,
    required this.overview,
    required this.onOpen,
    this.rowBuilder,
    this.title = '检测记录',
  });
  final RecordHistoryScope scope;
  final RecordHistoryOverview overview;
  final ValueChanged<TestRecord> onOpen;
  final Widget Function(TestRecord)? rowBuilder;
  final String title;
  @override
  ConsumerState<DatabaseRecordHistory> createState() =>
      _DatabaseRecordHistoryState();
}

class _DatabaseRecordHistoryState extends ConsumerState<DatabaseRecordHistory> {
  List<TestRecord> _records = const [];
  bool _loading = false;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(DatabaseRecordHistory old) {
    super.didUpdateWidget(old);
    if (old.scope != widget.scope || old.overview != widget.overview) _reset();
  }

  void _reset() {
    _generation++;
    _records = const [];
    _loading = false;
    _load();
  }

  Future<void> _load() async {
    if (_loading || _records.length >= widget.overview.count) return;
    final generation = _generation;
    _loading = true;
    try {
      final page = await ref
          .read(recordHistorySourceProvider)
          .readPage(widget.scope, after: _records.lastOrNull);
      if (!mounted || generation != _generation) return;
      setState(() {
        _records = [..._records, ...page];
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = '无法读取检测记录：$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (_error != null) TextButton(onPressed: _load, child: Text(_error!)),
      PagedRecordHistory(
        records: _records,
        totalCount: widget.overview.count,
        loading: _loading,
        onOpen: widget.onOpen,
        rowBuilder: widget.rowBuilder,
        title: widget.title,
        onLoadMore: () {
          _load();
          setState(() {});
        },
        onExpanded: (expanded) {
          _generation++;
          _records = const [];
          _loading = false;
          if (expanded) _load();
          setState(() {});
        },
      ),
    ],
  );
}
