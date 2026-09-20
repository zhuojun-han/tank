import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/images/bounded_image.dart';

/// One active capture and its immediately previous image. These files are
/// drafts, never formal detection records and never added to complete backups.
class NativePhotoDraftStorage {
  NativePhotoDraftStorage({Future<Directory> Function()? supportDirectory})
    : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  static const maximumBytes = 2 * 1024 * 1024;
  static const maximumEdge = 1600;
  static final _tokenPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  final Future<Directory> Function() _supportDirectory;
  bool _saving = false;

  Future<Directory> _directory() async {
    final support = await _supportDirectory();
    return Directory(p.join(support.path, 'webview-photo-drafts'))
      ..createSync(recursive: true);
  }

  Future<Map<String, dynamic>> save({
    required String tankId,
    required Object? dataUrl,
  }) async {
    if (_saving) throw const FormatException('正在保存照片，请稍后重试。');
    const prefix = 'data:image/jpeg;base64,';
    if (dataUrl is! String ||
        !dataUrl.startsWith(prefix) ||
        dataUrl.length > prefix.length + ((maximumBytes + 2) ~/ 3) * 4) {
      throw const FormatException('请使用不超过 1600 像素、2 MB 的 JPG 草稿。');
    }
    _saving = true;
    try {
      final bytes = base64Decode(dataUrl.substring(prefix.length));
      if (bytes.length < 4 ||
          bytes.length > maximumBytes ||
          bytes[0] != 0xff ||
          bytes[1] != 0xd8) {
        throw const FormatException('照片草稿格式无效。');
      }
      // Existing decoder inspects JPEG SOF before allocating pixels; perform
      // its bounded decode outside the UI isolate.
      final size = await Isolate.run(() {
        final image = decodeBoundedImage(
          bytes,
          maximumBytes: maximumBytes,
          maximumPixels: maximumEdge * maximumEdge,
        );
        if (image.width > maximumEdge || image.height > maximumEdge) {
          throw const FormatException('照片草稿最长边不能超过 1600 像素。');
        }
        return (image.width, image.height);
      });
      final directory = await _directory();
      final latest = File(p.join(directory.path, 'latest.txt'));
      final previousToken =
          await latest.exists() && await latest.length() <= 100
          ? (await latest.readAsString()).trim()
          : null;
      await for (final entry in directory.list(followLinks: false)) {
        final name = p.basename(entry.path);
        if (entry is File &&
            name.endsWith('.jpg.tmp') &&
            _tokenPattern.hasMatch(
              name.substring(0, name.length - '.jpg.tmp'.length),
            )) {
          await entry.delete();
        }
      }
      final token = const Uuid().v4();
      final file = File(p.join(directory.path, '$token.jpg'));
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(file.path);
      await File(p.join(directory.path, '$token.json')).writeAsString(
        jsonEncode({
          'version': 1,
          'tankId': tankId,
          'width': size.$1,
          'height': size.$2,
        }),
        flush: true,
      );
      final latestTemporary = File('${latest.path}.tmp');
      await latestTemporary.writeAsString(token, flush: true);
      await latestTemporary.rename(latest.path);
      final photos = await directory
          .list(followLinks: false)
          .where(
            (entity) =>
                entity is File &&
                entity.path.endsWith('.jpg') &&
                _tokenPattern.hasMatch(p.basenameWithoutExtension(entity.path)),
          )
          .cast<File>()
          .toList();
      for (final photo in photos) {
        final photoToken = p.basenameWithoutExtension(photo.path);
        if (photoToken != token && photoToken != previousToken) {
          await _deletePair(directory, photoToken);
        }
      }
      final url =
          'https://appassets.androidplatform.net/native-photo/$token.jpg';
      return {
        'photoToken': token,
        'photoUrl': url,
        'source': url,
        'width': size.$1,
        'height': size.$2,
      };
    } finally {
      _saving = false;
    }
  }

  Future<void> remove({required String tankId, required Object? token}) async {
    if (token is! String || !_tokenPattern.hasMatch(token)) {
      throw const FormatException('照片草稿标识无效。');
    }
    final directory = await _directory();
    final metadata = File(p.join(directory.path, '$token.json'));
    if (!await metadata.exists()) return;
    if (await metadata.length() > 4096) {
      throw const FormatException('照片草稿归属无效。');
    }
    final owner = jsonDecode(await metadata.readAsString());
    if (owner is! Map || owner['tankId'] != tankId) {
      throw const FormatException('照片草稿不属于当前海缸。');
    }
    await _deletePair(directory, token);
  }

  Future<void> clear({String? tankId}) async {
    final directory = await _directory();
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File) continue;
      if (tankId == null) {
        await entry.delete();
        continue;
      }
      final token = p.basenameWithoutExtension(entry.path);
      if (!entry.path.endsWith('.json') || !_tokenPattern.hasMatch(token)) {
        continue;
      }
      if (await entry.length() > 4096) continue;
      final metadata = jsonDecode(await entry.readAsString());
      if (metadata is Map && metadata['tankId'] == tankId) {
        await _deletePair(directory, token);
      }
    }
  }

  Future<void> _deletePair(Directory directory, String token) async {
    for (final extension in ['jpg', 'json', 'jpg.tmp']) {
      final file = File(p.join(directory.path, '$token.$extension'));
      if (await file.exists()) await file.delete();
    }
  }
}
