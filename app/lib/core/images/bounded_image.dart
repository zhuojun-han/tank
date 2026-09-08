import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

const maximumPhotoInputBytes = 20 * 1024 * 1024;
const maximumPhotoPixels = 20 * 1000 * 1000;
const maximumPhotoEdge = 10000;
const maximumWorkingPhotoEdge = 2048;

/// Bound compressed input before retaining it, including files that grow while read.
Future<Uint8List> readBoundedImageFile(
  String path, {
  int maximumBytes = maximumPhotoInputBytes,
}) async {
  final file = File(path);
  if (await file.length() > maximumBytes) {
    throw const FormatException('照片文件过大，请选择较小的图片。');
  }
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in file.openRead()) {
    if (bytes.length + chunk.length > maximumBytes) {
      throw const FormatException('照片文件过大，请选择较小的图片。');
    }
    bytes.add(chunk);
  }
  return bytes.takeBytes();
}

/// Inspect dimensions before allocating pixels; only a single still frame is accepted.
image.Image decodeBoundedImage(
  Uint8List bytes, {
  int maximumBytes = maximumPhotoInputBytes,
  int maximumPixels = maximumPhotoPixels,
}) {
  if (bytes.isEmpty || bytes.length > maximumBytes) {
    throw const FormatException('照片文件过大或为空，请选择其他图片。');
  }
  // image's JPEG startDecode prepares DCT coefficient buffers. Read SOF first
  // and bypass that duplicate preparation when decoding this common format.
  if (bytes.length > 2 && bytes[0] == 0xff && bytes[1] == 0xd8) {
    final size = _jpegDimensions(bytes);
    _checkDimensions(size.$1, size.$2, maximumPixels);
    final decoded = image.decodeJpg(bytes);
    if (decoded == null) throw const FormatException('无法读取图片。');
    return decoded;
  }
  final data = ByteData.sublistView(bytes);
  late final image.Decoder decoder;
  if (bytes.length >= 33 &&
      data.getUint32(0) == 0x89504e47 &&
      data.getUint32(4) == 0x0d0a1a0a) {
    _checkDimensions(data.getUint32(16), data.getUint32(20), maximumPixels);
    final inflatedLimit = _pngInflatedLimit(data);
    if (inflatedLimit > maximumPixels * 4) {
      throw const FormatException('照片尺寸过大，请降低分辨率后重试。');
    }
    final inflated = _ImageByteCounter(inflatedLimit);
    final conversion = ZLibCodec().decoder.startChunkedConversion(inflated);
    for (var offset = 8; offset + 12 <= bytes.length;) {
      final length = data.getUint32(offset);
      if (length > bytes.length - offset - 12) {
        throw const FormatException('PNG 图片不完整。');
      }
      if (data.getUint32(offset + 4) == 0x6163544c &&
          length >= 4 &&
          data.getUint32(offset + 8) > 1) {
        throw const FormatException('请选择静态照片。');
      }
      if (data.getUint32(offset + 4) == 0x49444154) {
        for (
          var start = offset + 8;
          start < offset + 8 + length;
          start += 1024
        ) {
          final end = start + 1024 < offset + 8 + length
              ? start + 1024
              : offset + 8 + length;
          conversion.add(Uint8List.sublistView(bytes, start, end));
        }
      }
      offset += 12 + length;
    }
    conversion.close();
    decoder = image.PngDecoder();
  } else if (bytes.length >= 12 &&
      data.getUint32(0) == 0x52494646 &&
      data.getUint32(8) == 0x57454250) {
    for (var offset = 12; offset + 8 <= bytes.length;) {
      final length = data.getUint32(offset + 4, Endian.little);
      if (length > bytes.length - offset - 8) {
        throw const FormatException('WebP 图片不完整。');
      }
      final type = data.getUint32(offset);
      if (type == 0x414e494d ||
          type == 0x414e4d46 ||
          type == 0x56503858 && length > 0 && bytes[offset + 8] & 2 != 0) {
        throw const FormatException('请选择静态照片。');
      }
      offset += 8 + length + (length & 1);
    }
    decoder = image.WebPDecoder();
  } else {
    throw const FormatException('请选择静态 PNG、JPG 或 WebP 图片。');
  }
  final info = decoder.startDecode(bytes);
  if (info == null) {
    throw const FormatException('无法读取图片，请使用 PNG、JPG 或 WebP。');
  }
  _checkDimensions(info.width, info.height, maximumPixels);
  // image 4.x reports zero animation frames for a static WebP.
  if (info.numFrames > 1) {
    throw const FormatException('请选择静态照片。');
  }
  final decoded = decoder.decodeFrame(0);
  if (decoded == null) throw const FormatException('无法读取图片。');
  return decoded;
}

void _checkDimensions(int width, int height, int maximumPixels) {
  if (width < 1 ||
      height < 1 ||
      width > maximumPhotoEdge ||
      height > maximumPhotoEdge ||
      width * height > maximumPixels) {
    throw const FormatException('照片尺寸过大，请降低分辨率后重试。');
  }
}

int _pngInflatedLimit(ByteData header) {
  final width = header.getUint32(16), height = header.getUint32(20);
  final bits = header.getUint8(24), color = header.getUint8(25);
  final channels = switch (color) {
    0 || 3 => 1,
    2 => 3,
    4 => 2,
    6 => 4,
    _ => 0,
  };
  if (channels == 0 || !const [1, 2, 4, 8, 16].contains(bits)) {
    throw const FormatException('PNG 图片格式无效。');
  }
  final passes = header.getUint8(28) == 0
      ? const [(0, 0, 1, 1)]
      : const [
          (0, 0, 8, 8),
          (4, 0, 8, 8),
          (0, 4, 4, 8),
          (2, 0, 4, 4),
          (0, 2, 2, 4),
          (1, 0, 2, 2),
          (0, 1, 1, 2),
        ];
  var length = 0;
  for (final pass in passes) {
    if (width <= pass.$1 || height <= pass.$2) continue;
    final columns = (width - pass.$1 + pass.$3 - 1) ~/ pass.$3;
    final rows = (height - pass.$2 + pass.$4 - 1) ~/ pass.$4;
    length += rows * (1 + (columns * channels * bits + 7) ~/ 8);
  }
  return length;
}

class _ImageByteCounter implements Sink<List<int>> {
  _ImageByteCounter(this.maximumBytes);
  final int maximumBytes;
  int _length = 0;
  @override
  void add(List<int> chunk) {
    if (_length + chunk.length > maximumBytes) {
      throw const FormatException('PNG 像素数据超出图片尺寸。');
    }
    _length += chunk.length;
  }

  @override
  void close() {}
}

(int, int) _jpegDimensions(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var offset = 2;
  while (offset + 3 < bytes.length) {
    if (bytes[offset++] != 0xff) break;
    while (offset < bytes.length && bytes[offset] == 0xff) {
      offset++;
    }
    if (offset >= bytes.length) break;
    final marker = bytes[offset++];
    if (marker == 0xda || marker == 0xd9) break;
    if (marker == 0x01 || marker >= 0xd0 && marker <= 0xd8) continue;
    if (offset + 2 > bytes.length) break;
    final length = data.getUint16(offset);
    if (length < 2 || offset + length > bytes.length) break;
    if (marker == 0xc0 || marker == 0xc1 || marker == 0xc2) {
      if (length < 8) break;
      final components = bytes[offset + 7];
      if (components < 1 || components > 4 || length != 8 + components * 3) {
        throw const FormatException('JPEG 图片格式无效。');
      }
      return (data.getUint16(offset + 5), data.getUint16(offset + 3));
    }
    offset += length;
  }
  throw const FormatException('无法读取 JPEG 图片尺寸。');
}

image.Image fitImageWithin(image.Image source, int maximumEdge) {
  final longest = source.width > source.height ? source.width : source.height;
  if (longest <= maximumEdge) return source;
  final width = (source.width * maximumEdge / longest).round().clamp(
    1,
    maximumEdge,
  );
  final height = (source.height * maximumEdge / longest).round().clamp(
    1,
    maximumEdge,
  );
  return image.copyResize(
    source,
    width: width,
    height: height,
    interpolation: image.Interpolation.average,
  );
}
