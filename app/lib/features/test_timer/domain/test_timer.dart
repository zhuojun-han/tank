enum TestTimerPhase { idle, running, paused, completed }

class TestTimerSnapshot {
  const TestTimerSnapshot({
    required this.configuredDurationSeconds,
    this.phase = TestTimerPhase.idle,
    this.startedAtUtc,
    this.endsAtUtc,
    this.pausedRemainingSeconds,
  }) : assert(
         configuredDurationSeconds >= minimumDurationSeconds &&
             configuredDurationSeconds <= maximumDurationSeconds,
       );

  static const int minimumDurationSeconds = 10;
  static const int maximumDurationSeconds = 60 * 60;
  static const int initialDurationSeconds = 5 * 60;
  static const List<int> quickDurationSeconds = [3 * 60, 5 * 60, 10 * 60];

  final int configuredDurationSeconds;
  final TestTimerPhase phase;
  final DateTime? startedAtUtc;
  final DateTime? endsAtUtc;
  final int? pausedRemainingSeconds;

  bool get isDurationLocked =>
      phase == TestTimerPhase.running || phase == TestTimerPhase.paused;

  TestTimerPhase effectivePhaseAt(DateTime now) {
    if (phase == TestTimerPhase.running && remainingSecondsAt(now) == 0) {
      return TestTimerPhase.completed;
    }
    return phase;
  }

  int remainingSecondsAt(DateTime now) {
    switch (phase) {
      case TestTimerPhase.idle:
        return configuredDurationSeconds;
      case TestTimerPhase.paused:
        return pausedRemainingSeconds ?? 0;
      case TestTimerPhase.completed:
        return 0;
      case TestTimerPhase.running:
        final end = endsAtUtc;
        if (end == null) return 0;
        final milliseconds = end.difference(now.toUtc()).inMilliseconds;
        if (milliseconds <= 0) return 0;
        return (milliseconds / Duration.millisecondsPerSecond).ceil();
    }
  }

  TestTimerSnapshot withConfiguredDuration(int seconds) {
    validateDuration(seconds);
    if (isDurationLocked) {
      throw StateError('计时已开始；请先重置再修改时长');
    }
    return TestTimerSnapshot(configuredDurationSeconds: seconds);
  }

  TestTimerSnapshot start(DateTime now) {
    final utcNow = now.toUtc();
    if (phase == TestTimerPhase.running || phase == TestTimerPhase.paused) {
      throw StateError('计时已经开始');
    }
    return TestTimerSnapshot(
      configuredDurationSeconds: configuredDurationSeconds,
      phase: TestTimerPhase.running,
      startedAtUtc: utcNow,
      endsAtUtc: utcNow.add(Duration(seconds: configuredDurationSeconds)),
    );
  }

  TestTimerSnapshot pause(DateTime now) {
    if (phase != TestTimerPhase.running) {
      throw StateError('只有进行中的计时可以暂停');
    }
    final remaining = remainingSecondsAt(now);
    if (remaining == 0) {
      return TestTimerSnapshot(
        configuredDurationSeconds: configuredDurationSeconds,
        phase: TestTimerPhase.completed,
        startedAtUtc: startedAtUtc,
      );
    }
    return TestTimerSnapshot(
      configuredDurationSeconds: configuredDurationSeconds,
      phase: TestTimerPhase.paused,
      startedAtUtc: startedAtUtc,
      pausedRemainingSeconds: remaining,
    );
  }

  TestTimerSnapshot resume(DateTime now) {
    if (phase != TestTimerPhase.paused) {
      throw StateError('只有已暂停的计时可以继续');
    }
    final remaining = pausedRemainingSeconds ?? 0;
    if (remaining <= 0) {
      return TestTimerSnapshot(
        configuredDurationSeconds: configuredDurationSeconds,
        phase: TestTimerPhase.completed,
        startedAtUtc: startedAtUtc,
      );
    }
    final utcNow = now.toUtc();
    return TestTimerSnapshot(
      configuredDurationSeconds: configuredDurationSeconds,
      phase: TestTimerPhase.running,
      startedAtUtc: startedAtUtc ?? utcNow,
      endsAtUtc: utcNow.add(Duration(seconds: remaining)),
    );
  }

  TestTimerSnapshot reset() =>
      TestTimerSnapshot(configuredDurationSeconds: configuredDurationSeconds);

  static void validateDuration(int seconds) {
    if (seconds < minimumDurationSeconds || seconds > maximumDurationSeconds) {
      throw ArgumentError.value(seconds, 'seconds', '计时时长必须在 10 秒至 60 分钟之间');
    }
  }
}
