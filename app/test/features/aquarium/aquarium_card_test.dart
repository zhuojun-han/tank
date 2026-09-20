import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/features/aquarium/domain/fish_stock.dart';
import 'package:lanjiao_water_quality/features/aquarium/presentation/aquarium_card.dart';

FishStockItem fish({int quantity = 1, String tankId = 'tank'}) => FishStockItem(
  id: 'fish',
  tankId: tankId,
  species: '小丑鱼',
  quantity: quantity,
  introducedOn: DateTime(2026, 9, 7),
  artworkKind: FishArtworkKind.builtinClownfish,
);

Widget scene(
  List<FishStockItem> items, {
  bool reduceMotion = false,
  bool enabled = true,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: TickerMode(enabled: enabled, child: child!),
  ),
  home: Scaffold(
    body: SizedBox(
      width: 394,
      child: AquariumCard(tankName: '测试缸', items: items, onTap: () {}),
    ),
  ),
);

Offset position(WidgetTester tester) {
  final widget = tester.widget<Positioned>(
    find.byKey(const ValueKey('fish-0')),
  );
  return Offset(widget.left!, widget.top!);
}

void main() {
  CustomPainter bubbles(WidgetTester tester) => tester
      .widget<CustomPaint>(find.byKey(const Key('aquarium-bubbles')))
      .painter!;

  testWidgets(
    'all aquarium text is outside the water, with separate tank and fish entry points',
    (tester) async {
      var tankEdits = 0, fishEdits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AquariumCard(
              tankName: '我的测试缸',
              items: [fish()],
              runningDays: 7,
              onManageTank: () => tankEdits++,
              onTap: () => fishEdits++,
            ),
          ),
        ),
      );
      final water = find.byKey(const Key('aquarium-water'));
      expect(
        find.descendant(of: water, matching: find.byType(Text)),
        findsNothing,
      );
      expect(
        tester.getBottomLeft(find.text('已运行 7 天')).dy,
        lessThanOrEqualTo(tester.getTopLeft(water).dy),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('aquarium-stock-summary'))).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(water).dy),
      );
      await tester.tap(find.byKey(const Key('edit-tank-start-date')));
      await tester.tap(find.byKey(const Key('edit-fish-stock')));
      expect(tankEdits, 1);
      expect(fishEdits, 1);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fish and empty-tank bubbles share background and reduced-motion suspension',
    (tester) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(scene([fish()]));
      await tester.pump(const Duration(milliseconds: 16));
      final initial = bubbles(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(bubbles(tester).shouldRepaint(initial), isTrue);
      final beforePause = bubbles(tester), fishBeforePause = position(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 5));
      expect(bubbles(tester).shouldRepaint(beforePause), isFalse);
      expect(position(tester), fishBeforePause);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final resumed = position(tester);
      expect((resumed - fishBeforePause).distance, lessThan(2));
      await tester.pump(const Duration(milliseconds: 100));
      expect((position(tester) - resumed).distance, greaterThan(0));
      await tester.pumpWidget(scene([], reduceMotion: true));
      final still = bubbles(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(bubbles(tester).shouldRepaint(still), isFalse);
      await tester.pumpWidget(scene([]));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 100));
      expect(bubbles(tester).shouldRepaint(still), isTrue);
      await tester.pumpWidget(scene([], enabled: false));
      final hidden = bubbles(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(bubbles(tester).shouldRepaint(hidden), isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an offscreen aquarium pauses without disposing and resumes its previous scene',
    (tester) async {
      final scroll = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [
                  AquariumCard(tankName: '测试缸', items: [fish()], onTap: () {}),
                  const SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 100));
      scroll.jumpTo(1000);
      await tester.pump();
      final offscreen = bubbles(tester), fishOffscreen = position(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(bubbles(tester).shouldRepaint(offscreen), isFalse);
      expect(position(tester), fishOffscreen);
      scroll.jumpTo(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect((position(tester) - fishOffscreen).distance, lessThan(2));
      await tester.pump(const Duration(milliseconds: 100));
      expect(bubbles(tester).shouldRepaint(offscreen), isTrue);
      await tester.pumpWidget(const SizedBox());
      scroll.dispose();
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets(
    'homepage rebuilds each second preserve swimming position for equivalent stock',
    (tester) async {
      await tester.pumpWidget(scene([fish()]));
      final start = position(tester);
      for (var second = 0; second < 3; second++) {
        for (var frame = 0; frame < 60; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final beforeRefresh = position(tester);
        expect((beforeRefresh - start).distance, greaterThan(2));
        // A new list and new model instances must not restart an unchanged tank.
        await tester.pumpWidget(scene([fish()]));
        expect((position(tester) - beforeRefresh).distance, lessThan(0.01));
      }
      final before = position(tester);
      await tester.pump(const Duration(milliseconds: 16));
      expect((position(tester) - before).distance, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stock changes still add, remove and restart fish after an empty tank',
    (tester) async {
      await tester.pumpWidget(scene([fish()]));
      await tester.pumpWidget(scene([fish(quantity: 2)]));
      expect(find.byKey(const ValueKey('fish-1')), findsOneWidget);
      await tester.pumpWidget(scene([]));
      expect(find.byKey(const ValueKey('fish-0')), findsNothing);
      await tester.pumpWidget(scene([fish(tankId: 'other')]));
      await tester.pump(const Duration(milliseconds: 16));
      final before = position(tester);
      await tester.pump(const Duration(milliseconds: 16));
      expect((position(tester) - before).distance, greaterThan(0));
      expect(find.byKey(const ValueKey('fish-1')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
