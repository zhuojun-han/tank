import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/features/test_timer/domain/test_timer.dart';

void main() {
  test('只接受 10 秒至 60 分钟并提供 3/5/10 分钟快捷值', () {
    expect(TestTimerSnapshot.quickDurationSeconds, [180, 300, 600]);
    expect(() => TestTimerSnapshot.validateDuration(9), throwsArgumentError);
    expect(() => TestTimerSnapshot.validateDuration(3601), throwsArgumentError);
    expect(() => TestTimerSnapshot.validateDuration(10), returnsNormally);
    expect(() => TestTimerSnapshot.validateDuration(3600), returnsNormally);
  });

  test('启动后锁定时长并按 UTC 绝对结束时间恢复剩余时间', () {
    final started = DateTime.utc(2026, 8, 12, 1);
    final timer = const TestTimerSnapshot(
      configuredDurationSeconds: 300,
    ).start(started);

    expect(timer.endsAtUtc, DateTime.utc(2026, 8, 12, 1, 5));
    expect(
      timer.remainingSecondsAt(started.add(const Duration(seconds: 61))),
      239,
    );
    expect(() => timer.withConfiguredDuration(600), throwsA(isA<StateError>()));
    expect(
      timer.effectivePhaseAt(started.add(const Duration(minutes: 6))),
      TestTimerPhase.completed,
    );
  });

  test('暂停保存剩余秒数，继续时建立新的绝对结束时间', () {
    final started = DateTime.utc(2026, 8, 12, 1);
    final running = const TestTimerSnapshot(
      configuredDurationSeconds: 300,
    ).start(started);
    final paused = running.pause(started.add(const Duration(seconds: 40)));

    expect(paused.phase, TestTimerPhase.paused);
    expect(paused.pausedRemainingSeconds, 260);
    expect(
      paused.remainingSecondsAt(started.add(const Duration(days: 1))),
      260,
    );

    final resumedAt = DateTime.utc(2026, 8, 13, 2);
    final resumed = paused.resume(resumedAt);
    expect(resumed.endsAtUtc, resumedAt.add(const Duration(seconds: 260)));
    expect(resumed.startedAtUtc, started);
  });

  test('重置保留已配置默认值并解除锁定', () {
    final timer = const TestTimerSnapshot(
      configuredDurationSeconds: 600,
    ).start(DateTime.utc(2026, 8, 12));
    final reset = timer.reset();

    expect(reset.phase, TestTimerPhase.idle);
    expect(reset.configuredDurationSeconds, 600);
    expect(reset.isDurationLocked, isFalse);
  });
}
