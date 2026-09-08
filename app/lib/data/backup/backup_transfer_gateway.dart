import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

enum BackupShareStatus { success, dismissed, unavailable }

abstract interface class BackupTransferGateway {
  /// Opens the platform picker for a single complete `.zip` backup.
  /// Returns `null` when the user cancels.
  Future<File?> pickCompleteBackup();

  Future<BackupShareStatus> shareCompleteBackup(File file);

  Future<BackupShareStatus> shareCsv(File file);
}

class FlutterBackupTransferGateway implements BackupTransferGateway {
  const FlutterBackupTransferGateway();

  static const _backupTypes = <XTypeGroup>[
    XTypeGroup(
      label: '澜礁完整数据备份',
      extensions: <String>['zip'],
      mimeTypes: <String>['application/zip'],
      uniformTypeIdentifiers: <String>['public.zip-archive'],
    ),
  ];

  @override
  Future<File?> pickCompleteBackup() async {
    final selected = await openFile(acceptedTypeGroups: _backupTypes);
    return selected == null ? null : File(selected.path);
  }

  @override
  Future<BackupShareStatus> shareCompleteBackup(File file) {
    return _share(file, 'application/zip', '澜礁完整数据备份');
  }

  @override
  Future<BackupShareStatus> shareCsv(File file) {
    return _share(file, 'text/csv', '澜礁检测记录 CSV');
  }

  Future<BackupShareStatus> _share(
    File file,
    String mimeType,
    String title,
  ) async {
    if (!await file.exists()) throw StateError('待分享文件不存在');
    final result = await SharePlus.instance.share(
      ShareParams(
        title: title,
        subject: title,
        files: <XFile>[XFile(file.path, mimeType: mimeType)],
      ),
    );
    return switch (result.status) {
      ShareResultStatus.success => BackupShareStatus.success,
      ShareResultStatus.dismissed => BackupShareStatus.dismissed,
      ShareResultStatus.unavailable => BackupShareStatus.unavailable,
    };
  }
}
