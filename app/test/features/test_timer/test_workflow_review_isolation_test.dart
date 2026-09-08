import 'dart:async';

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
import 'package:lanjiao_water_quality/features/test_timer/presentation/test_workflow_page.dart';

void main() {
  for (final saveRecord in [false, true]) {
    testWidgets(
      saveRecord
          ? '确认保存等待队列期间切缸，记录保留原草稿的全部确认输入'
          : '延迟保存期间同页切缸，两缸草稿各自保留数值、备注和日期',
      (tester) async {
        final database = AppDatabase(NativeDatabase.memory());
        final repository = TestSessionRepository(database);
        final tanks = TankRepository(database);
        final tankB = await tanks.createTank(name: '海缸 B');
        await tanks.switchTank(AppDatabase.defaultTankId);
        final sessionA = await repository.createDraft(
          tankId: AppDatabase.defaultTankId,
          parameterId: AppDatabase.no3Id,
        );
        final sessionB = await repository.createDraft(
          tankId: tankB,
          parameterId: AppDatabase.no3Id,
        );
        final dateA = DateTime.utc(2001, 2, 3, 4, 5);
        final dateB = DateTime.utc(2002, 3, 4, 5, 6);
        await repository.updateReviewDraft(
          tankId: AppDatabase.defaultTankId,
          sessionId: sessionA,
          confirmedMinValue: 10,
          confirmedMaxValue: 18,
          confirmedInterpolation: 15,
          confirmedAt: dateA,
          notes: 'A 原备注',
        );
        await repository.updateReviewDraft(
          tankId: tankB,
          sessionId: sessionB,
          confirmedMinValue: 20,
          confirmedAt: dateB,
          notes: 'B 原备注',
        );
        final delayed = _DelayedReviewController(
          TestWorkflowController(
            repository: repository,
            notifications: _ReviewTestNotifications(),
            photoStorage: const LocalPhotoStorage(),
          ),
        );
        final pageKey = GlobalKey();
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Column(
                children: [
                  Material(
                    child: Row(
                      children: [
                        TextButton(
                          key: const Key('switch-tank-a'),
                          onPressed: () =>
                              tanks.switchTank(AppDatabase.defaultTankId),
                          child: const Text('切换到 A'),
                        ),
                        TextButton(
                          key: const Key('switch-tank-b'),
                          onPressed: () => tanks.switchTank(tankB),
                          child: const Text('切换到 B'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TestWorkflowPage(
                      key: pageKey,
                      initialParameterId: AppDatabase.no3Id,
                    ),
                  ),
                ],
              ),
            ),
            GoRoute(
              path: '/test',
              builder: (_, _) => const Scaffold(body: Text('记录列表')),
            ),
          ],
        );
        final minimum = find.byKey(const Key('confirmed-minimum'));
        final notes = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == '备注（可选）',
        );
        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appDatabaseProvider.overrideWithValue(database),
                testSessionRepositoryProvider.overrideWithValue(repository),
                testWorkflowControllerProvider.overrideWithValue(delayed),
              ],
              child: MaterialApp.router(routerConfig: router),
            ),
          );
          await tester.pumpAndSettle();
          final originalPageState = pageKey.currentState;
          expect(originalPageState, isNotNull);
          expect(_fieldText(tester, minimum), '10');

          await _enterText(tester, minimum, '11');
          expect(delayed.calls, 1);
          await _enterText(tester, minimum, '12');
          await _enterText(
            tester,
            find.byKey(const Key('confirmed-interpolation')),
            '16',
          );
          await _enterText(tester, notes, 'A 修改备注');
          expect(delayed.calls, 1, reason: '首次持久化仍被阻塞，后续真实输入已排队');
          if (saveRecord) {
            final save = find.byKey(const Key('save-test-workflow'));
            await tester.ensureVisible(save);
            await tester.tap(save);
            await tester.pump();
            expect(delayed.savedRecords, 0);
          }

          // Switch through the real current-tank preference/provider while the
          // same page State and its pending persistence queue remain alive.
          await tester.tap(find.byKey(const Key('switch-tank-b')));
          await tester.pumpAndSettle();
          expect(pageKey.currentState, same(originalPageState));
          expect(_fieldText(tester, minimum), '20');
          expect(find.byKey(const Key('confirmed-maximum')), findsNothing);
          expect(_fieldText(tester, notes), 'B 原备注');
          expect(
            find.textContaining(_confirmationLabel(dateB)),
            findsOneWidget,
          );
          if (!saveRecord) {
            await _enterText(tester, minimum, '21');
            await _enterText(tester, notes, 'B 修改备注');
          }

          delayed.release.complete();
          final expectedWrites = saveRecord ? 5 : 6;
          for (var attempt = 0; attempt < 100; attempt++) {
            if (delayed.finished == expectedWrites &&
                (!saveRecord || delayed.savedRecords == 1)) {
              break;
            }
            await tester.pump(const Duration(milliseconds: 20));
          }
          expect(delayed.finished, expectedWrites);
          await tester.pumpAndSettle();

          final a = await tester.runAsync(
            () => repository.readDraftById(sessionA),
          );
          final b = await tester.runAsync(
            () => repository.readDraftById(sessionB),
          );
          final records = (await tester.runAsync(
            () => database.select(database.testRecords).get(),
          ))!;
          expect(b, isNotNull);
          expect(b!.tankId, tankB);
          expect(b.parameterId, AppDatabase.no3Id);
          expect(b.draftConfirmedMinValue, saveRecord ? 20 : 21);
          expect(b.draftConfirmedMaxValue, isNull);
          expect(b.draftConfirmedInterpolation, isNull);
          expect(b.draftNotes, saveRecord ? 'B 原备注' : 'B 修改备注');
          expect(b.draftConfirmedAt?.toUtc(), dateB);
          if (saveRecord) {
            expect(delayed.savedRecords, 1);
            expect(a, isNull);
            expect(records, hasLength(1));
            final record = records.single;
            expect(record.tankId, AppDatabase.defaultTankId);
            expect(record.parameterId, AppDatabase.no3Id);
            expect(record.confirmedMinValue, 12);
            expect(record.confirmedMaxValue, 18);
            expect(record.confirmedInterpolation, 16);
            expect(record.notes, 'A 修改备注');
            expect(record.confirmedAt?.toUtc(), dateA);
            expect(record.measuredAt.toUtc(), dateA);
            expect(find.text('记录列表'), findsOneWidget);
          } else {
            expect(records, isEmpty);
            expect(a, isNotNull);
            expect(a!.tankId, AppDatabase.defaultTankId);
            expect(a.parameterId, AppDatabase.no3Id);
            expect(a.draftConfirmedMinValue, 12);
            expect(a.draftConfirmedMaxValue, 18);
            expect(a.draftConfirmedInterpolation, 16);
            expect(a.draftNotes, 'A 修改备注');
            expect(a.draftConfirmedAt?.toUtc(), dateA);
            await tester.tap(find.byKey(const Key('switch-tank-a')));
            await tester.pumpAndSettle();
            await _waitForReviewText(tester, minimum, '12');
            expect(_fieldText(tester, minimum), '12');
            expect(_fieldText(tester, notes), 'A 修改备注');
            expect(
              find.textContaining(_confirmationLabel(dateA)),
              findsOneWidget,
            );

            // A resumed draft may still receive an older autosave. Make the
            // first new edit invalid, so no new database write can mask a
            // mistaken re-hydration of the user's in-progress text.
            final releaseOldWrite = Completer<void>();
            final oldWrite = releaseOldWrite.future.then((_) {
              return delayed.real.persistReview(
                session: a,
                confirmedMinValue: 11,
                confirmedMaxValue: 18,
                confirmedInterpolation: 15,
                confirmedAt: dateA,
                notes: 'A 较早的自动保存',
              );
            });
            try {
              await _enterText(tester, minimum, '50');
              releaseOldWrite.complete();
              await tester.runAsync(() => oldWrite);
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 30)),
              );
              await tester.pumpAndSettle();
              expect(
                (await tester.runAsync(
                  () => repository.readDraftById(sessionA),
                ))!.draftConfirmedMinValue,
                11,
                reason: '较早写入已经真实到达 SQLite，而非仍被测试阻塞',
              );
              expect(_fieldText(tester, minimum), '50');
              expect(_fieldText(tester, notes), 'A 修改备注');
              expect(
                find.textContaining(_confirmationLabel(dateA)),
                findsOneWidget,
              );
            } finally {
              if (!releaseOldWrite.isCompleted) releaseOldWrite.complete();
              await tester.runAsync(() => oldWrite);
            }
          }
          expect(tester.takeException(), isNull);
        } finally {
          if (!delayed.release.isCompleted) delayed.release.complete();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          router.dispose();
          await database.close();
        }
      },
    );
  }
}

Future<void> _enterText(WidgetTester tester, Finder field, String text) async {
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> _waitForReviewText(
  WidgetTester tester,
  Finder field,
  String expected,
) async {
  // SQLite watches can resume after the frame with a cached value. Allow a
  // bounded real event turn, without invalidating providers or hiding stale UI.
  for (var attempt = 0; attempt < 20; attempt++) {
    if (field.evaluate().isNotEmpty && _fieldText(tester, field) == expected) {
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
}

String _fieldText(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).controller!.text;

String _confirmationLabel(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '确认时间：${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

class _DelayedReviewController implements TestWorkflowController {
  _DelayedReviewController(this.real);

  final TestWorkflowController real;
  final release = Completer<void>();
  int calls = 0;
  int finished = 0;
  int savedRecords = 0;

  @override
  Future<void> persistReview({
    required ActiveTestSession session,
    double? confirmedMinValue,
    double? confirmedMaxValue,
    double? confirmedInterpolation,
    DateTime? confirmedAt,
    String? notes,
  }) async {
    calls++;
    if (calls == 1) await release.future;
    await real.persistReview(
      session: session,
      confirmedMinValue: confirmedMinValue,
      confirmedMaxValue: confirmedMaxValue,
      confirmedInterpolation: confirmedInterpolation,
      confirmedAt: confirmedAt,
      notes: notes,
    );
    finished++;
  }

  @override
  Future<String> save({
    required ActiveTestSession session,
    required double confirmedMinValue,
    double? confirmedMaxValue,
    double? confirmedInterpolation,
    DateTime? confirmedAt,
    String? notes,
  }) async {
    final id = await real.save(
      session: session,
      confirmedMinValue: confirmedMinValue,
      confirmedMaxValue: confirmedMaxValue,
      confirmedInterpolation: confirmedInterpolation,
      confirmedAt: confirmedAt,
      notes: notes,
    );
    savedRecords++;
    return id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _ReviewTestNotifications implements LocalNotificationService {
  @override
  Future<NotificationOperationResult> initialize() async =>
      const NotificationOperationResult.succeeded();

  @override
  Future<NotificationOperationResult> cancel(int id) async =>
      const NotificationOperationResult.succeeded();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
