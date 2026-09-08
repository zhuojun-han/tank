import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lanjiao_water_quality/features/image_estimation/domain/card_color_match.dart';

void main() {
  test(
    'NO3 and PO4 match current web outputs, including recorded sample RGB',
    () {
      final fixtures =
          jsonDecode(
                File('test/fixtures/web-color-parity.json').readAsStringSync(),
              )
              as List;
      ColorSample sample(Map s) => ColorSample(
        (s['rgb'] as List).map((v) => (v as num).toDouble()).toList(),
        spread: (s['spread'] as num).toDouble(),
        rejected: (s['rejected'] as num).toDouble(),
        count: s['count'] as int,
      );
      for (final f in fixtures) {
        final result = compareCardColors(sample(f['liquid']), [
          for (final p in f['patches'])
            ColorPatch(
              (p['level'] as num).toDouble(),
              const SampleRect(0, 0, .1, .1),
              sample(p['sample']),
            ),
        ], f['parameter']);
        final e = f['expected'];
        expect(result.nearest, e['nearestLevel']);
        expect(result.low, e['range']?[0]);
        expect(result.high, e['range']?[1]);
        if (e['interpolatedValue'] == null) {
          expect(result.interpolation, isNull);
        } else {
          expect(result.interpolation, closeTo(e['interpolatedValue'], 1e-8));
        }
      }
    },
  );
  test(
    'quality, nonadjacent bracket and outside projection reject independently for both parameters',
    () {
      for (final parameter in ['NO3', 'PO4']) {
        final levels = cardTemplate(parameter).toSet().toList()..sort();
        List<ColorPatch> ramp() => List.generate(
          7,
          (i) => ColorPatch(
            levels[i],
            const SampleRect(0, 0, .1, .1),
            ColorSample(List.filled(3, 30.0 + i * 30)),
          ),
        );
        final bad = compareCardColors(
          const ColorSample([105, 105, 105], spread: 15),
          ramp(),
          parameter,
        );
        expect([bad.nearest, bad.low, bad.interpolation], everyElement(isNull));
        final patches = ramp();
        final p = patches[2];
        patches[2] = ColorPatch(levels[6], p.rect, p.sample);
        patches[6] = ColorPatch(levels[2], patches[6].rect, patches[6].sample);
        final nonAdjacent = compareCardColors(
          const ColorSample([105, 105, 105]),
          patches,
          parameter,
        );
        expect(nonAdjacent.nearest, isNotNull);
        expect(nonAdjacent.low, isNull);
        expect(nonAdjacent.interpolationReasons, hasLength(1));
        final outside = compareCardColors(
          const ColorSample([240, 240, 240]),
          ramp(),
          parameter,
        );
        expect(outside.nearest, levels.last);
        expect(outside.low, levels[5]);
        expect(outside.interpolation, isNull);
      }
    },
  );
  test('sampling uses channel median and excludes clipped highlights', () {
    final image = img.Image(width: 20, height: 20, numChannels: 4);
    img.fill(image, color: img.ColorRgba8(120, 50, 80, 255));
    for (var i = 0; i < 10; i++) {
      image.setPixelRgba(i, 0, 255, 255, 255, 255);
    }
    final sample = sampleRegion(image, const SampleRect(0, 0, 1, 1));
    expect(sample.rgb, [120, 50, 80]);
    expect(sample.count, 390);
    expect(
      () => sampleRegion(image, const SampleRect(.9, 0, .2, 1)),
      throwsFormatException,
    );
  });
  test('fixed upright templates locate eight patch centers', () {
    for (final parameter in ['NO3', 'PO4']) {
      final image = img.Image(width: 400, height: 200, numChannels: 4);
      for (var y = 0; y < 200; y++) {
        for (var x = 0; x < 400; x++) {
          final i = y ~/ 100 * 4 + x ~/ 100;
          image.setPixelRgba(x, y, 40 + i * 20, 80, 100, 255);
        }
      }
      final patches = pickCardPatches(
        image,
        const SampleRect(0, 0, 1, 1),
        parameter,
      );
      expect(patches.map((p) => p.level), cardTemplate(parameter));
      for (var i = 0; i < 8; i++) {
        expect(patches[i].sample.rgb, [40 + i * 20, 80, 100]);
      }
    }
  });
}
