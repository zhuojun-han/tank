import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:lanjiao_water_quality/webview/native_photo_draft_storage.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  late NativePhotoDraftStorage storage;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lanjiao-photo-draft-');
    storage = NativePhotoDraftStorage(supportDirectory: () async => directory);
  });

  tearDown(() async => directory.delete(recursive: true));

  String jpeg(int width, int height) =>
      'data:image/jpeg;base64,${base64Encode(image.encodeJpg(image.Image(width: width, height: height)))}';

  test(
    'photo bytes survive a new service instance; deletion checks tank ownership',
    () async {
      final url = jpeg(8, 6);
      final result = await storage.save(tankId: 'tank-a', dataUrl: url);
      final token = result['photoToken'] as String;
      final file = File(
        p.join(directory.path, 'webview-photo-drafts', '$token.jpg'),
      );
      expect(await file.readAsBytes(), base64Decode(url.split(',').last));
      expect(
        result['photoUrl'],
        'https://appassets.androidplatform.net/native-photo/$token.jpg',
      );
      expect(result['width'], 8);
      expect(result['height'], 6);

      final restarted = NativePhotoDraftStorage(
        supportDirectory: () async => directory,
      );
      await expectLater(
        restarted.remove(tankId: 'tank-b', token: token),
        throwsFormatException,
      );
      expect(await file.exists(), isTrue);
      await restarted.remove(tankId: 'tank-a', token: token);
      await restarted.remove(tankId: 'tank-a', token: token);
      expect(await file.exists(), isFalse);
    },
  );

  test(
    'new captures bound disk use and remove interrupted temporary writes',
    () async {
      final url = jpeg(8, 8);
      final first = await storage.save(tankId: 'tank-a', dataUrl: url);
      final cache = Directory(p.join(directory.path, 'webview-photo-drafts'));
      final orphan = File(
        p.join(cache.path, '00000000-0000-4000-8000-000000000001.jpg.tmp'),
      );
      await orphan.writeAsString('unfinished');
      await storage.save(tankId: 'tank-a', dataUrl: url);
      await storage.save(tankId: 'tank-a', dataUrl: url);
      final files = await cache.list().toList();
      expect(files.where((file) => file.path.endsWith('.jpg')).length, 2);
      expect(files.where((file) => file.path.endsWith('.json')).length, 2);
      expect(await orphan.exists(), isFalse);
      expect(
        await File(p.join(cache.path, '${first['photoToken']}.jpg')).exists(),
        isFalse,
      );
    },
  );

  test(
    'invalid type, oversized dimensions and raw paths are rejected',
    () async {
      await expectLater(
        storage.save(
          tankId: 'tank-a',
          dataUrl: 'data:text/html;base64,PHNjcmlwdD4=',
        ),
        throwsFormatException,
      );
      await expectLater(
        storage.save(tankId: 'tank-a', dataUrl: jpeg(1601, 1)),
        throwsFormatException,
      );
      await expectLater(
        storage.remove(tankId: 'tank-a', token: '../database'),
        throwsFormatException,
      );
      expect(
        await Directory(
          p.join(directory.path, 'webview-photo-drafts'),
        ).exists(),
        isFalse,
      );
    },
  );
}
