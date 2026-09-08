import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import '../../../core/images/bounded_image.dart';

import '../domain/fish_stock.dart';

class PreparedFishArtwork {
  const PreparedFishArtwork({required this.mimeType, required this.base64Data});

  final String mimeType;
  final String base64Data;
}

class FishArtworkProcessor {
  const FishArtworkProcessor();

  Future<PreparedFishArtwork> prepare(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maximumFishArtworkInputBytes) {
      throw const FormatException('原图不能为空且不能超过 8 MB');
    }
    final result = await compute(_prepareArtwork, bytes);
    return PreparedFishArtwork(
      mimeType: result['mimeType']!,
      base64Data: result['base64Data']!,
    );
  }
}

Map<String, String> _prepareArtwork(Uint8List bytes) {
  final decoded = decodeBoundedImage(
    bytes,
    maximumBytes: maximumFishArtworkInputBytes,
  );
  if (decoded.width < 2 || decoded.height < 2) {
    throw const FormatException('无法读取该图片，请使用 PNG、JPG 或 WebP');
  }
  final oriented = image.bakeOrientation(decoded);
  for (final width in const [512, 420, 360, 300, 256, 220]) {
    final resized = fitImageWithin(oriented, width);
    final encodedBytes = image.encodeWebP(resized);
    final encoded = base64Encode(encodedBytes);
    if (encoded.length <= maximumFishArtworkBase64Length) {
      return {'mimeType': 'image/webp', 'base64Data': encoded};
    }
  }
  throw const FormatException('压缩后立绘仍然过大，请选择背景更简单的图片');
}
