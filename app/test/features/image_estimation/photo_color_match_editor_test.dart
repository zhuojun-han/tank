import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lanjiao_water_quality/features/image_estimation/presentation/photo_color_match_editor.dart';

Future<void> finishWork(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    if (find.byType(LinearProgressIndicator).evaluate().isEmpty) return;
  }
  fail('Image processing did not complete');
}

void main() {
  for (final parameter in ['NO3', 'PO4']) {
    testWidgets(
      '$parameter physically rotates original pixels and resets selected regions',
      (tester) async {
        final dir = Directory.systemTemp.createTempSync('color-editor-');
        final path = '${dir.path}/photo.png';
        final source = img.Image(width: 400, height: 200, numChannels: 4);
        for (var y = 0; y < 200; y++) {
          for (var x = 0; x < 400; x++) {
            source.setPixelRgba(
              x,
              y,
              x < 200 ? 60 : 180,
              y < 100 ? 80 : 160,
              100,
              255,
            );
          }
        }
        File(path).writeAsBytesSync(img.encodePng(source));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PhotoColorMatchEditor(
                path: path,
                parameter: parameter,
                onConfirm: (_) {},
                onRetake: () {},
                onManual: () {},
              ),
            ),
          ),
        );
        await finishWork(tester);
        final finder = find.byKey(const Key('color-match-image'));
        final bounds = tester.getRect(finder);
        await tester.dragFrom(
          bounds.topLeft + const Offset(10, 10),
          const Offset(200, 80),
        );
        await tester.pump();
        expect(
          tester
              .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
              .value,
          -1,
        );
        await tester.dragFrom(
          bounds.topLeft + const Offset(240, 80),
          const Offset(10, 10),
        );
        await tester.pump();
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '取色比较'))
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.text('顺时针90°'));
        await finishWork(tester);
        final memory =
            tester.widget<Image>(find.byType(Image)).image as MemoryImage;
        final rotated = img.decodePng(memory.bytes)!;
        expect(rotated.width, 200);
        expect(rotated.height, 400);
        expect(rotated.getPixel(0, 0).r, 60);
        expect(rotated.getPixel(0, 0).g, 160);
        expect(
          tester
              .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
              .value,
          -2,
        );
        await tester.tap(find.text('逆时针90°'));
        await finishWork(tester);
        final restored = img.decodePng(
          (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes,
        )!;
        expect(restored.width, 400);
        expect(restored.height, 200);
        expect(restored.getPixel(0, 0).g, 80);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        dir.deleteSync(recursive: true);
      },
    );
  }
}
