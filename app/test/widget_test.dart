import 'package:lanjiao_water_quality/features/trends/data/record_history_source.dart';
import 'support/record_history_fixture.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/app/lanjiao_app.dart';
import 'package:lanjiao_water_quality/app/router.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/aquarium/application/aquarium_providers.dart';
import 'package:lanjiao_water_quality/features/aquarium/domain/fish_stock.dart';
import 'package:lanjiao_water_quality/features/aquarium/presentation/aquarium_card.dart';
import 'package:lanjiao_water_quality/features/aquarium/presentation/fish_artwork_view.dart';
import 'package:lanjiao_water_quality/features/calculators/application/maintenance_cycle_providers.dart';
import 'package:lanjiao_water_quality/features/tanks/application/tank_providers.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_providers.dart';
import 'package:lanjiao_water_quality/features/maintenance/application/maintenance_notification_providers.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';
import 'package:lanjiao_water_quality/features/test_records/application/test_record_providers.dart';
import 'package:lanjiao_water_quality/features/trends/presentation/database_record_history_widgets.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });
  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('鱼种目录横滑至末尾选择黄金吊，切换自定义后仍保存正确数量与立绘', (tester) async {
    await tester.pumpWidget(_testApp(enableRealFishStock: true));
    await _pumpUntilFound(tester, find.byKey(const Key('home-aquarium-card')));

    await tester.tap(find.byKey(const Key('edit-fish-stock')));
    await _pumpUntilFound(tester, find.text('鱼类档案'));
    await tester.pumpAndSettle();
    expect(find.text('小丑鱼'), findsOneWidget);
    expect(find.text('20 个内置鱼种 · 点击立绘选择'), findsOneWidget);
    final catalog = find.byKey(const Key('builtin-fish-catalog'));
    final catalogScrollable = find.descendant(
      of: catalog,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.right,
      ),
    );
    final yellowTang = find.byKey(const Key('builtin-fish-builtinYellowTang'));
    expect(yellowTang.hitTestable(), findsNothing);
    await _center(tester, catalog);
    await tester.scrollUntilVisible(
      yellowTang,
      400,
      scrollable: catalogScrollable,
      maxScrolls: 20,
    );
    expect(
      tester.state<ScrollableState>(catalogScrollable).position.pixels,
      greaterThan(0),
    );
    await tester.tap(yellowTang.hitTestable());
    await tester.pump();
    expect(
      find.descendant(
        of: yellowTang,
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
    final managerScrollable = find.descendant(
      of: find.byKey(const Key('fish-manager-list')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    expect(managerScrollable, findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('其他鱼种'),
      -250,
      scrollable: managerScrollable,
    );
    await tester.tap(find.text('其他鱼种'));
    await tester.pump();
    expect(find.byKey(const Key('custom-fish-species-field')), findsOneWidget);
    expect(find.byKey(const Key('pick-custom-fish-artwork')), findsOneWidget);
    await tester.tap(find.text('内置鱼种'));
    await tester.pump();
    final quantity = find.byKey(const Key('new-fish-quantity-field'));
    await tester.ensureVisible(quantity);
    await tester.enterText(quantity, '3');
    await tester.scrollUntilVisible(
      find.byKey(const Key('add-fish-stock-item')),
      250,
      scrollable: managerScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('add-fish-stock-item')).hitTestable(),
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('save-fish-stock')));
    await tester.tap(find.byKey(const Key('save-fish-stock')));
    await _pumpUntilFound(tester, find.text('黄金吊 × 3'));

    expect(find.text('黄金吊 × 3'), findsOneWidget);
    final saved = tester
        .widget<AquariumCard>(find.byType(AquariumCard))
        .items
        .single;
    expect(saved.species, '黄金吊');
    expect(saved.quantity, 3);
    expect(saved.artworkKind, FishArtworkKind.builtinYellowTang);
    final artwork = tester.widgetList<FishArtworkView>(
      find.descendant(
        of: find.byKey(const Key('home-aquarium-card')),
        matching: find.byType(FishArtworkView),
      ),
    );
    expect(artwork, hasLength(3));
    expect(
      artwork.every((view) => view.kind == FishArtworkKind.builtinYellowTang),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });

  testWidgets('底部导航和设置入口可访问', (tester) async {
    await tester.pumpWidget(_testApp());
    await _pumpUntilFound(tester, find.text('我的海缸'));

    await tester.tap(find.text('检测').last);
    await _pumpUntilFound(tester, find.byKey(const Key('add-test-record')));
    await tester.scrollUntilVisible(
      find.byKey(const Key('add-test-record')),
      240,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 20,
    );
    final addRecord = find.byKey(const Key('add-test-record'));
    await _center(tester, addRecord);
    await tester.tap(addRecord.hitTestable());
    await _pumpUntilFound(tester, find.text('检测参数'));
    expect(find.text('添加手动检测'), findsOneWidget);
    expect(find.text('检测参数'), findsOneWidget);
    expect(find.text('单值'), findsOneWidget);
    expect(find.text('范围'), findsOneWidget);
    expect(find.text('检测时间'), findsOneWidget);
    expect(find.text('备注（可选）'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('设置'));
    await _pumpUntilFound(tester, find.text('海缸管理'));
    expect(find.text('我的海缸'), findsWidgets);
    expect(find.text('关注指标管理'), findsOneWidget);
    expect(find.text('水质目标范围'), findsOneWidget);
    expect(find.text('稳定滴定配方'), findsOneWidget);
    await _disposeApp(tester);
  });

  testWidgets('设置页可进入海盐和氯化镧计算器', (tester) async {
    await tester.pumpWidget(_testApp());
    await _pumpUntilFound(tester, find.text('我的海缸'));
    await tester.tap(find.byTooltip('设置'));
    await _pumpUntilFound(tester, find.text('设置与工具'));
    await tester.scrollUntilVisible(
      find.text('海盐计算'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await _center(tester, find.text('海盐计算'));
    await tester.tap(find.text('海盐计算').hitTestable());
    await _pumpUntilFound(tester, find.byKey(const Key('calculate-salinity')));
    expect(find.text('海盐配制计算器'), findsWidgets);
    expect(find.byKey(const Key('salinity-initial')), findsOneWidget);
    expect(find.byKey(const Key('salinity-target')), findsOneWidget);

    await tester.tap(find.byTooltip('Back').hitTestable().last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await _pumpUntilFound(tester, find.text('设置与工具'));
    await tester.scrollUntilVisible(
      find.text('PO4 理论计划'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await _center(tester, find.text('PO4 理论计划'));
    await tester.tap(find.text('PO4 理论计划').hitTestable());
    await _pumpUntilFound(tester, find.byKey(const Key('calculate-lanthanum')));
    expect(find.text('氯化镧降低 PO4'), findsOneWidget);
    expect(find.byKey(const Key('lanthanum-target-po4')), findsOneWidget);
    expect(find.byKey(const Key('lanthanum-net-volume')), findsOneWidget);
    await _disposeApp(tester);
  });

  testWidgets('趋势页无记录时显示真实空状态', (tester) async {
    await tester.pumpWidget(_testApp());
    await _pumpUntilFound(tester, find.byKey(const Key('home-aquarium-card')));
    await tester.tap(find.text('趋势').last);
    await _pumpUntilFound(tester, find.text('NO3 暂无趋势数据'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('trend-add-record')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('trend-add-record')), findsOneWidget);
    expect(find.byKey(const Key('trend-chart')), findsNothing);
    await _disposeApp(tester);
  });

  testWidgets('点击首页 PO4 读数卡后趋势页选中 PO4', (tester) async {
    final first = DateTime.utc(2026, 8, 1);
    final second = DateTime.utc(2026, 8, 10);
    await tester.pumpWidget(
      _testApp(
        records: [
          TestRecord(
            id: 'po4-new',
            tankId: AppDatabase.defaultTankId,
            parameterId: AppDatabase.po4Id,
            confirmedMinValue: 0.03,
            unit: 'mg/L',
            measuredAt: second,
            wasManuallyEdited: false,
            createdAt: second,
            updatedAt: second,
          ),
          TestRecord(
            id: 'po4-old',
            tankId: AppDatabase.defaultTankId,
            parameterId: AppDatabase.po4Id,
            confirmedMinValue: 0.02,
            unit: 'mg/L',
            measuredAt: first,
            wasManuallyEdited: false,
            createdAt: first,
            updatedAt: first,
          ),
        ],
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-aquarium-card')));
    final metric = find.byKey(Key('home-metric-${AppDatabase.po4Id}'));
    await tester.scrollUntilVisible(
      metric,
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(metric);
    await tester.pumpAndSettle();
    await tester.tap(metric);
    await _pumpUntilFound(tester, find.byKey(const Key('trend-chart')));

    expect(find.byKey(const Key('trend-chart')), findsOneWidget);
    expect(
      tester
          .widget<DatabaseRecordChart>(find.byKey(const Key('trend-chart')))
          .overview
          .count,
      2,
    );
    expect(
      tester
          .widget<DatabaseRecordChart>(find.byKey(const Key('trend-chart')))
          .scope,
      (tankId: AppDatabase.defaultTankId, parameterId: AppDatabase.po4Id),
    );
    expect(find.byKey(const Key('insufficient-trend-data')), findsNothing);
    await _disposeApp(tester);
  });

  testWidgets('首页展示全部历史且范围不虚构插值', (tester) async {
    final now = DateTime.now().toUtc().subtract(const Duration(days: 1));
    await tester.pumpWidget(
      _testApp(
        records: [
          TestRecord(
            id: 'home-range',
            tankId: AppDatabase.defaultTankId,
            parameterId: AppDatabase.no3Id,
            confirmedMinValue: 10,
            confirmedMaxValue: 25,
            unit: 'mg/L',
            measuredAt: now,
            wasManuallyEdited: false,
            createdAt: now,
            updatedAt: now,
          ),
          TestRecord(
            id: 'home-po4-old',
            tankId: AppDatabase.defaultTankId,
            parameterId: AppDatabase.po4Id,
            confirmedMinValue: 0.02,
            unit: 'mg/L',
            measuredAt: DateTime.now().toUtc().subtract(
              const Duration(days: 31),
            ),
            wasManuallyEdited: false,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-aquarium-card')));
    await tester.scrollUntilVisible(
      find.byKey(Key('home-trend-chart-${AppDatabase.no3Id}')),
      260,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 20,
    );

    expect(find.text('插值 / 单值'), findsWidgets);
    expect(find.textContaining('中点不是真实测量值'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(Key('home-trend-chart-${AppDatabase.po4Id}')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(Key('home-trend-chart-${AppDatabase.po4Id}')),
      findsOneWidget,
    );
    await _disposeApp(tester);
  });

  testWidgets('趋势明细按当前缸精确记录进入详情和编辑', (tester) async {
    final older = DateTime.now().toUtc().subtract(const Duration(days: 2));
    final newer = DateTime.now().toUtc().subtract(const Duration(days: 1));
    await tester.pumpWidget(
      _testApp(
        records: [
          TestRecord(
            id: 'trend-old',
            tankId: AppDatabase.defaultTankId,
            parameterId: AppDatabase.no3Id,
            confirmedMinValue: 5,
            unit: 'mg/L',
            measuredAt: older,
            notes: '较早记录',
            wasManuallyEdited: false,
            createdAt: older,
            updatedAt: older,
          ),
          TestRecord(
            id: 'trend-exact',
            tankId: AppDatabase.defaultTankId,
            parameterId: AppDatabase.no3Id,
            estimatedMinValue: 10,
            estimatedMaxValue: 25,
            confirmedMinValue: 15,
            unit: 'mg/L',
            measuredAt: newer,
            notes: '应打开这一条',
            wasManuallyEdited: false,
            createdAt: newer,
            updatedAt: newer,
          ),
          TestRecord(
            id: 'foreign-record',
            tankId: 'another-tank',
            parameterId: AppDatabase.no3Id,
            confirmedMinValue: 100,
            unit: 'mg/L',
            measuredAt: newer,
            notes: '不应跨缸显示',
            wasManuallyEdited: false,
            createdAt: newer,
            updatedAt: newer,
          ),
        ],
      ),
    );
    await _pumpUntilFound(tester, find.text('我的海缸'));
    await tester.tap(find.text('趋势').last);
    await _pumpUntilFound(tester, find.byKey(const Key('trend-chart')));
    await tester.scrollUntilVisible(
      find.byKey(const Key('trend-record-trend-exact')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('trend-record-foreign-record')), findsNothing);
    await _center(tester, find.byKey(const Key('trend-record-trend-exact')));
    await tester.tap(find.byKey(const Key('trend-record-trend-exact')));
    await _pumpUntilFound(tester, find.text('NO3 检测详情'));

    expect(find.text('应打开这一条'), findsOneWidget);
    expect(find.text('10–25 mg/L'), findsNothing);
    await tester.ensureVisible(find.text('算法原始结果（只读）'));
    await tester.tap(find.text('算法原始结果（只读）'));
    await tester.pumpAndSettle();
    expect(find.text('10–25 mg/L'), findsOneWidget);
    final editButton = find.byKey(const Key('edit-test-record')).hitTestable();
    expect(editButton, findsOneWidget);
    await tester.tap(editButton);
    await _pumpUntilFound(tester, find.text('算法与拍摄原始信息（只读）'));
    await _disposeApp(tester);
  });

  testWidgets('大字体与窄屏下首屏可滚动且不发生布局异常', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(_testApp());
    await _pumpUntilFound(tester, find.byKey(const Key('home-aquarium-card')));
    await tester.scrollUntilVisible(
      find.text('建议先做这些'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('建议先做这些'), findsOneWidget);
    await _disposeApp(tester);
  });
}

Widget _testApp({
  List<TestRecord> records = const [],
  List<WaterQualityTarget> targets = const [],
  bool enableRealFishStock = false,
}) {
  final now = DateTime.utc(2026, 8, 9);
  final tank = Tank(
    id: AppDatabase.defaultTankId,
    name: '我的海缸',
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
  final parameters = [
    WaterParameter(
      id: AppDatabase.no3Id,
      code: 'NO3',
      displayName: '硝酸盐',
      unit: 'mg/L',
      isBuiltIn: true,
      photoSupported: true,
      createdAt: now,
    ),
    WaterParameter(
      id: AppDatabase.po4Id,
      code: 'PO4',
      displayName: '磷酸盐',
      unit: 'mg/L',
      isBuiltIn: true,
      photoSupported: false,
      createdAt: now,
    ),
  ];
  return ProviderScope(
    overrides: [
      recordHistorySourceProvider.overrideWithValue(
        FixtureRecordHistorySource(records),
      ),
      appDatabaseProvider.overrideWith((ref) {
        final database = AppDatabase(NativeDatabase.memory());
        ref.onDispose(database.close);
        return database;
      }),
      notificationsEnabledProvider.overrideWithValue(false),
      maintenanceClockProvider.overrideWith((ref) => Stream.value(now)),
      // These fixtures exercise navigation/records/fish, with no dosing cycles.
      maintenanceCyclesProvider.overrideWith(
        (ref, tankId) => Stream.value(const []),
      ),
      allMaintenanceTaskItemsProvider.overrideWith(
        (ref) => Stream.value(const []),
      ),
      currentTankProvider.overrideWith((ref) => Stream.value(tank)),
      activeTanksProvider.overrideWith((ref) => Stream.value([tank])),
      enabledParametersProvider.overrideWith(
        (ref, tankId) => Stream.value(parameters),
      ),
      parameterStatesProvider.overrideWith(
        (ref, tankId) => Stream.value([
          for (final parameter in parameters)
            TankParameterState(parameter: parameter, isEnabled: true),
        ]),
      ),
      waterQualityTargetsProvider.overrideWith(
        (ref, tankId) => Stream.value(targets),
      ),
      latestTestRecordsProvider.overrideWith(
        (ref, tankId) => Stream.value([
          for (final record in records)
            if (record.tankId == tankId) record,
        ]),
      ),
      testRecordProvider.overrideWith(
        (ref, scope) => Future.value(_scopedRecord(records, scope)),
      ),
      reagentProfilesProvider.overrideWith(
        (ref, parameterId) => Stream.value(const []),
      ),
      enabledReagentProfilesProvider.overrideWith(
        (ref, parameterId) => Stream.value(const []),
      ),
      maintenanceTaskItemsProvider.overrideWith(
        (ref, tankId) => Stream.value(const []),
      ),
      if (!enableRealFishStock)
        fishStockProvider.overrideWith(
          (ref, tankId) => Stream.value(const <FishStockItem>[]),
        ),
    ],
    child: LanjiaoApp(router: createAppRouter()),
  );
}

TestRecord? _scopedRecord(List<TestRecord> records, TestRecordScope scope) {
  for (final record in records) {
    if (record.tankId == scope.tankId && record.id == scope.recordId) {
      return record;
    }
  }
  return null;
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('等待组件超时：$finder');
}

Future<void> _center(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
}

Future<void> _disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}
