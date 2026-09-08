import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/images/bounded_image.dart';
import 'captured_photo_processor.dart';
import '../domain/photo_capture_models.dart';

Future<(Uint8List, int, int, PhotoQualityReport)> _prepare(String path) async {
  final image = decodeBoundedImage(await readBoundedImageFile(path));
  final oriented = img.bakeOrientation(image);
  final quality = const PhotoQualityInspector().inspect(oriented);
  // Bound every later pixel copy/rotation; PNG adds no further encoding loss.
  final working = fitImageWithin(oriented, maximumWorkingPhotoEdge);
  return (img.encodePng(working), working.width, working.height, quality);
}

class CardPhotoProcessor implements CapturedPhotoProcessor {
  @override
  Future<PhotoProcessingResult> process(String sourcePath) async {
    try {
      final prepared = await compute(_prepare, sourcePath);
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
    } catch (error) {
      return PhotoProcessingResult.failed(
        message: error is FormatException
            ? error.message
            : '无法读取照片，请重新拍摄或选择图片。',
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
