import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:lanjiao_water_quality/features/aquarium/data/fish_artwork_processor.dart';
import 'package:lanjiao_water_quality/features/aquarium/domain/fish_stock.dart';

void main() {
  test('上传立绘在端侧转为受限大小 WebP', () async {
    final source = image.Image(width: 900, height: 500, numChannels: 4);
    image.fill(source, color: image.ColorRgba8(255, 120, 30, 180));
    final png = image.encodePng(source);

    final result = await const FishArtworkProcessor().prepare(png);

    expect(result.mimeType, 'image/webp');
    expect(
      result.base64Data.length,
      lessThanOrEqualTo(maximumFishArtworkBase64Length),
    );
    final decoded = image.decodeWebP(base64Decode(result.base64Data));
    expect(decoded, isNotNull);
    expect(decoded!.width, lessThanOrEqualTo(512));
  });

  test('拒绝空图片和超过 8 MB 的输入', () async {
    const processor = FishArtworkProcessor();
    await expectLater(processor.prepare(Uint8List(0)), throwsFormatException);
    await expectLater(
      processor.prepare(Uint8List(maximumFishArtworkInputBytes + 1)),
      throwsFormatException,
    );
  });
}
