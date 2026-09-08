import 'dart:async';
import 'package:flutter/widgets.dart';
import '../data/maintenance_repository.dart';
import '../domain/recurrence.dart';

/// Calendar presentation needs minute changes and exact pending deadlines,
/// rather than a permanently running second ticker.
DateTime nextMaintenanceRefresh(DateTime now, List<MaintenanceTaskItem> items) {
  final local = now.toLocal();
  var next = DateTime(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute + 1,
  );
  void include(DateTime? date) {
    if (date != null && date.isAfter(now) && date.isBefore(next)) next = date;
  }

  for (final item in items) {
    if (item.task.status != 'enabled') continue;
    include(item.task.dueAt);
    include(item.latestEvent?.snoozedUntil);
    final encoded = item.task.recurrenceJson;
    if (encoded != null) {
      final rule = Recurrence.decode(encoded);
      if (rule.occurs(item.task, localDate(now)) &&
          rule.stateOn(localDate(now)) == 'pending') {
        include(rule.dueOn(item.task, localDate(now)));
        include(DateTime.tryParse(rule.snoozes[dateKey(now)] ?? ''));
      }
    }
  }
  return next;
}

class MaintenanceClock with WidgetsBindingObserver {
  MaintenanceClock({DateTime Function()? now}) : _now = now ?? DateTime.now {
    _events = StreamController<DateTime>(onListen: refresh);
    WidgetsBinding.instance.addObserver(this);
  }
  final DateTime Function() _now;
  late final StreamController<DateTime> _events;
  Timer? _timer;
  List<MaintenanceTaskItem> _items = const [];
  bool _paused = false;
  bool _closed = false;
  Stream<DateTime> get stream => _events.stream;

  void update(List<MaintenanceTaskItem> items) {
    _items = items;
    if (_events.hasListener) refresh();
  }

  void refresh() {
    _timer?.cancel();
    if (_closed || _paused) return;
    final now = _now();
    _events.add(now);
    _timer = Timer(
      nextMaintenanceRefresh(now, _items).difference(now),
      refresh,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    if (_paused) {
      _timer?.cancel();
    } else {
      refresh();
    }
  }

  void dispose() {
    _closed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_events.close());
  }
}
