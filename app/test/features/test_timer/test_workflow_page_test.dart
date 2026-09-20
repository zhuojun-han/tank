import 'package:lanjiao_water_quality/features/image_estimation/domain/photo_capture_models.dart';
import 'package:lanjiao_water_quality/features/image_estimation/domain/card_color_match.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/core/notifications/local_notification.dart';
import 'package:lanjiao_water_quality/core/notifications/local_notification_service.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/tanks/application/tank_providers.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';
import 'package:lanjiao_water_quality/features/test_records/data/local_photo_storage.dart';
import 'package:lanjiao_water_quality/features/test_timer/application/test_session_providers.dart';
import 'package:lanjiao_water_quality/features/test_timer/application/test_workflow_controller.dart';
import 'package:lanjiao_water_quality/features/test_timer/data/test_session_repository.dart';
import 'package:lanjiao_water_quality/features/test_timer/presentation/test_workflow_page.dart';
import 'package:lanjiao_water_quality/features/test_records/presentation/test_records_page.dart';

void main() {
  testWidgets('准备照片期间切走检测页，保留草稿但不迟到打开相机', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final repository = TestSessionRepository(database);
    final notifications = _WidgetTestNotifications();
    final sessionId = await repository.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
    );
    final delayed = _DelayedPhotoPreparationController(
      TestWorkflowController(
        repository: repository,
        notifications: notifications,
        photoStorage: const LocalPhotoStorage(),
      ),
    );
    final active = ValueNotifier(true);
    var photoRoutes = 0;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => ValueListenableBuilder<bool>(
            valueListenable: active,
            builder: (_, enabled, _) => TickerMode(
              enabled: enabled,
              child: TestWorkflowPage(initialSessionId: sessionId),
            ),
          ),
        ),
        GoRoute(
          path: '/photo-capture',
          builder: (_, _) {
            photoRoutes++;
            return const Scaffold(body: Text('相机页'));
          },
        ),
      ],
    );
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            testWorkflowControllerProvider.overrideWithValue(delayed),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('skip-test-timer')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('skip-test-timer')));
      await tester.pump();
      expect(delayed.started, isTrue);
      active.value = false;
      await tester.pump();
      delayed.release.complete();
      await _waitForStage(
        tester,
        repository: repository,
        sessionId: sessionId,
        stage: ActiveTestStage.photoReady,
      );
      await tester.pumpAndSettle();
      expect(photoRoutes, 0);
      expect(find.text('相机页'), findsNothing);
      expect(await database.select(database.testRecords).get(), isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      if (!delayed.release.isCompleted) delayed.release.complete();
      await _disposeHarness(tester, notifications, database);
      active.dispose();
      router.dispose();
    }
  });

  testWidgets('检测首页直接开始计时，分秒与草稿按缸隔离，重置后可修改', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final repository = TestSessionRepository(database);
    final tanks = TankRepository(database);
    final second = await tanks.createTank(name: '另一缸');
    final notifications = _WidgetTestNotifications();
    final controller = TestWorkflowController(
      repository: repository,
      notifications: notifications,
      photoStorage: const LocalPhotoStorage(),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            testWorkflowControllerProvider.overrideWithValue(controller),
          ],
          child: const MaterialApp(home: Scaffold(body: TestRecordsPage())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('准备检测'), findsOneWidget);
      expect(find.text('当前记录到 我的海缸'), findsOneWidget);
      expect(find.byKey(const Key('test-parameter-tabs')), findsOneWidget);
      expect(find.text('创建检测草稿'), findsNothing);
      expect(await database.select(database.activeTestSessions).get(), isEmpty);
      await tester.enterText(
        find.byKey(const Key('custom-duration-minutes')),
        '2',
      );
      await tester.enterText(
        find.byKey(const Key('custom-duration-seconds')),
        '15',
      );
      await tester.ensureVisible(find.byKey(const Key('start-test-timer')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('start-test-timer')));
      ActiveTestSession? session;
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        session = await repository.readDraft(
          tankId: AppDatabase.defaultTankId,
          parameterId: AppDatabase.no3Id,
        );
        if (session?.stage == ActiveTestStage.timerRunning.name) break;
      }
      expect(session?.stage, ActiveTestStage.timerRunning.name);
      expect(session!.timerDurationSeconds, 135);
      await _waitForNotification(tester, notifications);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('custom-duration-minutes')), findsNothing);
      await tester.ensureVisible(find.text('重置本次计时'));
      await tester.tap(find.text('重置本次计时'));
      await _waitForStage(
        tester,
        repository: repository,
        sessionId: session.id,
        stage: ActiveTestStage.preparation,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('custom-duration-seconds')),
      );
      await tester.enterText(
        find.byKey(const Key('custom-duration-seconds')),
        '90',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('start-test-timer')))
            .onPressed,
        isNull,
      );
      expect(
        (await repository.readDraftById(session.id))!.timerDurationSeconds,
        135,
      );
      await tanks.switchTank(second);
      await tester.pumpAndSettle();
      expect(find.text('当前记录到 另一缸'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);
      expect(
        await repository.readDraft(
          tankId: second,
          parameterId: AppDatabase.no3Id,
        ),
        isNull,
      );
      expect(await database.select(database.testRecords).get(), isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      await _disposeHarness(tester, notifications, database);
    }
  });

  testWidgets('切走底部检测页不后台推进，返回后按原截止时间完成', (tester) async {
    var now = DateTime.utc(2026, 9, 9, 10);
    final database = AppDatabase(NativeDatabase.memory());
    final repository = TestSessionRepository(database, now: () => now);
    final notifications = _WidgetTestNotifications();
    final active = ValueNotifier(false);
    final controller = TestWorkflowController(
      repository: repository,
      notifications: notifications,
      photoStorage: const LocalPhotoStorage(),
      now: () => now,
    );
    await TankRepository(database).setParameterEnabled(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.caId,
      enabled: true,
    );
    final id = await controller.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.caId,
    );
    await controller.start((await repository.readDraftById(id))!);
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            testWorkflowNowProvider.overrideWithValue(() => now),
            testWorkflowControllerProvider.overrideWithValue(controller),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: active,
                builder: (_, enabled, _) => TickerMode(
                  enabled: enabled,
                  child: TestWorkflowPage(embedded: true, initialSessionId: id),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      now = now.add(const Duration(hours: 1));
      await tester.pump(const Duration(minutes: 10));
      expect(
        (await repository.readDraftById(id))!.stage,
        ActiveTestStage.timerRunning.name,
      );
      expect(notifications.cancelledIds, isEmpty);
      active.value = true;
      await _waitForStage(
        tester,
        repository: repository,
        sessionId: id,
        stage: ActiveTestStage.timerCompleted,
      );
      expect(notifications.cancelledIds, [testTimerNotificationId(id)]);
    } finally {
      await _disposeHarness(tester, notifications, database);
      active.dispose();
    }
  });

  testWidgets('后台跨过结束时间不写库，恢复及旧页面快照只完成一次', (tester) async {
    var now = DateTime.utc(2026, 9, 8, 10);
    final database = AppDatabase(NativeDatabase.memory());
    final repository = TestSessionRepository(database, now: () => now);
    final notifications = _WidgetTestNotifications();
    final controller = TestWorkflowController(
      repository: repository,
      notifications: notifications,
      photoStorage: const LocalPhotoStorage(),
      now: () => now,
    );
    await TankRepository(database).setParameterEnabled(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.caId,
      enabled: true,
    );
    final sessionId = await controller.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.caId,
    );
    await controller.start((await repository.readDraftById(sessionId))!);
    final running = (await repository.readDraftById(sessionId))!;
    await _auditTimerWrites(database);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            testWorkflowNowProvider.overrideWithValue(() => now),
            testWorkflowControllerProvider.overrideWithValue(controller),
            // Deliberately retain the rendered snapshot after the DB changes.
            activeTestSessionByIdProvider(
              sessionId,
            ).overrideWith((ref) => Stream.value(running)),
          ],
          child: MaterialApp(
            home: TestWorkflowPage(initialSessionId: sessionId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = running.timerEndsAt!.add(const Duration(seconds: 30));
      await tester.pump(const Duration(minutes: 6));
      expect(
        (await repository.readDraftById(sessionId))!.stage,
        ActiveTestStage.timerRunning.name,
      );
      expect(await _timerWriteCount(database), 0);
      expect(notifications.cancelledIds, isEmpty);
      expect(notifications.scheduledAtUtc, running.timerEndsAt!.toUtc());

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _waitForStage(
        tester,
        repository: repository,
        sessionId: sessionId,
        stage: ActiveTestStage.timerCompleted,
      );
      await tester.pumpAndSettle();
      now = now.add(const Duration(seconds: 20));
      await tester.pump(const Duration(seconds: 20));
      expect(await _timerWriteCount(database), 1);
      expect(notifications.cancelledIds, [testTimerNotificationId(sessionId)]);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 10));
      expect(await _timerWriteCount(database), 1);
      expect(notifications.cancelledIds, hasLength(1));
    } finally {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _disposeHarness(tester, notifications, database);
    }
  });

  testWidgets('后台创建页面和释放页面均不推进计时，保留草稿及系统通知', (tester) async {
    var now = DateTime.utc(2026, 9, 8, 10);
    final database = AppDatabase(NativeDatabase.memory());
    final repository = TestSessionRepository(database, now: () => now);
    final notifications = _WidgetTestNotifications();
    final controller = TestWorkflowController(
      repository: repository,
      notifications: notifications,
      photoStorage: const LocalPhotoStorage(),
      now: () => now,
    );
    await TankRepository(database).setParameterEnabled(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.caId,
      enabled: true,
    );
    final sessionId = await controller.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.caId,
    );
    await controller.start((await repository.readDraftById(sessionId))!);
    final running = (await repository.readDraftById(sessionId))!;
    await _auditTimerWrites(database);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            testWorkflowNowProvider.overrideWithValue(() => now),
            testWorkflowControllerProvider.overrideWithValue(controller),
          ],
          child: MaterialApp(
            home: TestWorkflowPage(initialSessionId: sessionId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      now = running.timerEndsAt!.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 6));
      expect(await _timerWriteCount(database), 0);

      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      now = now.add(const Duration(minutes: 10));
      await tester.pump(const Duration(minutes: 10));
      expect(await _timerWriteCount(database), 0);
      expect(
        (await repository.readDraftById(sessionId))!.stage,
        ActiveTestStage.timerRunning.name,
      );
      expect(notifications.cancelledIds, isEmpty);
      expect(notifications.scheduledAtUtc, running.timerEndsAt!.toUtc());
      expect(tester.takeException(), isNull);
    } finally {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _disposeHarness(tester, notifications, database);
    }
  });

  testWidgets('通知 sessionId 可恢复草稿并开始 UTC 计时', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final repository = TestSessionRepository(database);
    final sessionId = await repository.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
      reagentProfileId: AppDatabase.ealNo3ReagentId,
    );
    final notifications = _WidgetTestNotifications();
    final controller = TestWorkflowController(
      repository: repository,
      notifications: notifications,
      photoStorage: const LocalPhotoStorage(),
    );
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            testWorkflowControllerProvider.overrideWithValue(controller),
          ],
          child: MaterialApp(
            home: TestWorkflowPage(initialSessionId: sessionId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('当前记录到 我的海缸'), findsOneWidget);
      expect(find.text('NO3'), findsWidgets);
      expect(find.byKey(const Key('test-parameter-tabs')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('start-test-timer')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('start-test-timer')));
      final running = await _waitForStage(
        tester,
        repository: repository,
        sessionId: sessionId,
        stage: ActiveTestStage.timerRunning,
      );
      await _waitForNotification(tester, notifications);
      await tester.pumpAndSettle();

      expect(notifications.scheduledAtUtc?.isUtc, isTrue);
      expect(running.timerEndsAt, isNotNull);
      expect(
        running.timerEndsAt!.toUtc().millisecondsSinceEpoch ~/
            Duration.millisecondsPerSecond,
        notifications.scheduledAtUtc!.millisecondsSinceEpoch ~/
            Duration.millisecondsPerSecond,
      );
      expect(notifications.request?.payload.targetId, sessionId);
    } finally {
      await _disposeHarness(tester, notifications, database);
    }
  });

  testWidgets('NO3 跳过计时直接进入拍照并取消计时', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final repository = TestSessionRepository(database);
    final sessionId = await repository.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
    );
    final notifications = _WidgetTestNotifications();
    final controller = TestWorkflowController(
      repository: repository,
      notifications: notifications,
      photoStorage: const LocalPhotoStorage(),
    );
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            testWorkflowControllerProvider.overrideWithValue(controller),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) =>
                      TestWorkflowPage(initialSessionId: sessionId),
                ),
                GoRoute(
                  path: '/photo-capture',
                  builder: (context, _) => Scaffold(
                    body: FilledButton(
                      onPressed: () => context.pop(
                        PhotoEstimationDraft(
                          tankId: AppDatabase.defaultTankId,
                          parameterId: AppDatabase.no3Id,
                          parameterCode: 'NO3',
                          unit: 'mg/L',
                          createdAtUtc: DateTime.now(),
                          colorMatch: const ColorMatchResult(
                            low: 10,
                            high: 25,
                            interpolation: 18.6,
                            nearest: 25,
                            nearestReasons: [],
                            rangeReasons: [],
                            interpolationReasons: [],
                          ),
                        ),
                      ),
                      child: const Text('拍照路由'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('跳过计时，直接拍照'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('skip-test-timer')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('skip-test-timer')));
      await _waitForStage(
        tester,
        repository: repository,
        sessionId: sessionId,
        stage: ActiveTestStage.photoReady,
      );
      await tester.pumpAndSettle();

      expect(find.text('拍照路由'), findsOneWidget);
      await tester.tap(find.text('拍照路由'));
      await _waitForStage(
        tester,
        repository: repository,
        sessionId: sessionId,
        stage: ActiveTestStage.review,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('confirmed-minimum')))
            .controller!
            .text,
        '10',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('confirmed-maximum')))
            .controller!
            .text,
        '25',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('confirmed-interpolation')))
            .controller!
            .text,
        '18.6',
      );
    } finally {
      await _disposeHarness(tester, notifications, database);
    }
  });

  testWidgets('PO4 跳过计时直接进入拍照并取消计时', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final repository = TestSessionRepository(database);
    final sessionId = await repository.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.po4Id,
    );
    final notifications = _WidgetTestNotifications();
    final controller = TestWorkflowController(
      repository: repository,
      notifications: notifications,
      photoStorage: const LocalPhotoStorage(),
    );
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            testWorkflowControllerProvider.overrideWithValue(controller),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) =>
                      TestWorkflowPage(initialSessionId: sessionId),
                ),
                GoRoute(
                  path: '/photo-capture',
                  builder: (context, _) => Scaffold(
                    body: FilledButton(
                      onPressed: () => context.pop(
                        PhotoEstimationDraft(
                          tankId: AppDatabase.defaultTankId,
                          parameterId: AppDatabase.po4Id,
                          parameterCode: 'PO4',
                          unit: 'mg/L',
                          createdAtUtc: DateTime.now(),
                          colorMatch: const ColorMatchResult(
                            low: 10,
                            high: 25,
                            interpolation: 18.6,
                            nearest: 25,
                            nearestReasons: [],
                            rangeReasons: [],
                            interpolationReasons: [],
                          ),
                        ),
                      ),
                      child: const Text('拍照路由'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('跳过计时，直接拍照'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('skip-test-timer')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('skip-test-timer')));
      await _waitForStage(
        tester,
        repository: repository,
        sessionId: sessionId,
        stage: ActiveTestStage.photoReady,
      );
      await tester.pumpAndSettle();

      expect(find.text('拍照路由'), findsOneWidget);
      await tester.tap(find.text('拍照路由'));
      await _waitForStage(
        tester,
        repository: repository,
        sessionId: sessionId,
        stage: ActiveTestStage.review,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('confirmed-minimum')))
            .controller!
            .text,
        '10',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('confirmed-maximum')))
            .controller!
            .text,
        '25',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('confirmed-interpolation')))
            .controller!
            .text,
        '18.6',
      );
    } finally {
      await _disposeHarness(tester, notifications, database);
    }
  });

  testWidgets('恢复复核草稿时复用持久化确认时间', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final repository = TestSessionRepository(database);
    final sessionId = await repository.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
    );
    final confirmedAt = DateTime.utc(2001, 2, 3, 4, 5);
    await repository.updateReviewDraft(
      tankId: AppDatabase.defaultTankId,
      sessionId: sessionId,
      confirmedMinValue: 10,
      confirmedAt: confirmedAt,
    );
    final notifications = _WidgetTestNotifications();
    final controller = TestWorkflowController(
      repository: repository,
      notifications: notifications,
      photoStorage: const LocalPhotoStorage(),
    );
    final local = confirmedAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final expected =
        '确认时间：${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            testWorkflowControllerProvider.overrideWithValue(controller),
          ],
          child: MaterialApp(
            home: TestWorkflowPage(initialSessionId: sessionId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(expected), findsOneWidget);
      expect(find.byKey(const Key('confirmed-minimum')), findsOneWidget);
    } finally {
      await _disposeHarness(tester, notifications, database);
    }
  });
}

Future<ActiveTestSession> _waitForStage(
  WidgetTester tester, {
  required TestSessionRepository repository,
  required String sessionId,
  required ActiveTestStage stage,
}) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    final session = await repository.readDraftById(sessionId);
    if (session?.stage == stage.name) return session!;
  }
  fail('等待检测草稿进入 ${stage.name} 超时');
}

Future<void> _auditTimerWrites(AppDatabase database) async {
  await database.customStatement(
    'CREATE TEMP TABLE timer_write_audit (stage TEXT)',
  );
  await database.customStatement('''
    CREATE TEMP TRIGGER audit_timer_write AFTER UPDATE ON active_test_sessions
    BEGIN INSERT INTO timer_write_audit(stage) VALUES (NEW.stage); END
  ''');
}

Future<int> _timerWriteCount(AppDatabase database) async =>
    (await database
            .customSelect('SELECT COUNT(*) AS n FROM timer_write_audit')
            .getSingle())
        .read<int>('n');

Future<void> _waitForNotification(
  WidgetTester tester,
  _WidgetTestNotifications notifications,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (notifications.request != null) return;
    await tester.pump(const Duration(milliseconds: 20));
  }
  fail('等待检测计时通知调度超时');
}

Future<void> _disposeHarness(
  WidgetTester tester,
  _WidgetTestNotifications notifications,
  AppDatabase database,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await notifications.dispose();
  await database.close();
}

class _DelayedPhotoPreparationController extends Fake
    implements TestWorkflowController {
  _DelayedPhotoPreparationController(this.delegate);
  final TestWorkflowController delegate;
  final release = Completer<void>();
  bool started = false;
  @override
  Future<void> preparePhoto(ActiveTestSession session) async {
    started = true;
    await release.future;
    await delegate.preparePhoto(session);
  }
}

class _WidgetTestNotifications implements LocalNotificationService {
  final _taps = StreamController<LocalNotificationTap>.broadcast();
  LocalNotificationRequest? request;
  DateTime? scheduledAtUtc;
  final cancelledIds = <int>[];

  @override
  Stream<LocalNotificationTap> get taps => _taps.stream;

  @override
  Future<NotificationOperationResult> initialize() async =>
      const NotificationOperationResult.succeeded();

  @override
  Future<NotificationPermissionStatus> permissionStatus() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<NotificationPermissionStatus>
  requestExactSchedulingPermission() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<NotificationOperationResult> scheduleAtUtc(
    LocalNotificationRequest notification,
    DateTime scheduledAtUtc,
  ) async {
    request = notification;
    this.scheduledAtUtc = scheduledAtUtc;
    return const NotificationOperationResult.succeeded();
  }

  @override
  Future<NotificationOperationResult> scheduleAtDeviceLocalTime(
    LocalNotificationRequest request,
    DateTime deviceLocalDateTime,
  ) async => const NotificationOperationResult.succeeded();

  @override
  Future<NotificationOperationResult> scheduleDailyAtDeviceLocalTime(
    LocalNotificationRequest request,
    DateTime firstDeviceLocalDateTime,
  ) async => const NotificationOperationResult.succeeded();

  @override
  Future<NotificationOperationResult> cancel(int id) async {
    cancelledIds.add(id);
    return const NotificationOperationResult.succeeded();
  }

  Future<void> dispose() => _taps.close();
}
