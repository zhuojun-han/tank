import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  test('伪造小尺寸的 ZIP 在解压输出越界时立即拒绝', () async {
    final archive = Archive()
      ..add(ArchiveFile.bytes('database.json', Uint8List(8192)));
    final bytes = Uint8List.fromList(ZipEncoder().encodeBytes(archive));
    final data = ByteData.sublistView(bytes);
    for (var offset = 0; offset <= bytes.length - 30; offset++) {
      final signature = data.getUint32(offset, Endian.little);
      if (signature == 0x04034b50) {
        data.setUint32(offset + 22, 8, Endian.little);
      } else if (signature == 0x02014b50) {
        data.setUint32(offset + 24, 8, Endian.little);
      }
    }
    final file = File('${root.path}/undersized-header.zip');
    await file.writeAsBytes(bytes);
    await expectLater(
      serviceFor(database).validateFile(file),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('解压输出'),
        ),
      ),
    );
    expect(await database.select(database.testRecords).get(), isEmpty);
  });

  test('链接条目在解压其无效内容之前拒绝', () async {
    final archive = Archive()
      ..add(ArchiveFile.bytes('database.json', Uint8List.fromList([0xff])));
    final bytes = Uint8List.fromList(ZipEncoder().encodeBytes(archive));
    final data = ByteData.sublistView(bytes);
    for (var offset = 0; offset <= bytes.length - 46; offset++) {
      if (data.getUint32(offset, Endian.little) == 0x02014b50) {
        data.setUint16(offset + 4, (3 << 8) | 20, Endian.little);
        data.setUint32(offset + 38, 0xa000 << 16, Endian.little);
        break;
      }
    }
    final file = File('${root.path}/symlink.zip');
    await file.writeAsBytes(bytes);
    await expectLater(
      serviceFor(database).validateFile(file),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('目录或链接'),
        ),
      ),
    );
  });

  test('合法的小型 ZIP64 完整备份继续兼容', () async {
    final report = await serviceFor(database).exportToPrivateFile();
    final original = await report.file.readAsBytes();
    final footer = original.length - 22;
    final originalData = ByteData.sublistView(original);
    final count = originalData.getUint16(footer + 10, Endian.little);
    final directorySize = originalData.getUint32(footer + 12, Endian.little);
    final directoryOffset = originalData.getUint32(footer + 16, Endian.little);
    final zip64 = ByteData(56)
      ..setUint32(0, 0x06064b50, Endian.little)
      ..setUint64(4, 44, Endian.little)
      ..setUint16(12, 45, Endian.little)
      ..setUint16(14, 45, Endian.little)
      ..setUint64(24, count, Endian.little)
      ..setUint64(32, count, Endian.little)
      ..setUint64(40, directorySize, Endian.little)
      ..setUint64(48, directoryOffset, Endian.little);
    final locator = ByteData(20)
      ..setUint32(0, 0x07064b50, Endian.little)
      ..setUint64(8, footer, Endian.little)
      ..setUint32(16, 1, Endian.little);
    final end = Uint8List.fromList(original.sublist(footer));
    ByteData.sublistView(end)
      ..setUint16(6, 0xffff, Endian.little)
      ..setUint16(8, 0xffff, Endian.little)
      ..setUint16(10, 0xffff, Endian.little)
      ..setUint32(12, 0xffffffff, Endian.little)
      ..setUint32(16, 0xffffffff, Endian.little);
    final file = File('${root.path}/compatible-zip64.zip');
    await file.writeAsBytes([
      ...original.sublist(0, footer),
      ...zip64.buffer.asUint8List(),
      ...locator.buffer.asUint8List(),
      ...end,
    ]);
    final preview = await serviceFor(database).validateFile(file);
    expect(preview.databaseFormatVersion, LocalBackupService.formatVersion);
    expect(preview.photoCount, 0);
  });

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
    await database
        .update(database.tanks)
        .write(
          const TanksCompanion(
            startedOn: Value('2000-02-29'),
            volumeLiters: Value(120.5),
          ),
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
    final tank = await restored.select(restored.tanks).getSingle();
    expect(tank.startedOn, '2000-02-29');
    expect(tank.volumeLiters, 120.5);
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
