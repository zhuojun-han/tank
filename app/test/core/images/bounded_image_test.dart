import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:lanjiao_water_quality/core/images/bounded_image.dart';

void main() {
  test(
    'PNG oversized dimensions are rejected before reading their pixel payload',
    () {
      final bytes = image.encodePng(image.Image(width: 2, height: 2));
      final data = ByteData.sublistView(bytes);
      data.setUint32(16, 100000);
      data.setUint32(20, 100000);
      data.setUint32(29, getCrc32(Uint8List.sublistView(bytes, 12, 29)));
      expect(
        () => decodeBoundedImage(bytes),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('尺寸过大'),
          ),
        ),
      );
    },
  );

  test('JPEG SOF is guarded before decoder coefficient allocation', () {
    final bytes = image.encodeJpg(image.Image(width: 2, height: 2));
    var found = false;
    for (var i = 0; i < bytes.length - 9; i++) {
      if (bytes[i] == 0xff && bytes[i + 1] == 0xc0) {
        ByteData.sublistView(bytes).setUint16(i + 5, 65535);
        ByteData.sublistView(bytes).setUint16(i + 7, 65535);
        found = true;
        break;
      }
    }
    expect(found, isTrue);
    expect(
      () => decodeBoundedImage(bytes),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('尺寸过大'),
        ),
      ),
    );
  });

  test('still JPEG, PNG and WebP retain their dimensions and colors', () {
    final source = image.Image(width: 20, height: 10, numChannels: 4);
    image.fill(source, color: image.ColorRgba8(60, 120, 180, 255));
    for (final bytes in [
      image.encodeJpg(source),
      image.encodePng(source),
      image.encodeWebP(source),
    ]) {
      final decoded = decodeBoundedImage(bytes);
      expect((decoded.width, decoded.height), (20, 10));
      expect(decoded.getPixel(5, 5).g, closeTo(120, 3));
    }
  });

  test(
    'working images cap both dimensions without upscaling a thin portrait',
    () {
      final portrait = fitImageWithin(image.Image(width: 2, height: 4000), 512);
      expect((portrait.width, portrait.height), (1, 512));
      final landscape = fitImageWithin(
        image.Image(width: 3000, height: 1000),
        maximumWorkingPhotoEdge,
      );
      expect((landscape.width, landscape.height), (2048, 683));
      final small = image.Image(width: 30, height: 20);
      expect(identical(fitImageWithin(small, 512), small), isTrue);
    },
  );

  test('file byte limit is checked before a large input is retained', () async {
    final directory = await Directory.systemTemp.createTemp('bounded-image-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/input.png');
    await file.writeAsBytes(Uint8List(1025));
    await expectLater(
      readBoundedImageFile(file.path, maximumBytes: 1024),
      throwsFormatException,
    );
    expect(await file.length(), 1025);
  });

  test('small PNG header cannot hide an oversized inflated IDAT payload', () {
    final source = image.encodePng(image.Image(width: 1, height: 1));
    final encoded = Uint8List.fromList(
      ZLibCodec().encoder.convert(Uint8List(8192)),
    );
    final result = BytesBuilder()..add(source.sublist(0, 8));
    final data = ByteData.sublistView(source);
    for (var offset = 8; offset + 12 <= source.length;) {
      final length = data.getUint32(offset);
      if (data.getUint32(offset + 4) == 0x49444154) {
        final header = ByteData(8)
          ..setUint32(0, encoded.length)
          ..setUint32(4, 0x49444154);
        final crc = ByteData(4)
          ..setUint32(
            0,
            getCrc32([...header.buffer.asUint8List().sublist(4), ...encoded]),
          );
        result
          ..add(header.buffer.asUint8List())
          ..add(encoded)
          ..add(crc.buffer.asUint8List());
      } else {
        result.add(source.sublist(offset, offset + 12 + length));
      }
      offset += 12 + length;
    }
    expect(
      () => decodeBoundedImage(result.takeBytes()),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('像素数据'),
        ),
      ),
    );
  });

  test(
    'unsupported formats are rejected without invoking a generic decoder',
    () {
      expect(
        () => decodeBoundedImage(Uint8List.fromList('GIF89a'.codeUnits)),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('静态 PNG'),
          ),
        ),
      );
    },
  );
}
