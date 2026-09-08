import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/features/test_records/data/local_photo_storage.dart';
import 'package:path/path.dart' as path;

void main() {
  group('normalizeManagedPhotoReference', () {
    test('保留受管目录内的规范相对路径', () {
      expect(
        normalizeManagedPhotoReference('water_quality_photos/photo.jpg'),
        'water_quality_photos/photo.jpg',
      );
      expect(
        normalizeManagedPhotoReference(
          'water_quality_photos/2026/08/photo.jpg',
        ),
        'water_quality_photos/2026/08/photo.jpg',
      );
    });

    test('拒绝绝对路径、遍历、其他 Documents 文件和目录本身', () {
      const rejected = <String>[
        '',
        ' ',
        '/water_quality_photos/photo.jpg',
        r'C:\water_quality_photos\photo.jpg',
        r'\\server\share\photo.jpg',
        'water_quality_photos',
        'water_quality_photos/',
        'water_quality_photos/../outside.jpg',
        'water_quality_photos/nested/../../outside.jpg',
        '../water_quality_photos/photo.jpg',
        'other_documents_file.jpg',
        'other_directory/photo.jpg',
        r'water_quality_photos\photo.jpg',
        'water_quality_photos//photo.jpg',
        'water_quality_photos/./photo.jpg',
        ' water_quality_photos/photo.jpg',
        'water_quality_photos/photo.jpg ',
        'water_quality_photos/photo\u0000.jpg',
      ];

      for (final value in rejected) {
        expect(
          normalizeManagedPhotoReference(value),
          isNull,
          reason: '应拒绝：$value',
        );
      }
      expect(
        normalizeManagedPhotoReference('water_quality_photos/${'a' * 500}.jpg'),
        isNull,
      );
    });
  });

  group('LocalPhotoStorage', () {
    late Directory documents;
    late LocalPhotoStorage storage;

    setUp(() async {
      documents = await Directory.systemTemp.createTemp(
        'lanjiao_local_photo_storage_',
      );
      storage = LocalPhotoStorage(
        documentsDirectoryResolver: () async => documents,
      );
    });

    tearDown(() async {
      if (await documents.exists()) {
        await documents.delete(recursive: true);
      }
    });

    test('resolve 只返回受管子目录内的文件路径', () async {
      final resolved = await storage.resolvePrivatePhoto(
        'water_quality_photos/nested/photo.jpg',
      );

      expect(
        resolved?.path,
        path.join(
          documents.path,
          'water_quality_photos',
          'nested',
          'photo.jpg',
        ),
      );
      expect(await storage.resolvePrivatePhoto('unrelated/photo.jpg'), isNull);
      expect(
        await storage.resolvePrivatePhoto(
          'water_quality_photos/../unrelated.txt',
        ),
        isNull,
      );
      expect(await storage.resolvePrivatePhoto(documents.path), isNull);
      expect(await storage.resolvePrivatePhoto('water_quality_photos'), isNull);
    });

    test('delete 仅删除受管文件且不触碰 Documents 内其他文件', () async {
      final managedDirectory = Directory(
        path.join(documents.path, 'water_quality_photos'),
      );
      await managedDirectory.create(recursive: true);
      final managedFile = File(path.join(managedDirectory.path, 'photo.jpg'));
      final unrelatedFile = File(path.join(documents.path, 'unrelated.txt'));
      await managedFile.writeAsString('managed');
      await unrelatedFile.writeAsString('keep');

      expect(
        await storage.deletePrivatePhoto('water_quality_photos/photo.jpg'),
        isTrue,
      );
      expect(await managedFile.exists(), isFalse);

      expect(await storage.deletePrivatePhoto('unrelated.txt'), isFalse);
      expect(
        await storage.deletePrivatePhoto(
          'water_quality_photos/../unrelated.txt',
        ),
        isFalse,
      );
      expect(
        await storage.deletePrivatePhoto(unrelatedFile.absolute.path),
        isFalse,
      );
      expect(await storage.deletePrivatePhoto('water_quality_photos'), isFalse);
      expect(await unrelatedFile.readAsString(), 'keep');
      expect(await managedDirectory.exists(), isTrue);
      expect(await storage.deletePrivatePhoto(null), isTrue);
    });
  });
}
