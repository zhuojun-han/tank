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

Widget scene(List<FishStockItem> items) => MaterialApp(
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
