import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/tanks/application/tank_providers.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';
import 'package:lanjiao_water_quality/features/test_records/application/test_record_providers.dart';
import 'package:lanjiao_water_quality/features/test_records/data/local_photo_storage.dart';
import 'package:lanjiao_water_quality/features/test_records/presentation/test_records_page.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late TankRepository tanks;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    tanks = TankRepository(database);
    await database.select(database.tanks).get();
  });

  tearDown(() => database.close());

  testWidgets('读取手动入口期间切走检测页，不在其他页弹出表单', (tester) async {
    // Read the seed synchronously through a query future. A Drift watch()
    // first emission needs the widget test's fake clock to advance, so waiting
    // for it before the first pump deadlocks this fixture.
    final enabled = (await tanks.readParameterStates(AppDatabase.defaultTankId))
        .where((state) => state.isEnabled)
        .map((state) => state.parameter)
        .toList();
    final delayed = Completer<List<WaterParameter>>();
    var reads = 0;
    final active = ValueNotifier(true);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        enabledParametersProvider(AppDatabase.defaultTankId).overrideWith(
          (ref) =>
              reads++ == 0 ? Stream.value(enabled) : delayed.future.asStream(),
        ),
      ],
    );
    // Keep the delayed stream active while the embedded page is hidden.
    // Consumer subscriptions pause with TickerMode, but the test must deliver
    // the awaited value so the late-navigation guard actually executes.
    final parameterSubscription = container.listen(
      enabledParametersProvider(AppDatabase.defaultTankId),
      (_, _) {},
    );
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: active,
                builder: (_, value, child) =>
                    TickerMode(enabled: value, child: child!),
                child: const TestRecordsPage(),
              ),
            ),
          ),
        ),
      );
      await _pumpUntilFound(tester, find.text('准备检测'));
      await tester.scrollUntilVisible(
        find.byKey(const Key('add-test-record')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      // Invalidate without pumping: the visible entry still exists, but its
      // async provider read now waits until after navigation has changed.
      container.invalidate(
        enabledParametersProvider(AppDatabase.defaultTankId),
      );
      await tester.tap(find.byKey(const Key('add-test-record')));
      active.value = false;
      await tester.pump();
      delayed.complete(enabled);
      await tester.pumpAndSettle();
      expect(
        container
            .read(enabledParametersProvider(AppDatabase.defaultTankId))
            .isLoading,
        isFalse,
      );
      expect(find.byKey(const Key('record-min-value')), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(await database.select(database.testRecords).get(), isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      if (!delayed.isCompleted) delayed.complete(enabled);
      // Finish pending provider reads before disposal, then flush the zero
      // duration timers Drift schedules when its final subscriptions close.
      await tester.pumpAndSettle();
      await _disposeWidgetTree(tester);
      parameterSubscription.close();
      container.dispose();
      await tester.pumpAndSettle();
      active.dispose();
    }
  });

  testWidgets('目标编辑打开后换缸不提交到原缸或新缸', (tester) async {
    final second = await tanks.createTank(name: '另一缸');
    try {
      await tester.pumpWidget(_app(database));
      await _pumpUntilFound(tester, find.text('NO3 · 硝酸盐'));
      await tester.tap(find.text('NO3 · 硝酸盐'));
      await _pumpUntilFound(tester, find.text('NO3 目标范围'));
      await tester.enterText(find.byKey(const Key('target-min-value')), '2');
      await tester.enterText(find.byKey(const Key('target-max-value')), '8');
      await tanks.switchTank(second);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-target-range')));
      await tester.pumpAndSettle();
      expect(
        await database.select(database.waterQualityTargets).get(),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await _disposeWidgetTree(tester);
    }
  });

  testWidgets('设置目标范围关闭弹窗时不触发控制器生命周期异常', (tester) async {
    try {
      await tester.pumpWidget(_app(database));
      await _pumpUntilFound(tester, find.text('NO3 · 硝酸盐'));

      await tester.tap(find.text('NO3 · 硝酸盐'));
      await _pumpUntilFound(tester, find.text('NO3 目标范围'));

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      final minimumController = tester
          .widget<TextField>(fields.at(0))
          .controller!;
      await tester.enterText(fields.at(0), '1');
      await tester.enterText(fields.at(1), '5');
      await tester.tap(find.widgetWithText(FilledButton, '保存'));

      // The dialog owns this controller. Closing it must not let a helper
      // function dispose the controller before the route lifecycle does.
      expect(find.byType(TextField, skipOffstage: false), findsNWidgets(2));
      void listener() {}
      expect(() => minimumController.addListener(listener), returnsNormally);
      minimumController.removeListener(listener);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final target = await database
          .select(database.waterQualityTargets)
          .getSingle();
      expect(target.tankId, AppDatabase.defaultTankId);
      expect(target.parameterId, AppDatabase.no3Id);
      expect(target.minValue, 1);
      expect(target.maxValue, 5);

      await _pumpUntilFound(tester, find.text('1–5 mg/L'));
      await tester.tap(find.text('NO3 · 硝酸盐'));
      await _pumpUntilFound(tester, find.text('NO3 目标范围'));
      await tester.enterText(find.byKey(const Key('target-min-value')), '2');
      await tester.enterText(find.byKey(const Key('target-max-value')), '8');
      await tester.tap(find.byKey(const Key('save-target-range')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final targets = await database.select(database.waterQualityTargets).get();
      expect(targets, hasLength(1));
      expect(targets.single.id, target.id);
      expect(targets.single.minValue, 2);
      expect(targets.single.maxValue, 8);
    } finally {
      await _disposeWidgetTree(tester);
    }
  });

  testWidgets('手动新增限定当前缸启用项，并在稍后继续后恢复草稿', (tester) async {
    try {
      await tanks.setParameterEnabled(
        tankId: AppDatabase.defaultTankId,
        parameterId: AppDatabase.po4Id,
        enabled: false,
      );
      await tester.pumpWidget(_app(database, detection: true));
      await _pumpUntilFound(tester, find.byKey(const Key('start-test-timer')));
      await _scrollToAndTap(tester, find.byKey(const Key('add-test-record')));
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('record-fixed-current-tank')),
      );

      expect(find.text('我的海缸'), findsWidgets);
      expect(find.textContaining('NO3 · mg/L'), findsOneWidget);
      expect(find.textContaining('PO4 · mg/L'), findsNothing);

      await tester.tap(find.byKey(const Key('record-reagent-no3')));
      await tester.pumpAndSettle();
      expect(find.text('益尔').hitTestable(), findsOneWidget);
      await tester.tap(find.text('益尔').hitTestable());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('record-min-value')), '12.5');
      await tester.enterText(find.byKey(const Key('record-notes')), '保留的草稿');
      await tester.ensureVisible(find.byKey(const Key('record-keep-draft')));
      await tester.tap(find.byKey(const Key('record-keep-draft')));
      await tester.pumpAndSettle();

      // Closing the dialog resumes the embedded providers; wait for their
      // data before finding an entry that ListView may build only on scroll.
      await _pumpUntilFound(tester, find.byKey(const Key('start-test-timer')));
      await _scrollToAndTap(tester, find.byKey(const Key('add-test-record')));
      await _pumpUntilFound(tester, find.byKey(const Key('record-min-value')));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('record-min-value')))
            .controller!
            .text,
        '12.5',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('record-notes')))
            .controller!
            .text,
        '保留的草稿',
      );

      await tester.ensureVisible(find.byKey(const Key('record-discard-draft')));
      await tester.tap(find.byKey(const Key('record-discard-draft')));
      await _pumpUntilFound(tester, find.text('放弃这个草稿？'));
      await tester.tap(find.byKey(const Key('confirm-放弃草稿')));
      await tester.pumpAndSettle();

      // Closing the dialog resumes the embedded providers; wait for their
      // data before finding an entry that ListView may build only on scroll.
      await _pumpUntilFound(tester, find.byKey(const Key('start-test-timer')));
      await _scrollToAndTap(tester, find.byKey(const Key('add-test-record')));
      await _pumpUntilFound(tester, find.byKey(const Key('record-min-value')));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('record-min-value')))
            .controller!
            .text,
        isEmpty,
      );
    } finally {
      await _disposeWidgetTree(tester);
    }
  });

  testWidgets('历史详情分离算法值，编辑可迁移到有关联但已停用的参数', (tester) async {
    try {
      final secondTankId = await tanks.createTank(name: '检疫缸');
      await tanks.setParameterEnabled(
        tankId: secondTankId,
        parameterId: AppDatabase.no3Id,
        enabled: false,
      );
      final capturedAt = DateTime.utc(2026, 8, 11, 8);
      final confirmedAt = DateTime.utc(2026, 8, 11, 8, 10);
      await _insertRecord(
        database,
        id: 'rich-record',
        capturedAt: capturedAt,
        confirmedAt: confirmedAt,
        estimatedMin: 10,
        estimatedMax: 25,
        confirmedMin: 15,
        wasManuallyEdited: true,
        note: '原备注',
      );

      await tester.pumpWidget(_app(database));
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('record-rich-record')),
      );
      expect(find.textContaining('已手动修改'), findsNothing);

      await _scrollToAndTap(
        tester,
        find.byKey(const Key('record-rich-record')),
      );
      await _pumpUntilFound(tester, find.text('算法原始结果（只读）'));
      expect(find.text('最终确认结果'), findsOneWidget);
      expect(find.text('算法原始估值'), findsNothing);
      await _scrollToAndTap(tester, find.text('算法原始结果（只读）'));
      await tester.pumpAndSettle();
      expect(find.text('算法原始估值'), findsOneWidget);
      expect(find.text('10–25 mg/L'), findsOneWidget);
      expect(find.text('原始拍摄时间'), findsOneWidget);
      expect(find.text('最后修改时间'), findsOneWidget);

      final editButton = find
          .byKey(const Key('edit-test-record'))
          .hitTestable();
      expect(editButton, findsOneWidget);
      await tester.tap(editButton);
      await _pumpUntilFound(tester, find.text('算法与拍摄原始信息（只读）'));

      await tester.tap(
        find.byKey(Key('record-tank-${AppDatabase.defaultTankId}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('检疫缸').last);
      await _pumpUntilFound(tester, find.textContaining('已停用，历史可编辑'));

      await tester.enterText(find.byKey(const Key('record-notes')), '迁移后的备注');
      await tester.ensureVisible(find.byKey(const Key('save-test-record')));
      await tester.tap(find.byKey(const Key('save-test-record')));
      await tester.pumpAndSettle();

      final edited = await (database.select(
        database.testRecords,
      )..where((row) => row.id.equals('rich-record'))).getSingle();
      expect(edited.tankId, secondTankId);
      expect(edited.parameterId, AppDatabase.no3Id);
      expect(edited.notes, '迁移后的备注');
      expect(edited.wasManuallyEdited, isTrue);
      expect(edited.capturedAt?.isAtSameMomentAs(capturedAt), isTrue);
      expect(edited.estimatedMinValue, 10);
      expect(edited.estimatedMaxValue, 25);
      expect(edited.confirmedMinValue, 15);
    } finally {
      await _disposeWidgetTree(tester);
    }
  });

  testWidgets('清照片和删记录均先提交数据库，再提示照片文件失败', (tester) async {
    try {
      final now = DateTime.utc(2026, 8, 11, 9);
      await _insertRecord(
        database,
        id: 'clear-record',
        capturedAt: now,
        confirmedAt: now,
        estimatedMin: 5,
        confirmedMin: 5,
        photoPath: 'test_photos/clear.jpg',
      );
      await _insertRecord(
        database,
        id: 'delete-record',
        capturedAt: now.subtract(const Duration(minutes: 1)),
        confirmedAt: now.subtract(const Duration(minutes: 1)),
        estimatedMin: 10,
        confirmedMin: 10,
        photoPath: 'test_photos/delete.jpg',
      );
      final storage = _RecordingPhotoStorage(database);

      await tester.pumpWidget(_app(database, photoStorage: storage));
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('record-clear-record')),
      );

      await _scrollToAndTap(
        tester,
        find.byKey(const Key('record-clear-record')),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('clear-record-photo')),
      );
      await tester.tap(find.byKey(const Key('clear-record-photo')));
      await _pumpUntilFound(tester, find.text('删除旧版本留档照片？'));
      await tester.tap(find.byKey(const Key('confirm-删除照片')));
      await _pumpUntilFound(tester, find.textContaining('照片文件删除失败'));

      final retained = await (database.select(
        database.testRecords,
      )..where((row) => row.id.equals('clear-record'))).getSingle();
      expect(retained.confirmedMinValue, 5);
      expect(retained.photoPath, isNull);
      expect(storage.databaseWasUpdated['test_photos/clear.jpg'], isTrue);

      await _scrollToAndTap(
        tester,
        find.byKey(const Key('record-delete-record')),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('delete-test-record')),
      );
      await tester.tap(find.byKey(const Key('delete-test-record')));
      await _pumpUntilFound(tester, find.text('永久删除这条记录？'));
      await tester.tap(find.byKey(const Key('confirm-删除记录')));
      await _pumpUntilFound(tester, find.textContaining('照片文件清理失败'));

      final deleted = await (database.select(
        database.testRecords,
      )..where((row) => row.id.equals('delete-record'))).getSingleOrNull();
      expect(deleted, isNull);
      expect(storage.databaseWasUpdated['test_photos/delete.jpg'], isTrue);
    } finally {
      await _disposeWidgetTree(tester);
    }
  });
}

Future<void> _disposeWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

Future<void> _scrollToAndTap(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable);
  expect(scrollable, findsWidgets);
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: scrollable.first,
    maxScrolls: 20,
  );
  expect(finder, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
  final entryTile = find.descendant(
    of: finder,
    matching: find.byType(ListTile),
  );
  final hitTestable = (entryTile.evaluate().isEmpty ? finder : entryTile)
      .hitTestable();
  expect(hitTestable, findsOneWidget);
  await tester.tap(hitTestable);
  await tester.pump();
}

Widget _app(
  AppDatabase database, {
  LocalPhotoStorage photoStorage = const LocalPhotoStorage(),
  bool detection = false,
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      localPhotoStorageProvider.overrideWithValue(photoStorage),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: detection ? const TestRecordsPage() : const _EditorEntries(),
      ),
    ),
  );
}

final _editorRecordsProvider = StreamProvider.family(
  (Ref ref, String tankId) =>
      ref.watch(testRecordRepositoryProvider).watchForTank(tankId),
);

class _EditorEntries extends ConsumerWidget {
  const _EditorEntries();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tank = ref.watch(currentTankProvider).value;
    if (tank == null) return const SizedBox.shrink();
    final states = ref.watch(parameterStatesProvider(tank.id)).value ?? [];
    final targets = ref.watch(waterQualityTargetsProvider(tank.id)).value ?? [];
    final records = ref.watch(_editorRecordsProvider(tank.id)).value ?? [];
    return ListView(
      children: [
        for (final state in states.where((state) => state.isEnabled))
          Builder(
            builder: (context) {
              final target = targets
                  .where((target) => target.parameterId == state.parameter.id)
                  .firstOrNull;
              String n(double? value) => value == null
                  ? '未设置'
                  : value.toString().replaceFirst(RegExp(r'\.0$'), '');
              return ListTile(
                title: Text(
                  '${state.parameter.code} · ${state.parameter.displayName}',
                ),
                subtitle: Text(
                  '${n(target?.minValue)}–${n(target?.maxValue)} ${state.parameter.unit}',
                ),
                onTap: () => showWaterQualityTargetEditor(
                  context,
                  ref,
                  tankId: tank.id,
                  parameter: state.parameter,
                  target: target,
                ),
              );
            },
          ),
        for (final record in records)
          TextButton(
            key: Key('record-${record.id}'),
            onPressed: () => showScopedTestRecordDetails(
              context: context,
              ref: ref,
              record: record,
              tank: tank,
              parameter: states
                  .firstWhere(
                    (state) => state.parameter.id == record.parameterId,
                  )
                  .parameter,
            ),
            child: Text('${record.confirmedMinValue} ${record.unit}'),
          ),
      ],
    );
  }
}

Future<void> _insertRecord(
  AppDatabase database, {
  required String id,
  required DateTime confirmedAt,
  required double confirmedMin,
  DateTime? capturedAt,
  double? estimatedMin,
  double? estimatedMax,
  String? note,
  String? photoPath,
  bool wasManuallyEdited = false,
}) async {
  await database
      .into(database.testRecords)
      .insert(
        TestRecordsCompanion.insert(
          id: id,
          tankId: AppDatabase.defaultTankId,
          parameterId: AppDatabase.no3Id,
          reagentProfileId: const Value(AppDatabase.ealNo3ReagentId),
          capturedAt: Value(capturedAt),
          estimatedMinValue: Value(estimatedMin),
          estimatedMaxValue: Value(estimatedMax),
          estimationMethod: const Value('reference-color-distance'),
          estimationVersion: const Value('unvalidated-v0'),
          qualityScore: const Value(0.7),
          confidence: const Value('medium'),
          confirmedMinValue: confirmedMin,
          unit: 'mg/L',
          measuredAt: confirmedAt,
          confirmedAt: Value(confirmedAt),
          notes: Value(note),
          photoPath: Value(photoPath),
          wasManuallyEdited: Value(wasManuallyEdited),
          createdAt: confirmedAt,
          updatedAt: confirmedAt,
        ),
      );
}

class _RecordingPhotoStorage extends LocalPhotoStorage {
  _RecordingPhotoStorage(this.database);

  final AppDatabase database;
  final Map<String, bool> databaseWasUpdated = {};

  @override
  Future<bool> deletePrivatePhoto(String? storedPath) async {
    if (storedPath == null) return false;
    final id = storedPath.contains('clear') ? 'clear-record' : 'delete-record';
    final row = await (database.select(
      database.testRecords,
    )..where((record) => record.id.equals(id))).getSingleOrNull();
    databaseWasUpdated[storedPath] =
        row == null || (id == 'clear-record' && row.photoPath == null);
    return false;
  }
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 350; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  final visibleText = find
      .byType(Text)
      .evaluate()
      .map((element) => (element.widget as Text).data)
      .whereType<String>()
      .toList();
  fail('等待组件超时：$finder\n当前文本：$visibleText');
}
