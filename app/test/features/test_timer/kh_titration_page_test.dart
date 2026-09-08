import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanjiao_water_quality/core/notifications/local_notification.dart';
import 'package:lanjiao_water_quality/core/notifications/local_notification_service.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/tanks/application/tank_providers.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';
import 'package:lanjiao_water_quality/features/test_records/data/local_photo_storage.dart';
import 'package:lanjiao_water_quality/features/test_timer/application/test_session_providers.dart';
import 'package:lanjiao_water_quality/features/test_timer/application/test_workflow_controller.dart';
import 'package:lanjiao_water_quality/features/test_timer/data/test_session_repository.dart';
import 'package:lanjiao_water_quality/features/test_timer/domain/kh_titration.dart';
import 'package:lanjiao_water_quality/features/test_timer/presentation/test_workflow_page.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  tester.testTextInput.hide();
  await tester.pump();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  testWidgets(
    'KH entry cancels only current tank timers, calculates without a timer and confirms one raw-backed record',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final tanks = TankRepository(db), sessions = TestSessionRepository(db);
      final notifications = _Notifications();
      final controller = TestWorkflowController(
        repository: sessions,
        notifications: notifications,
        photoStorage: const LocalPhotoStorage(),
      );
      await tanks.setParameterEnabled(
        tankId: AppDatabase.defaultTankId,
        parameterId: AppDatabase.khId,
        enabled: true,
      );
      final otherTank = await tanks.createTank(name: '第二缸');
      final current = await controller.createDraft(
        tankId: AppDatabase.defaultTankId,
        parameterId: AppDatabase.no3Id,
      );
      final other = await controller.createDraft(
        tankId: otherTank,
        parameterId: AppDatabase.no3Id,
      );
      await controller.start((await sessions.readDraftById(current))!);
      await controller.start((await sessions.readDraftById(other))!);
      final router = _router();
      try {
        await tester.pumpWidget(_app(db, controller, router));
        await settle(tester);
        expect(find.text('KH 滴定检测'), findsOneWidget);
        expect(find.text('显色计时'), findsNothing);
        expect(find.byKey(const Key('test-timer-countdown')), findsNothing);
        expect(
          (await sessions.readDraftById(current))!.stage,
          ActiveTestStage.preparation.name,
        );
        expect(
          (await sessions.readDraftById(other))!.stage,
          ActiveTestStage.timerRunning.name,
        );
        expect(
          notifications.cancelled,
          contains(testTimerNotificationId(current)),
        );
        expect(
          notifications.cancelled,
          isNot(contains(testTimerNotificationId(other))),
        );
        await tester.enterText(find.byKey(const Key('kh-initial')), '.8');
        await tester.enterText(find.byKey(const Key('kh-remaining')), '.29');
        await tap(tester, find.byKey(const Key('calculate-kh-titration')));
        expect(find.text('7.9 dKH'), findsOneWidget);
        expect(await db.select(db.testRecords).get(), isEmpty);
        await tap(tester, find.byKey(const Key('save-kh-titration')));
        expect(find.text('已回检测'), findsOneWidget);
        final record = await db.select(db.testRecords).getSingle();
        expect(record.parameterId, AppDatabase.khId);
        expect(record.confirmedMinValue, 7.9);
        expect(record.confirmedMaxValue, isNull);
        final metadata = validateKhTitrationJson(record.khTitrationJson!);
        expect(metadata.initialMl, .8);
        expect(metadata.remainingMl, .29);
        expect(metadata.dkh, closeTo(7.85, 1e-12));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await settle(tester);
        router.dispose();
        await db.close();
      }
    },
  );
  testWidgets(
    'KH validation, edited input, parameter/tank switch and cancel never save; manual entry remains available',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final tanks = TankRepository(db), sessions = TestSessionRepository(db);
      await tanks.setParameterEnabled(
        tankId: AppDatabase.defaultTankId,
        parameterId: AppDatabase.khId,
        enabled: true,
      );
      final other = await tanks.createTank(name: '第二缸');
      await tanks.setParameterEnabled(
        tankId: other,
        parameterId: AppDatabase.khId,
        enabled: true,
      );
      final controller = TestWorkflowController(
        repository: sessions,
        notifications: _Notifications(),
        photoStorage: const LocalPhotoStorage(),
      );
      final router = _router();
      try {
        await tester.pumpWidget(_app(db, controller, router));
        await settle(tester);
        for (final remaining in ['', '1.1', '1']) {
          await tester.enterText(
            find.byKey(const Key('kh-remaining')),
            remaining,
          );
          await tap(tester, find.byKey(const Key('calculate-kh-titration')));
          expect(find.byKey(const Key('kh-error')), findsOneWidget);
          expect(find.byKey(const Key('kh-result')), findsNothing);
        }
        await tester.enterText(find.byKey(const Key('kh-remaining')), '.98');
        await tap(tester, find.byKey(const Key('calculate-kh-titration')));
        expect(find.text('0.0 dKH'), findsOneWidget);
        await tester.enterText(find.byKey(const Key('kh-remaining')), '.48');
        await tester.pump();
        expect(find.byKey(const Key('kh-result')), findsNothing);
        await tap(tester, find.byKey(const Key('calculate-kh-titration')));
        expect(find.text('8.0 dKH'), findsOneWidget);
        await tap(
          tester,
          find.byKey(const Key('workflow-parameter-${AppDatabase.khId}')),
        );
        await tap(tester, find.text('NO3 · 硝酸盐').last);
        expect(find.byKey(const Key('kh-result')), findsNothing);
        expect(find.byKey(const Key('create-test-draft')), findsOneWidget);
        await tap(
          tester,
          find.byKey(const Key('workflow-parameter-${AppDatabase.no3Id}')),
        );
        await tap(tester, find.text('KH · 碳酸盐硬度').last);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('kh-remaining')))
              .controller!
              .text,
          '',
        );
        await tap(
          tester,
          find.byKey(const Key('workflow-tank-${AppDatabase.defaultTankId}')),
        );
        await tap(tester, find.text('第二缸').last);
        expect(find.byKey(const Key('kh-result')), findsNothing);
        await tap(tester, find.text('本次不记录'));
        expect(await db.select(db.testRecords).get(), isEmpty);
        expect(await db.select(db.activeTestSessions).get(), isEmpty);
        router.go('/test-flow');
        await settle(tester);
        await tap(tester, find.byKey(const Key('manual-kh-entry')));
        expect(find.byKey(const Key('test-timer-countdown')), findsNothing);
        expect(find.byKey(const Key('save-test-workflow')), findsOneWidget);
        expect(
          (await db.select(db.activeTestSessions).getSingle()).stage,
          ActiveTestStage.review.name,
        );
        expect(await db.select(db.testRecords).get(), isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await settle(tester);
        router.dispose();
        await db.close();
      }
    },
  );
}

GoRouter _router() => GoRouter(
  initialLocation: '/test-flow',
  routes: [
    GoRoute(
      path: '/test-flow',
      builder: (_, _) =>
          const TestWorkflowPage(initialParameterId: AppDatabase.khId),
    ),
    GoRoute(
      path: '/test',
      builder: (_, _) => const Scaffold(body: Text('已回检测')),
    ),
  ],
);
Widget _app(
  AppDatabase db,
  TestWorkflowController controller,
  GoRouter router,
) => ProviderScope(
  overrides: [
    appDatabaseProvider.overrideWithValue(db),
    testWorkflowControllerProvider.overrideWithValue(controller),
  ],
  child: MaterialApp.router(routerConfig: router),
);

class _Notifications implements LocalNotificationService {
  final cancelled = <int>[];
  @override
  Stream<LocalNotificationTap> get taps => const Stream.empty();
  @override
  Future<NotificationOperationResult> initialize() async =>
      const NotificationOperationResult.succeeded();
  @override
  Future<NotificationOperationResult> cancel(int id) async {
    cancelled.add(id);
    return const NotificationOperationResult.succeeded();
  }

  @override
  Future<NotificationOperationResult> scheduleAtUtc(
    LocalNotificationRequest request,
    DateTime when,
  ) async => const NotificationOperationResult.succeeded();
  @override
  Future<NotificationOperationResult> scheduleAtDeviceLocalTime(
    LocalNotificationRequest request,
    DateTime when,
  ) async => const NotificationOperationResult.succeeded();
  @override
  Future<NotificationOperationResult> scheduleDailyAtDeviceLocalTime(
    LocalNotificationRequest request,
    DateTime when,
  ) async => const NotificationOperationResult.succeeded();
  @override
  Future<NotificationPermissionStatus> permissionStatus() async =>
      NotificationPermissionStatus.granted;
  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.granted;
  @override
  Future<NotificationPermissionStatus>
  requestExactSchedulingPermission() async =>
      NotificationPermissionStatus.granted;
}
