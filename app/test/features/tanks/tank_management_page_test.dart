import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/core/notifications/local_notification.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/aquarium/presentation/fish_manager_sheet.dart';
import 'package:lanjiao_water_quality/features/home/presentation/home_page.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_clock.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_notification_providers.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_providers.dart';
import 'package:lanjiao_water_quality/features/settings/presentation/settings_entry_dialog.dart';
import 'package:lanjiao_water_quality/features/settings/presentation/settings_page.dart';
import 'package:lanjiao_water_quality/features/tanks/application/tank_providers.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';

void main() {
  late AppDatabase database;
  late TankRepository repository;
  late ProviderContainer container;
  late DateTime today;
  late DateTime now;

  setUp(() async {
    today = DateUtils.dateOnly(DateTime.now());
    now = DateTime(today.year, today.month, today.day, 12);
    database = AppDatabase(NativeDatabase.memory());
    repository = TankRepository(database);
    await database.select(database.tanks).get();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        tankRepositoryProvider.overrideWithValue(repository),
        maintenanceClockProvider.overrideWith((ref) {
          final clock = MaintenanceClock(now: () => now);
          ref.onDispose(clock.dispose);
          return clock.stream;
        }),
        notificationsEnabledProvider.overrideWithValue(false),
        notificationPermissionStatusProvider.overrideWith(
          (ref) async => NotificationPermissionStatus.denied,
        ),
        maintenanceNotificationSyncStateProvider.overrideWith(
          (ref) => const Stream.empty(),
        ),
      ],
    );
  });

  tearDown(() async {
    await database.close();
  });

  void testManagement(
    String description,
    Future<void> Function(WidgetTester tester) scenario,
  ) {
    testWidgets(description, (tester) async {
      try {
        await scenario(tester);
      } finally {
        // This container owns the real clock. Dispose it inside testWidgets,
        // before the binding checks for pending timers, including on failure.
        try {
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          container.dispose();
        }
        await tester.pumpAndSettle();
      }
    });
  }

  Future<void> open(WidgetTester tester, {bool home = false}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: home ? const Scaffold(body: HomePage()) : const SettingsPage(),
        ),
      ),
    );
    await _flush(tester);
  }

  Future<List<Tank>> readTanks(WidgetTester tester) async =>
      (await tester.runAsync(() => database.select(database.tanks).get()))!;

  Future<String?> readCurrentTankId(WidgetTester tester) async =>
      (await tester.runAsync(
        () => database.select(database.appPreferences).getSingle(),
      ))!.currentTankId;

  testManagement('添加海缸默认不补造日期或水体积，保存后切换到新缸', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('添加海缸'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('tank-start-date')),
        matching: find.text('选择日期'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('clear-tank-start-date')), findsNothing);
    expect(_text(tester, _volume), isEmpty);
    await tester.enterText(_name, '无日期海缸');
    await _dialogAction(tester, '保存');
    expect(find.byType(SettingsEntryDialog), findsNothing);
    final saved = (await readTanks(
      tester,
    )).singleWhere((tank) => tank.name == '无日期海缸');
    expect(saved.startedOn, isNull);
    expect(saved.volumeLiters, isNull);
    expect(await readCurrentTankId(tester), saved.id);
    expect(find.textContaining('设置开缸日期'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testManagement('实际日期选择器取消不预填，确认日期及有效水体积后保存', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('添加海缸'));
    await tester.pumpAndSettle();
    await tester.enterText(_name, '有日期海缸');
    await _pickDate(tester, today, cancel: true);
    expect(find.byKey(const Key('clear-tank-start-date')), findsNothing);
    await _pickDate(tester, today);
    expect(find.text(_dateKey(today)), findsOneWidget);
    await tester.enterText(_volume, '0');
    await _dialogAction(tester, '保存');
    expect(find.byType(SettingsEntryDialog), findsOneWidget);
    expect(await readTanks(tester), hasLength(1));

    await tester.enterText(_volume, '250.5');
    await _dialogAction(tester, '保存');
    expect(find.byType(SettingsEntryDialog), findsNothing);
    final saved = (await readTanks(
      tester,
    )).singleWhere((tank) => tank.name == '有日期海缸');
    expect(saved.startedOn, _dateKey(today));
    expect(saved.volumeLiters, 250.5);
    expect(tester.takeException(), isNull);
  });

  testManagement('编辑取消不写库，清空其他缸资料不改变当前缸', (tester) async {
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final earlier = DateTime(today.year, today.month, today.day - 2);
    final idA = await repository.createTank(
      name: '编辑 A',
      startedOn: _dateKey(yesterday),
      volumeLiters: 100,
    );
    final idB = await repository.createTank(
      name: '编辑 B',
      startedOn: _dateKey(earlier),
      volumeLiters: 220,
    );
    await open(tester);
    final original = await readTanks(tester);
    final originalA = original.singleWhere((tank) => tank.id == idA);
    final originalB = original.singleWhere((tank) => tank.id == idB);
    final originalCurrentTankId = await readCurrentTankId(tester);
    expect(originalCurrentTankId, isNot(idA));
    await _editTank(tester, '编辑 A');
    expect(_text(tester, _volume), '100');
    await tester.enterText(_name, '取消后不应出现');
    await tester.enterText(_volume, '300');
    await _pickDate(tester, today);
    await _dialogAction(tester, '取消');
    final cancelled = await readTanks(tester);
    expect(cancelled.singleWhere((tank) => tank.id == idA), originalA);
    expect(cancelled.singleWhere((tank) => tank.id == idB), originalB);
    expect(await readCurrentTankId(tester), originalCurrentTankId);

    await _editTank(tester, '编辑 A');
    expect(find.text(_dateKey(yesterday)), findsOneWidget);
    expect(_text(tester, _volume), '100');
    await tester.tap(find.byKey(const Key('clear-tank-start-date')));
    await tester.enterText(_volume, '');
    await _dialogAction(tester, '保存');
    final saved = await readTanks(tester);
    final updated = saved.singleWhere((tank) => tank.id == idA);
    expect(updated.name, '编辑 A');
    expect(updated.startedOn, isNull);
    expect(updated.volumeLiters, isNull);
    expect(saved.singleWhere((tank) => tank.id == idB), originalB);
    expect(await readCurrentTankId(tester), originalCurrentTankId);
    expect(tester.takeException(), isNull);
  });

  testManagement('首页实际时钟跨日和恢复更新天数，日期与鱼只入口独立且跟随当前缸', (tester) async {
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    await repository.updateTank(
      tankId: AppDatabase.defaultTankId,
      name: '首页 A',
      startedOn: Value(_dateKey(today)),
      volumeLiters: const Value(120),
    );
    final tankB = await repository.createTank(
      name: '首页 B',
      startedOn: _dateKey(yesterday),
      volumeLiters: 220,
    );
    await repository.switchTank(AppDatabase.defaultTankId);
    now = DateTime(today.year, today.month, today.day, 23, 59, 59);
    await open(tester, home: true);
    expect(find.text('已运行 0 天'), findsOneWidget);

    now = DateTime(today.year, today.month, today.day + 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('已运行 1 天'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    try {
      now = DateTime(today.year, today.month, today.day + 2, 12);
      await tester.pump(const Duration(minutes: 2));
      expect(find.text('已运行 1 天'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _flush(tester);
      expect(find.text('已运行 2 天'), findsOneWidget);
    } finally {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }

    await tester.runAsync(() => repository.switchTank(tankB));
    await _flush(tester);
    expect(find.text('我的鱼缸 · 首页 B'), findsOneWidget);
    expect(find.text('已运行 3 天'), findsOneWidget);
    final originalA = (await readTanks(
      tester,
    )).singleWhere((tank) => tank.id == AppDatabase.defaultTankId);
    await tester.tap(find.byKey(const Key('edit-tank-start-date')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsEntryDialog), findsOneWidget);
    expect(find.byType(FishManagerSheet), findsNothing);
    expect(_text(tester, _name), '首页 B');
    expect(find.text(_dateKey(yesterday)), findsOneWidget);
    expect(_text(tester, _volume), '220');
    await tester.enterText(_volume, '225');
    await _dialogAction(tester, '保存');
    final saved = await readTanks(tester);
    expect(
      saved.singleWhere((tank) => tank.id == AppDatabase.defaultTankId),
      originalA,
    );
    expect(saved.singleWhere((tank) => tank.id == tankB).volumeLiters, 225);

    await tester.tap(find.byKey(const Key('edit-fish-stock')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsEntryDialog), findsNothing);
    expect(find.byType(FishManagerSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FishManagerSheet),
        matching: find.text('首页 B'),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<FishManagerSheet>(find.byType(FishManagerSheet)).tankId,
      tankB,
    );
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(await readTanks(tester), saved);
    expect(tester.takeException(), isNull);
  });
}

Finder get _name => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == '名称',
);

Finder get _volume => find.byKey(const Key('tank-volume-liters'));

String _text(WidgetTester tester, Finder finder) =>
    tester.widget<TextField>(finder).controller!.text;

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

Future<void> _flush(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

Future<void> _dialogAction(WidgetTester tester, String label) async {
  final action = find.descendant(
    of: find.byType(SettingsEntryDialog),
    matching: find.text(label),
  );
  await tester.ensureVisible(action);
  await tester.tap(action);
  await _flush(tester);
}

Future<void> _editTank(WidgetTester tester, String name) async {
  final row = find.widgetWithText(RadioListTile<String>, name);
  await tester.ensureVisible(row);
  await tester.tap(
    find.descendant(of: row, matching: find.byType(PopupMenuButton<String>)),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('编辑'));
  await tester.pumpAndSettle();
}

Future<void> _pickDate(
  WidgetTester tester,
  DateTime date, {
  bool cancel = false,
}) async {
  final start = find.byKey(const Key('tank-start-date'));
  await tester.ensureVisible(start);
  await tester.tap(start);
  await tester.pumpAndSettle();
  final picker = find.byType(DatePickerDialog);
  expect(picker, findsOneWidget);
  final dialog = tester.widget<DatePickerDialog>(picker);
  expect(dialog.lastDate, DateUtils.dateOnly(DateTime.now()));
  final localizations = MaterialLocalizations.of(tester.element(picker));
  final initial = dialog.initialDate!;
  final monthDifference =
      (date.year - initial.year) * 12 + date.month - initial.month;
  for (var month = 0; month < monthDifference.abs(); month++) {
    await tester.tap(
      find.byTooltip(
        monthDifference < 0
            ? localizations.previousMonthTooltip
            : localizations.nextMonthTooltip,
      ),
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(
    find.descendant(of: picker, matching: find.text('${date.day}')),
  );
  await tester.tap(
    find.descendant(
      of: picker,
      matching: find.text(
        cancel ? localizations.cancelButtonLabel : localizations.okButtonLabel,
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(picker, findsNothing);
}
