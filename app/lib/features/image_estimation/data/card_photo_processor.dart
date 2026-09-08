import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'captured_photo_processor.dart';
import '../domain/photo_capture_models.dart';

(Uint8List, int, int, PhotoQualityReport) _prepare(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) throw const FormatException('无法读取照片');
  final oriented = img.bakeOrientation(image);
  // Lossless working image: quality is judged per selected region by the matcher.
  return (
    Uint8List.fromList(img.encodePng(oriented)),
    oriented.width,
    oriented.height,
    const PhotoQualityInspector().inspect(oriented),
  );
}

class CardPhotoProcessor implements CapturedPhotoProcessor {
  @override
  Future<PhotoProcessingResult> process(String sourcePath) async {
    try {
      final prepared = await compute(
        _prepare,
        await File(sourcePath).readAsBytes(),
      );
      final root = await getTemporaryDirectory();
      final folder = Directory('${root.path}/lanjiao_photo_work');
      await folder.create(recursive: true);
      final name = '${const Uuid().v4()}.png';
      final file = File('${folder.path}/$name');
      await file.writeAsBytes(prepared.$1, flush: true);
      await discardSource(sourcePath);
      return PhotoProcessingResult.accepted(
        StoredPhoto(
          relativePath: 'lanjiao_photo_work/$name',
          absolutePath: file.path,
          width: prepared.$2,
          height: prepared.$3,
          byteLength: prepared.$1.length,
          capturedAtUtc: DateTime.now().toUtc(),
          qualityReport: prepared.$4,
        ),
      );
    } catch (_) {
      return PhotoProcessingResult.failed(
        message: '无法读取照片，请重新拍摄或选择图片。',
        retainedSourcePath: sourcePath,
      );
    }
  }

  @override
  Future<void> discardSource(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> deleteStoredPhoto(StoredPhoto photo) =>
      discardSource(photo.absolutePath);
}
