import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../data/database/app_database.dart';
import '../domain/trend_series.dart';

String trendNumber(double value) =>
    value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

/// Format the confirmed value, never the original calculation's display string.
String recordTrendNumber(double value, TestRecord record) {
  final single =
      record.confirmedMaxValue == null ||
      record.confirmedMaxValue == record.confirmedMinValue;
  return record.parameterId == AppDatabase.khId &&
          record.khTitrationJson != null &&
          single
      ? value.toStringAsFixed(1)
      : trendNumber(value);
}

String recordTrendValue(TestRecord record) {
  final minimum = recordTrendNumber(record.confirmedMinValue, record);
  final maximum = record.confirmedMaxValue;
  return maximum == null || maximum == record.confirmedMinValue
      ? minimum
      : '$minimum–${recordTrendNumber(maximum, record)}';
}

String recordDate(DateTime value) {
  final d = value.toLocal();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class ScrollableRecordChart extends StatefulWidget {
  const ScrollableRecordChart({
    super.key,
    required this.data,
    this.bars = false,
    this.target,
    this.indices,
    this.totalCount,
    this.maximumValue,
    this.onWindowChanged,
  });
  final List<TrendDatum> data;
  final List<int>? indices;
  final int? totalCount;
  final double? maximumValue;
  final void Function(int start, int count)? onWindowChanged;
  final bool bars;
  final WaterQualityTarget? target;
  @override
  State<ScrollableRecordChart> createState() => _ScrollableRecordChartState();
}

class _ScrollableRecordChartState extends State<ScrollableRecordChart> {
  final _scroll = ScrollController();
  double _slot = 68;
  (int, int)? _lastWindow;
  int get _count => widget.totalCount ?? widget.data.length;
  void _windowChanged() {
    if (!_scroll.hasClients || widget.onWindowChanged == null) return;
    final start = math.max(0, (_scroll.offset / _slot).floor() - 2);
    final count = (_scroll.position.viewportDimension / _slot).ceil() + 5;
    if (_lastWindow == (start, count)) return;
    _lastWindow = (start, count);
    widget.onWindowChanged!(start, count);
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_windowChanged);
    _latest();
  }

  @override
  void didUpdateWidget(ScrollableRecordChart old) {
    super.didUpdateWidget(old);
    if ((old.totalCount ?? old.data.length) != _count ||
        (widget.totalCount == null &&
            old.data.lastOrNull?.record.id !=
                widget.data.lastOrNull?.record.id)) {
      _latest();
    }
  }

  void _latest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
        _windowChanged();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(int direction) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        (_scroll.offset + direction * _scroll.position.viewportDimension).clamp(
          0.0,
          _scroll.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(widget.bars ? '插值 / 单值' : '范围与插值', textAlign: TextAlign.center),
      Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _move(-1),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                ),
                child: const Text('← 较早'),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _move(1),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                ),
                child: const Text('最近 →'),
              ),
            ),
          ),
        ],
      ),
      LayoutBuilder(
        builder: (context, c) {
          final slot = math.max(1.0, c.maxWidth / 5);
          _slot = slot;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _windowChanged();
          });
          return Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: CustomPaint(
                size: Size(
                  math.max(c.maxWidth, _count * slot),
                  widget.bars ? 170 : 260,
                ),
                painter: _HistoryPainter(
                  widget.data,
                  slot,
                  widget.bars,
                  Theme.of(context).colorScheme,
                  widget.target,
                  _scroll,
                  widget.indices,
                  widget.maximumValue,
                ),
              ),
            ),
          );
        },
      ),
    ],
  );
}

class _HistoryPainter extends CustomPainter {
  _HistoryPainter(
    this.data,
    this.slot,
    this.bars,
    this.colors,
    this.target,
    this.scroll,
    List<int>? indices,
    this.maximumValue,
  ) : indices = indices ?? List.generate(data.length, (i) => i),
      points = [
        for (var i = 0; i < data.length; i++)
          if (data[i].point != null) i,
      ],
      super(repaint: scroll);
  final ScrollController scroll;
  final List<int> indices, points;
  final double? maximumValue;
  int _lowerBound(List<int> values, int needle) {
    var lo = 0, hi = values.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (values[mid] < needle) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  final List<TrendDatum> data;
  final double slot;
  final bool bars;
  final ColorScheme colors;
  final WaterQualityTarget? target;
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxValue =
        math.max(
          1e-9,
          maximumValue ??
              data.fold<double>(
                0,
                (m, d) => math.max(m, bars ? (d.point ?? 0) : d.upper),
              ),
        ) *
        1.25;
    const top = 28.0;
    final bottom = size.height - 38;
    double y(double value) => bottom - (value / maxValue) * (bottom - top);
    final line = Paint()
      ..color = colors.primary
      ..strokeWidth = 2.5;
    final purple = Paint()
      ..color = Colors.purple.shade300
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(0, bottom),
      Offset(size.width, bottom),
      Paint()..color = colors.outlineVariant,
    );
    final offset = scroll.hasClients ? scroll.offset : 0.0;
    final width = scroll.hasClients
        ? scroll.position.viewportDimension
        : size.width;
    final firstIndex = math.max(0, (offset / slot).floor() - 1);
    final lastIndex = ((offset + width) / slot).ceil() + 1;
    final first = _lowerBound(indices, firstIndex);
    final last = _lowerBound(indices, lastIndex + 1);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(offset, 0, width, size.height));
    if (!bars && points.isNotEmpty) {
      final left = math.max(0, _lowerBound(points, first) - 1);
      final right = math.min(points.length, _lowerBound(points, last) + 1);
      for (var p = left + 1; p < right; p++) {
        final a = points[p - 1], b = points[p];
        canvas.drawLine(
          Offset((indices[a] + .5) * slot, y(data[a].point!)),
          Offset((indices[b] + .5) * slot, y(data[b].point!)),
          line,
        );
      }
    }
    void text(String value, double x, double yy, Color color) {
      final p = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(fontSize: 11, color: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: slot - 4);
      p.paint(canvas, Offset(x - p.width / 2, yy));
    }

    for (var i = first; i < last; i++) {
      final datum = data[i];
      final x = (indices[i] + .5) * slot;
      final point = datum.point;
      if (!bars && datum.lower != datum.upper) {
        final high = y(datum.upper), low = y(datum.lower);
        canvas.drawLine(Offset(x, high), Offset(x, low), purple);
        for (final yy in [high, low]) {
          canvas.drawLine(Offset(x - 6, yy), Offset(x + 6, yy), purple);
        }
        text(trendNumber(datum.upper), x, high - 17, Colors.purple.shade400);
        text(trendNumber(datum.lower), x, low + 4, Colors.purple.shade400);
      }
      if (point != null) {
        final location = Offset(x, y(point));
        if (bars) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(x - 12, location.dy, x + 12, bottom),
              const Radius.circular(5),
            ),
            line,
          );
        } else {
          canvas.drawCircle(location, 4, line);
        }
        text(
          recordTrendNumber(point, datum.record),
          x,
          location.dy - (datum.lower != datum.upper && !bars ? 32 : 18),
          colors.primary,
        );
      } else {
        text('未填插值', x, bottom - 18, colors.onSurfaceVariant);
      }
      text(
        recordDate(datum.record.measuredAt).substring(5),
        x,
        bottom + 10,
        colors.onSurfaceVariant,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HistoryPainter old) =>
      old.data != data ||
      old.slot != slot ||
      old.bars != bars ||
      old.colors != colors ||
      old.indices != indices ||
      old.maximumValue != maximumValue ||
      old.target != target;
}

class PagedRecordHistory extends StatefulWidget {
  const PagedRecordHistory({
    super.key,
    required this.records,
    required this.onOpen,
    this.totalCount,
    this.loading = false,
    this.onLoadMore,
    this.onReset,
    this.onExpanded,
    this.rowBuilder,
    this.title = '检测记录',
    this.headerTrailing,
  });
  final List<TestRecord> records;
  final ValueChanged<TestRecord> onOpen;
  final int? totalCount;
  final bool loading;
  final VoidCallback? onLoadMore, onReset;
  final ValueChanged<bool>? onExpanded;
  final Widget Function(TestRecord)? rowBuilder;
  final String title;
  final Widget? headerTrailing;
  @override
  State<PagedRecordHistory> createState() => _PagedRecordHistoryState();
}

class _PagedRecordHistoryState extends State<PagedRecordHistory> {
  int _limit = 10;
  bool _expanded = true;
  void _more() {
    if (widget.loading) return;
    if (widget.onLoadMore != null) {
      widget.onLoadMore!();
      return;
    }
    if (_limit < widget.records.length) setState(() => _limit += 10);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.totalCount == null
        ? math.min(_limit, widget.records.length)
        : widget.records.length;
    final total = widget.totalCount ?? widget.records.length;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text('已加载 $count / 共 $total 条'),
                trailing: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                ),
                onTap: () => setState(() {
                  _expanded = !_expanded;
                  _limit = 10;
                  widget.onReset?.call();
                  widget.onExpanded?.call(_expanded);
                }),
              ),
            ),
            if (widget.headerTrailing != null) widget.headerTrailing!,
          ],
        ),
        if (_expanded)
          SizedBox(
            height: math.min(480.0, count * 100.0 + 48),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollEndNotification &&
                    n.metrics.axis == Axis.vertical &&
                    n.metrics.extentAfter < 80) {
                  _more();
                }
                return false;
              },
              child: ListView.builder(
                primary: false,
                itemCount: count + 1,
                itemBuilder: (context, i) {
                  if (i == count) {
                    if (widget.loading) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return count < total
                        ? TextButton(
                            onPressed: _more,
                            child: const Text('加载更多'),
                          )
                        : const SizedBox(height: 16);
                  }
                  final r = widget.records[i];
                  if (widget.rowBuilder != null) return widget.rowBuilder!(r);
                  final range =
                      r.confirmedMaxValue != null &&
                      r.confirmedMaxValue != r.confirmedMinValue;
                  final point =
                      r.confirmedInterpolation ??
                      (range ? null : r.confirmedMinValue);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      key: Key('trend-record-${r.id}'),
                      title: Text('${recordTrendValue(r)} ${r.unit}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (range)
                            Text(
                              '插值：${point == null ? '未填' : trendNumber(point)}${point == null ? '' : ' ${r.unit}'}',
                            ),
                          Text(recordDate(r.measuredAt)),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => widget.onOpen(r),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
