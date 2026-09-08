import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'local_backup_service.dart';

enum MissingPhotoPolicy { reject, omit }

class CompleteBackupReport {
  const CompleteBackupReport({
    required this.file,
    required this.photoCount,
    required this.omittedPhotoPaths,
  });

  final File file;
  final int photoCount;
  final List<String> omittedPhotoPaths;
}

class CompleteBackupPreview {
  const CompleteBackupPreview({
    required this.formatVersion,
    required this.databaseFormatVersion,
    required this.createdAtUtc,
    required this.photoCount,
    required this.totalUncompressedBytes,
    required this.omittedPhotoPaths,
  });

  final int formatVersion;
  final int databaseFormatVersion;
  final DateTime createdAtUtc;
  final int photoCount;
  final int totalUncompressedBytes;
  final List<String> omittedPhotoPaths;
}

class CompleteBackupRestoreReport {
  const CompleteBackupRestoreReport({
    required this.preview,
    required this.result,
  });

  final CompleteBackupPreview preview;
  final LocalBackupRestoreResult result;
}

class CompleteBackupService {
  CompleteBackupService(
    this._jsonBackup, {
    this.maximumArchiveBytes = defaultMaximumArchiveBytes,
    this.maximumEntryBytes = defaultMaximumEntryBytes,
    this.maximumTotalUncompressedBytes = defaultMaximumTotalUncompressedBytes,
    this.maximumEntries = defaultMaximumEntries,
    this.maximumCompressionRatio = defaultMaximumCompressionRatio,
    this.missingPhotoPolicy = MissingPhotoPolicy.reject,
    Future<Directory> Function()? documentsDirectory,
    Future<Directory> Function()? supportDirectory,
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  static const formatVersion = 1;
  // ZIP decoding is currently in-memory. These limits cap the compressed
  // input and all simultaneously retained uncompressed entries on mobile.
  static const defaultMaximumArchiveBytes = 64 * 1024 * 1024;
  static const defaultMaximumEntryBytes = 16 * 1024 * 1024;
  static const defaultMaximumTotalUncompressedBytes = 96 * 1024 * 1024;
  static const defaultMaximumEntries = 1024;
  static const defaultMaximumCompressionRatio = 100;
  static const _manifestPath = 'manifest.json';
  static const _databasePath = 'database.json';
  static const _photoPrefix = 'photos/';

  final LocalBackupService _jsonBackup;
  final int maximumArchiveBytes;
  final int maximumEntryBytes;
  final int maximumTotalUncompressedBytes;
  final int maximumEntries;
  final int maximumCompressionRatio;
  final MissingPhotoPolicy missingPhotoPolicy;
  final Future<Directory> Function() _documentsDirectory;
  final Future<Directory> Function() _supportDirectory;

  Future<CompleteBackupReport> exportToPrivateFile() async {
    final json = await _jsonBackup.exportJson();
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('数据库备份格式无效');
    }
    final databaseVersion = decoded['formatVersion'];
    if (databaseVersion is! int) {
      throw const FormatException('数据库备份缺少版本');
    }
    final photoPaths = _referencedPhotoPaths(decoded);
    final documents = await _documentsDirectory();
    final documentRoot = p.normalize(documents.absolute.path);
    final archive = Archive();
    final manifestFiles = <Map<String, Object>>[];
    final omitted = <String>[];

    final databaseBytes = Uint8List.fromList(utf8.encode(json));
    _guardEntrySize(databaseBytes.length);
    var totalUncompressedBytes = databaseBytes.length;
    archive.add(ArchiveFile.bytes(_databasePath, databaseBytes));
    manifestFiles.add(_manifestFile(_databasePath, databaseBytes));

    for (final relativePath in photoPaths) {
      final source = _resolvePortablePath(documentRoot, relativePath);
      if (source == null || !await source.exists()) {
        if (missingPhotoPolicy == MissingPhotoPolicy.reject) {
          throw StateError('备份引用的照片缺失：$relativePath');
        }
        omitted.add(relativePath);
        continue;
      }
      final size = await source.length();
      _guardEntrySize(size);
      totalUncompressedBytes += size;
      if (totalUncompressedBytes > maximumTotalUncompressedBytes) {
        throw const FormatException('备份解压后体积过大');
      }
      final bytes = await source.readAsBytes();
      final archivePath = '$_photoPrefix$relativePath';
      archive.add(ArchiveFile.bytes(archivePath, bytes));
      manifestFiles.add(_manifestFile(archivePath, bytes));
    }

    final createdAt = DateTime.now().toUtc();
    final manifestBytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'lanjiao-complete-backup',
          'formatVersion': formatVersion,
          'databaseFormatVersion': databaseVersion,
          'createdAt': createdAt.toIso8601String(),
          'files': manifestFiles,
          'omittedPhotoPaths': omitted,
        }),
      ),
    );
    _guardEntrySize(manifestBytes.length);
    totalUncompressedBytes += manifestBytes.length;
    if (totalUncompressedBytes > maximumTotalUncompressedBytes) {
      throw const FormatException('备份解压后体积过大');
    }
    archive.add(ArchiveFile.bytes(_manifestPath, manifestBytes));
    if (archive.length > maximumEntries) {
      throw const FormatException('备份文件数量过多');
    }
    final zipBytes = ZipEncoder().encodeBytes(
      archive,
      level: DeflateLevel.bestSpeed,
      modified: createdAt,
    );
    if (zipBytes.length > maximumArchiveBytes) {
      throw const FormatException('备份文件过大');
    }
    final support = await _supportDirectory();
    final directory = Directory(p.join(support.path, 'backups'));
    await directory.create(recursive: true);
    final timestamp = createdAt.toIso8601String().replaceAll(':', '-');
    final target = File(
      p.join(directory.path, 'lanjiao-complete-backup-$timestamp.zip'),
    );
    await target.writeAsBytes(zipBytes, flush: true);
    return CompleteBackupReport(
      file: target,
      photoCount: manifestFiles.length - 1,
      omittedPhotoPaths: List.unmodifiable(omitted),
    );
  }

  Future<File?> latestPrivateBackup() async {
    final support = await _supportDirectory();
    final directory = Directory(p.join(support.path, 'backups'));
    if (!await directory.exists()) return null;
    final files = await directory
        .list()
        .where(
          (entity) =>
              entity is File && entity.path.toLowerCase().endsWith('.zip'),
        )
        .cast<File>()
        .toList();
    if (files.isEmpty) return null;
    files.sort((first, second) {
      return second.lastModifiedSync().compareTo(first.lastModifiedSync());
    });
    return files.first;
  }

  Future<CompleteBackupPreview> validateFile(File source) async {
    return (await _validatedArchive(source)).preview;
  }

  Future<CompleteBackupPreview> restoreMergeFromFile(File source) async {
    final validated = await _validatedArchive(source);
    final documents = await _documentsDirectory();
    final documentRoot = p.normalize(documents.absolute.path);
    var plan = await _jsonBackup.prepareMerge(validated.databaseJson);
    final omitted = validated.preview.omittedPhotoPaths.toSet();
    final overrides = <String, String?>{
      for (final transfer in plan.photoTransfers)
        if (omitted.contains(transfer.sourcePath)) transfer.sourcePath: null,
    };
    final reservedDestinations = <String>{};
    for (final transfer in plan.photoTransfers) {
      if (omitted.contains(transfer.sourcePath)) continue;
      final archivePath = '$_photoPrefix${transfer.sourcePath}';
      final manifestFile = validated.files.singleWhere(
        (item) => item.path == archivePath,
        orElse: () => throw const FormatException('待导入照片不在完整备份中'),
      );
      overrides[transfer.sourcePath] = await _safePhotoDestination(
        root: documentRoot,
        requestedPath: transfer.destinationPath,
        expectedSha256: manifestFile.sha256,
        reserved: reservedDestinations,
      );
    }
    plan = plan.withPhotoDestinations(overrides);

    // Photos referenced by rows in this exact plan are copied first with
    // exclusive creation. If the strict database transaction then fails, all
    // files created by this attempt are removed before the error is rethrown.
    final createdPhotos = <File>[];
    try {
      for (final transfer in plan.photoTransfers) {
        final archivePath = '$_photoPrefix${transfer.sourcePath}';
        final bytes = validated.entries[archivePath];
        if (bytes == null) throw const FormatException('待导入照片不在完整备份中');
        final destination = _resolvePortablePath(
          documentRoot,
          transfer.destinationPath,
        )!;
        if (await destination.exists()) continue;
        await destination.parent.create(recursive: true);
        try {
          await destination.create(exclusive: true);
          createdPhotos.add(destination);
          try {
            await destination.writeAsBytes(bytes, flush: true);
          } catch (_) {
            if (await destination.exists()) await destination.delete();
            createdPhotos.remove(destination);
            rethrow;
          }
        } on FileSystemException {
          if (!await destination.exists()) rethrow;
          final digest = sha256
              .convert(await destination.readAsBytes())
              .toString();
          final manifestFile = validated.files.singleWhere(
            (item) => item.path == archivePath,
          );
          if (digest != manifestFile.sha256) rethrow;
        }
      }
      await _jsonBackup.restorePreparedMerge(plan);
      return validated.preview;
    } catch (error, stackTrace) {
      Object? cleanupError;
      for (final file in createdPhotos.reversed) {
        try {
          if (await file.exists()) await file.delete();
        } on Object catch (cleanupFailure) {
          cleanupError ??= cleanupFailure;
        }
      }
      if (cleanupError != null) {
        throw StateError('恢复失败，且本次新复制照片未能全部回滚');
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Restores one authoritative, data-only snapshot. Historical archives may
  /// still contain photos and are fully integrity-checked, but photo files and
  /// references are deliberately ignored by LocalBackupService v7.
  Future<CompleteBackupRestoreReport> restoreReplaceFromFile(
    File source,
  ) async {
    final validated = await _validatedArchive(source);
    final result = await _jsonBackup.restoreReplace(validated.databaseJson);
    return CompleteBackupRestoreReport(
      preview: validated.preview,
      result: result,
    );
  }

  Future<String> _safePhotoDestination({
    required String root,
    required String requestedPath,
    required String expectedSha256,
    required Set<String> reserved,
  }) async {
    var candidate = requestedPath;
    for (var suffix = 0; suffix < 10000; suffix++) {
      if (suffix > 0) {
        final extension = p.posix.extension(requestedPath);
        candidate = p.posix.join(
          'water_quality_photos',
          'restored-${expectedSha256.substring(0, 16)}-$suffix$extension',
        );
      }
      if (!reserved.add(candidate)) continue;
      final file = _resolvePortablePath(root, candidate);
      if (file == null) throw const FormatException('备份照片路径无效');
      if (!await file.exists()) return candidate;
      final digest = sha256.convert(await file.readAsBytes()).toString();
      if (digest == expectedSha256) return candidate;
      reserved.remove(candidate);
    }
    throw StateError('无法为恢复照片生成无冲突路径');
  }

  Future<CompleteBackupPreview> restoreLatestPrivateBackupReplace() async {
    final file = await latestPrivateBackup();
    if (file == null) throw StateError('尚无完整本地备份');
    return (await restoreReplaceFromFile(file)).preview;
  }

  Future<_ValidatedCompleteBackup> _validatedArchive(File source) async {
    final archiveSize = await source.length();
    if (archiveSize <= 0 || archiveSize > maximumArchiveBytes) {
      throw const FormatException('备份文件大小无效');
    }
    late final Archive archive;
    late final ZipDecoder decoder;
    try {
      decoder = ZipDecoder();
      archive = decoder.decodeBytes(await source.readAsBytes(), verify: true);
    } on Object {
      throw const FormatException('ZIP 备份无法解析或 CRC 校验失败');
    }
    if (archive.isEmpty || archive.length > maximumEntries) {
      throw const FormatException('ZIP 备份条目数无效');
    }
    if (decoder.directory.fileHeaders.length != archive.length) {
      throw const FormatException('ZIP 内含重复路径');
    }
    final entries = <String, Uint8List>{};
    var totalBytes = 0;
    for (var index = 0; index < archive.length; index++) {
      final entry = archive[index];
      final header = decoder.directory.fileHeaders[index];
      if (!entry.isFile || entry.isSymbolicLink) {
        throw const FormatException('ZIP 不允许目录或链接条目');
      }
      final name = _safeArchivePath(entry.name);
      if (entries.containsKey(name)) {
        throw const FormatException('ZIP 内含重复路径');
      }
      if (header.diskNumberStart != 0 ||
          (header.generalPurposeBitFlag & 0x0001) != 0 ||
          (header.compressionMethod != 0 && header.compressionMethod != 8)) {
        throw const FormatException('ZIP 条目使用了不支持或不安全的格式');
      }
      if (entry.size < 0 ||
          entry.size != header.uncompressedSize ||
          entry.size > maximumEntryBytes) {
        throw const FormatException('备份中的单个文件过大');
      }
      if (entry.size > 0 &&
          (header.compressedSize <= 0 ||
              entry.size > header.compressedSize * maximumCompressionRatio)) {
        throw const FormatException('ZIP 压缩比异常');
      }
      totalBytes += entry.size;
      if (totalBytes > maximumTotalUncompressedBytes) {
        throw const FormatException('备份解压后体积过大');
      }
      final bytes = entry.readBytes();
      if (bytes == null || bytes.length != entry.size) {
        throw FormatException('ZIP 条目大小校验失败：$name');
      }
      if (entry.crc32 != null && getCrc32(bytes) != entry.crc32) {
        throw FormatException('ZIP 条目 CRC 校验失败：$name');
      }
      entries[name] = bytes;
    }

    final manifestBytes = entries[_manifestPath];
    final databaseBytes = entries[_databasePath];
    if (manifestBytes == null || databaseBytes == null) {
      throw const FormatException('完整备份缺少清单或数据库文件');
    }
    final manifest = _decodeManifest(manifestBytes);
    final listedPaths = manifest.files.map((item) => item.path).toSet();
    if (listedPaths.length != manifest.files.length ||
        !listedPaths.contains(_databasePath) ||
        listedPaths.contains(_manifestPath)) {
      throw const FormatException('完整备份清单条目无效');
    }
    final actualPaths = entries.keys
        .where((path) => path != _manifestPath)
        .toSet();
    if (actualPaths.length != listedPaths.length ||
        !actualPaths.containsAll(listedPaths)) {
      throw const FormatException('ZIP 条目与完整性清单不一致');
    }
    for (final file in manifest.files) {
      final bytes = entries[file.path]!;
      if (bytes.length != file.size ||
          sha256.convert(bytes).toString() != file.sha256) {
        throw FormatException('备份 SHA-256 校验失败：${file.path}');
      }
      if (file.path != _databasePath && !file.path.startsWith(_photoPrefix)) {
        throw FormatException('备份清单包含未知路径：${file.path}');
      }
    }
    final databaseJson = _decodeUtf8(databaseBytes, '数据库 JSON');
    await _jsonBackup.validateJson(databaseJson);
    final databaseMap = jsonDecode(databaseJson) as Map<String, dynamic>;
    if (databaseMap['formatVersion'] != manifest.databaseFormatVersion) {
      throw const FormatException('清单与数据库备份版本不一致');
    }
    final referenced = _referencedPhotoPaths(databaseMap);
    final archivedPhotos = manifest.files
        .where((file) => file.path.startsWith(_photoPrefix))
        .map((file) => file.path.substring(_photoPrefix.length))
        .toSet();
    final omitted = manifest.omittedPhotoPaths.toSet();
    if (referenced.any(
          (path) => !archivedPhotos.contains(path) && !omitted.contains(path),
        ) ||
        archivedPhotos.any((path) => !referenced.contains(path)) ||
        omitted.any((path) => !referenced.contains(path)) ||
        archivedPhotos.any(omitted.contains)) {
      throw const FormatException('照片条目与数据库引用不一致');
    }

    return _ValidatedCompleteBackup(
      databaseJson: databaseJson,
      entries: Map.unmodifiable(entries),
      files: manifest.files,
      preview: CompleteBackupPreview(
        formatVersion: formatVersion,
        databaseFormatVersion: manifest.databaseFormatVersion,
        createdAtUtc: manifest.createdAtUtc,
        photoCount: archivedPhotos.length,
        totalUncompressedBytes: totalBytes,
        omittedPhotoPaths: manifest.omittedPhotoPaths,
      ),
    );
  }

  _Manifest _decodeManifest(Uint8List bytes) {
    final decoded = jsonDecode(_decodeUtf8(bytes, '完整备份清单'));
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'lanjiao-complete-backup' ||
        decoded['formatVersion'] != formatVersion ||
        decoded['databaseFormatVersion'] is! int ||
        decoded['createdAt'] is! String ||
        decoded['files'] is! List ||
        decoded['omittedPhotoPaths'] is! List) {
      throw const FormatException('完整备份清单格式无效');
    }
    final createdAt = DateTime.tryParse(decoded['createdAt'] as String);
    if (createdAt == null || !createdAt.isUtc) {
      throw const FormatException('完整备份时间无效');
    }
    final files = <_ManifestFile>[];
    for (final item in decoded['files'] as List) {
      if (item is! Map<String, dynamic> ||
          item['path'] is! String ||
          item['size'] is! int ||
          item['sha256'] is! String) {
        throw const FormatException('完整备份清单文件条目无效');
      }
      final path = _safeArchivePath(item['path'] as String);
      final size = item['size'] as int;
      final digest = item['sha256'] as String;
      if (size < 0 ||
          size > maximumEntryBytes ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
        throw const FormatException('完整备份清单校验值无效');
      }
      files.add(_ManifestFile(path: path, size: size, sha256: digest));
    }
    final omitted = <String>[];
    for (final item in decoded['omittedPhotoPaths'] as List) {
      if (item is! String) throw const FormatException('省略照片清单无效');
      _safeRelativePhotoPath(item);
      omitted.add(item);
    }
    if (omitted.toSet().length != omitted.length) {
      throw const FormatException('省略照片清单重复');
    }
    return _Manifest(
      databaseFormatVersion: decoded['databaseFormatVersion'] as int,
      createdAtUtc: createdAt,
      files: List.unmodifiable(files),
      omittedPhotoPaths: List.unmodifiable(omitted),
    );
  }

  Map<String, Object> _manifestFile(String path, Uint8List bytes) => {
    'path': path,
    'size': bytes.length,
    'sha256': sha256.convert(bytes).toString(),
  };

  void _guardEntrySize(int size) {
    if (size < 0 || size > maximumEntryBytes) {
      throw const FormatException('备份中的单个文件过大');
    }
  }
}

class _ValidatedCompleteBackup {
  const _ValidatedCompleteBackup({
    required this.databaseJson,
    required this.entries,
    required this.files,
    required this.preview,
  });

  final String databaseJson;
  final Map<String, Uint8List> entries;
  final List<_ManifestFile> files;
  final CompleteBackupPreview preview;
}

class _Manifest {
  const _Manifest({
    required this.databaseFormatVersion,
    required this.createdAtUtc,
    required this.files,
    required this.omittedPhotoPaths,
  });

  final int databaseFormatVersion;
  final DateTime createdAtUtc;
  final List<_ManifestFile> files;
  final List<String> omittedPhotoPaths;
}

class _ManifestFile {
  const _ManifestFile({
    required this.path,
    required this.size,
    required this.sha256,
  });

  final String path;
  final int size;
  final String sha256;
}

Set<String> _referencedPhotoPaths(Map<String, dynamic> database) {
  final paths = <String>{};
  for (final tableAndField in const [
    ('testRecords', 'photoPath'),
    ('activeTestSessions', 'draftPhotoPath'),
  ]) {
    final items = database[tableAndField.$1];
    if (items is! List) {
      throw FormatException('数据库备份缺少 ${tableAndField.$1}');
    }
    for (final item in items) {
      if (item is! Map<String, dynamic>) {
        throw FormatException('${tableAndField.$1} 数据无效');
      }
      final value = item[tableAndField.$2];
      if (value == null) continue;
      if (value is! String) throw const FormatException('备份照片路径无效');
      paths.add(_safeRelativePhotoPath(value));
    }
  }
  return paths;
}

File? _resolvePortablePath(String root, String relativePath) {
  try {
    final safePath = _safeRelativePhotoPath(relativePath);
    final candidate = p.normalize(
      p.joinAll(<String>[root, ...safePath.split('/')]),
    );
    if (!p.isWithin(root, candidate)) return null;
    return File(candidate);
  } on FormatException {
    return null;
  }
}

String _safeRelativePhotoPath(String value) {
  final normalized = _safeArchivePath(value);
  if (normalized != value || !normalized.startsWith('water_quality_photos/')) {
    throw const FormatException('备份照片路径无效');
  }
  return normalized;
}

String _safeArchivePath(String value) {
  if (value.isEmpty ||
      value.length > 512 ||
      value.startsWith('/') ||
      value.startsWith('\\') ||
      value.endsWith('/') ||
      value.contains('\\') ||
      value.contains('\u0000') ||
      RegExp(r'^[A-Za-z]:').hasMatch(value)) {
    throw const FormatException('ZIP 内含不安全路径');
  }
  final parts = value.split('/');
  if (parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw const FormatException('ZIP 内含不安全路径');
  }
  return value;
}

String _decodeUtf8(Uint8List bytes, String label) {
  try {
    return utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    throw FormatException('$label 不是有效 UTF-8');
  }
}
