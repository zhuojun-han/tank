import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/backup/complete_backup_service.dart';
import 'package:lanjiao_water_quality/data/backup/local_backup_service.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/aquarium/data/fish_stock_repository.dart';
import 'package:lanjiao_water_quality/features/aquarium/domain/fish_stock.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory root;
  late Directory documents;
  late Directory support;
  late AppDatabase database;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('lanjiao-backup-test-');
    documents = Directory('${root.path}${Platform.pathSeparator}documents');
    support = Directory('${root.path}${Platform.pathSeparator}support');
    await documents.create(recursive: true);
    await support.create(recursive: true);
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  CompleteBackupService serviceFor(AppDatabase db) => CompleteBackupService(
    LocalBackupService(db),
    documentsDirectory: () async => documents,
    supportDirectory: () async => support,
  );

  CompleteBackupService serviceWith(LocalBackupService backup) =>
      CompleteBackupService(
        backup,
        documentsDirectory: () async => documents,
        supportDirectory: () async => support,
      );

  test('新完整 ZIP 只包含结构化数据，恢复记录但不导出或复制照片', () async {
    final photo = File(
      '${documents.path}${Platform.pathSeparator}water_quality_photos'
      '${Platform.pathSeparator}sample.jpg',
    );
    await photo.parent.create(recursive: true);
    await photo.writeAsBytes(<int>[1, 2, 3, 4, 5]);
    final now = DateTime.utc(2026, 8, 12, 3, 4, 5);
    await database
        .into(database.testRecords)
        .insert(
          TestRecordsCompanion.insert(
            id: 'photo-record',
            tankId: AppDatabase.defaultTankId,
            parameterId: AppDatabase.no3Id,
            confirmedMinValue: 5,
            unit: 'mg/L',
            measuredAt: now,
            confirmedAt: Value(now),
            photoPath: const Value('water_quality_photos/sample.jpg'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await FishStockRepository(database).replaceForTank(
      tankId: AppDatabase.defaultTankId,
      items: [
        FishStockItem(
          id: 'backup-fish',
          tankId: AppDatabase.defaultTankId,
          species: '自定义鱼',
          quantity: 2,
          introducedOn: DateTime.utc(2026, 8, 12),
          artworkKind: FishArtworkKind.custom,
          artworkMimeType: 'image/webp',
          artworkBase64: base64Encode([1, 2, 3, 4]),
        ),
      ],
    );

    final report = await serviceFor(database).exportToPrivateFile();
    expect(report.photoCount, 0);
    expect(report.omittedPhotoPaths, isEmpty);
    final preview = await serviceFor(database).validateFile(report.file);
    expect(preview.databaseFormatVersion, LocalBackupService.formatVersion);
    expect(preview.photoCount, 0);
    final archive = ZipDecoder().decodeBytes(await report.file.readAsBytes());
    expect(archive.map((entry) => entry.name).toSet(), {
      'database.json',
      'manifest.json',
    });

    final restored = AppDatabase(NativeDatabase.memory());
    addTearDown(restored.close);
    await serviceFor(restored).restoreReplaceFromFile(report.file);
    final record = (await restored.select(restored.testRecords).get()).single;
    expect(record.id, 'photo-record');
    expect(record.photoPath, isNull);
    final fish = await FishStockRepository(
      restored,
    ).watchForTank(AppDatabase.defaultTankId).first;
    expect(fish.single.species, '自定义鱼');
    expect(fish.single.customArtworkBytes, [1, 2, 3, 4]);
    expect(await photo.readAsBytes(), <int>[1, 2, 3, 4, 5]);
  });

  test('清单 SHA-256 被篡改时在恢复前拒绝且不写数据库', () async {
    final report = await serviceFor(database).exportToPrivateFile();
    final archive = ZipDecoder().decodeBytes(await report.file.readAsBytes());
    final rewritten = Archive();
    for (final entry in archive) {
      final bytes = entry.readBytes()!;
      if (entry.name != 'manifest.json') {
        rewritten.add(ArchiveFile.bytes(entry.name, bytes));
        continue;
      }
      final manifest = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final files = manifest['files'] as List;
      final database =
          files.firstWhere(
                (item) =>
                    (item as Map<String, dynamic>)['path'] == 'database.json',
              )
              as Map<String, dynamic>;
      database['sha256'] = List.filled(64, '0').join();
      rewritten.add(ArchiveFile.string('manifest.json', jsonEncode(manifest)));
    }
    final tampered = File('${root.path}${Platform.pathSeparator}tampered.zip');
    await tampered.writeAsBytes(ZipEncoder().encodeBytes(rewritten));

    final restored = AppDatabase(NativeDatabase.memory());
    addTearDown(restored.close);
    await expectLater(
      serviceFor(restored).restoreReplaceFromFile(tampered),
      throwsFormatException,
    );
    expect(await restored.select(restored.testRecords).get(), isEmpty);
  });

  test('ZIP 中的 zip-slip 路径在解压前被拒绝', () async {
    final unsafeArchive = Archive()
      ..add(ArchiveFile.string('../outside.txt', 'unsafe'));
    final unsafe = File('${root.path}${Platform.pathSeparator}unsafe.zip');
    await unsafe.writeAsBytes(ZipEncoder().encodeBytes(unsafeArchive));

    await expectLater(
      serviceFor(database).validateFile(unsafe),
      throwsFormatException,
    );
    expect(
      await File(
        '${root.parent.path}${Platform.pathSeparator}outside.txt',
      ).exists(),
      isFalse,
    );
  });

  test('旧完整备份仍校验照片，但权威恢复只保留结构化数据', () async {
    final photo = await _insertPhotoRecord(database, documents);
    final report = await _createLegacyPhotoArchive(
      database: database,
      photo: photo,
      output: File('${root.path}${Platform.pathSeparator}legacy.zip'),
    );
    await photo.writeAsBytes(<int>[9, 9, 9], flush: true);

    final restored = AppDatabase(NativeDatabase.memory());
    addTearDown(restored.close);
    final preview = await serviceFor(restored).validateFile(report);
    expect(preview.databaseFormatVersion, 5);
    expect(preview.photoCount, 1);
    await serviceFor(restored).restoreReplaceFromFile(report);

    expect(await photo.readAsBytes(), <int>[9, 9, 9]);
    final record = await restored.select(restored.testRecords).getSingle();
    expect(record.id, 'photo-record');
    expect(record.photoPath, isNull);
  });

  test('数据库恢复失败时不会修改或复制旧备份照片', () async {
    final photo = await _insertPhotoRecord(database, documents);
    final report = await _createLegacyPhotoArchive(
      database: database,
      photo: photo,
      output: File('${root.path}${Platform.pathSeparator}legacy-failing.zip'),
    );

    final restored = AppDatabase(NativeDatabase.memory());
    addTearDown(restored.close);
    final failingBackup = _FailingLocalBackupService(restored);
    await expectLater(
      serviceWith(failingBackup).restoreReplaceFromFile(report),
      throwsStateError,
    );

    expect(await photo.readAsBytes(), <int>[1, 2, 3, 4, 5]);
    expect(await restored.select(restored.testRecords).get(), isEmpty);
  });

  test('权威恢复删除本机额外记录并精确采用备份数据', () async {
    await _insertPhotoRecord(database, documents);
    final report = await serviceFor(database).exportToPrivateFile();
    final restored = AppDatabase(NativeDatabase.memory());
    addTearDown(restored.close);
    final now = DateTime.utc(2026, 8, 14);
    await restored
        .into(restored.testRecords)
        .insert(
          TestRecordsCompanion.insert(
            id: 'local-only',
            tankId: AppDatabase.defaultTankId,
            parameterId: AppDatabase.no3Id,
            confirmedMinValue: 99,
            unit: 'mg/L',
            measuredAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await serviceFor(restored).restoreReplaceFromFile(report.file);

    final records = await restored.select(restored.testRecords).get();
    expect(records.map((item) => item.id), ['photo-record']);
    expect(records.single.photoPath, isNull);
  });
}

Future<File> _createLegacyPhotoArchive({
  required AppDatabase database,
  required File photo,
  required File output,
}) async {
  final decoded =
      jsonDecode(await LocalBackupService(database).exportJson())
          as Map<String, dynamic>;
  decoded['formatVersion'] = 5;
  ((decoded['testRecords'] as List).single
          as Map<String, dynamic>)['photoPath'] =
      'water_quality_photos/sample.jpg';
  final databaseBytes = utf8.encode(jsonEncode(decoded));
  final photoBytes = await photo.readAsBytes();
  final files = <Map<String, Object>>[
    _manifestEntry('database.json', databaseBytes),
    _manifestEntry('photos/water_quality_photos/sample.jpg', photoBytes),
  ];
  final manifestBytes = utf8.encode(
    jsonEncode({
      'format': 'lanjiao-complete-backup',
      'formatVersion': 1,
      'databaseFormatVersion': 5,
      'createdAt': DateTime.utc(2026, 8, 13).toIso8601String(),
      'files': files,
      'omittedPhotoPaths': <String>[],
    }),
  );
  final archive = Archive()
    ..add(ArchiveFile.bytes('database.json', databaseBytes))
    ..add(
      ArchiveFile.bytes('photos/water_quality_photos/sample.jpg', photoBytes),
    )
    ..add(ArchiveFile.bytes('manifest.json', manifestBytes));
  await output.writeAsBytes(ZipEncoder().encodeBytes(archive), flush: true);
  return output;
}

Map<String, Object> _manifestEntry(String path, List<int> bytes) => {
  'path': path,
  'size': bytes.length,
  'sha256': sha256.convert(bytes).toString(),
};

Future<File> _insertPhotoRecord(
  AppDatabase database,
  Directory documents,
) async {
  final photo = File(
    '${documents.path}${Platform.pathSeparator}water_quality_photos'
    '${Platform.pathSeparator}sample.jpg',
  );
  await photo.parent.create(recursive: true);
  await photo.writeAsBytes(<int>[1, 2, 3, 4, 5], flush: true);
  final now = DateTime.utc(2026, 8, 13, 3, 4, 5);
  await database
      .into(database.testRecords)
      .insert(
        TestRecordsCompanion.insert(
          id: 'photo-record',
          tankId: AppDatabase.defaultTankId,
          parameterId: AppDatabase.no3Id,
          confirmedMinValue: 5,
          unit: 'mg/L',
          measuredAt: now,
          confirmedAt: Value(now),
          photoPath: const Value('water_quality_photos/sample.jpg'),
          createdAt: now,
          updatedAt: now,
        ),
      );
  return photo;
}

class _FailingLocalBackupService extends LocalBackupService {
  _FailingLocalBackupService(super.database);

  @override
  Future<LocalBackupRestoreResult> restoreReplace(String source) async {
    throw StateError('simulated database failure');
  }
}
