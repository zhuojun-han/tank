import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanjiao_water_quality/app/theme.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_notification_providers.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_providers.dart';
import 'package:lanjiao_water_quality/features/settings/presentation/settings_menu_sheet.dart';
import 'package:lanjiao_water_quality/features/settings/presentation/settings_page.dart';
import 'package:lanjiao_water_quality/features/tanks/application/tank_providers.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';

void main() {
  late AppDatabase db;
  late TankRepository repository;
  late GoRouter router;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = TankRepository(db);
    await db.select(db.tanks).get();
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Column(
                children: [
                  Text(ref.watch(currentTankProvider).value?.name ?? '载入'),
                  FilledButton(
                    onPressed: () => showSettingsMenu(context),
                    child: const Text('打开设置'),
                  ),
                  FilledButton(
                    onPressed: () => showTankSwitcher(context, ref),
                    child: const Text('切换'),
                  ),
                ],
              ),
            ),
          ),
        ),
        for (final route in [
          '/maintenance-dosing',
          '/lanthanum-calculator',
          '/alkalinity-calculator',
          '/salinity-calculator',
          '/privacy-and-limits',
        ])
          GoRoute(
            path: route,
            builder: (_, _) => Scaffold(body: Text('route:$route')),
          ),
      ],
    );
  });

  tearDown(() async {
    router.dispose();
    await db.close();
  });

  Future<void> open(WidgetTester tester, {double scale = 1}) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tankRepositoryProvider.overrideWithValue(repository),
          notificationsEnabledProvider.overrideWithValue(false),
          maintenanceClockProvider.overrideWith(
            (ref) => Stream.value(DateTime(2026, 9, 9)),
          ),
        ],
        child: MaterialApp.router(
          theme: LanjiaoTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('设置面板关闭后直达对应计算器，不增加二次选择', (tester) async {
    await open(tester);
    await tester.tap(find.text('打开设置'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.ensureVisible(find.text('KH 理论计划'));
    await tester.tap(find.text('KH 理论计划'));
    await tester.pumpAndSettle();
    expect(find.text('route:/alkalinity-calculator'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('窄屏大字设置可滚动进入关注指标及返回', (tester) async {
    await open(tester, scale: 2);
    await tester.tap(find.text('打开设置'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('关注指标管理'));
    await tester.tap(find.text('关注指标管理'));
    await tester.pumpAndSettle();
    expect(find.byType(ParameterSettingsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开设置'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('备份与数据'),
      220,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('备份与数据')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('备份与数据'));
    await tester.pumpAndSettle();
    expect(find.text('导出完整数据备份'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('切缸面板更换当前海缸，关闭面板不改变选择', (tester) async {
    final secondId = await repository.createTank(name: '第二个海缸');
    await repository.switchTank(AppDatabase.defaultTankId);
    await open(tester);
    await tester.tap(find.text('切换'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第二个海缸'));
    await tester.pumpAndSettle();
    expect(
      (await db.select(db.appPreferences).getSingle()).currentTankId,
      secondId,
    );
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.text('切换'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('切换海缸'))).pop();
    await tester.pumpAndSettle();
    expect(
      (await db.select(db.appPreferences).getSingle()).currentTankId,
      secondId,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
