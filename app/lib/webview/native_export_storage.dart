import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Bounded sharing copies. Existing backups and pre-restore recovery archives
/// stay in their original directory and are never included in this rotation.
class NativeExportStorage {
  NativeExportStorage({Future<Directory> Function()? supportDirectory})
    : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _supportDirectory;

  Future<Directory> directory() async {
    final support = await _supportDirectory();
    return Directory(p.join(support.path, 'webview-share-cache'));
  }

  /// Call within the platform's exclusive file operation, before sharing.
  /// No subsequent export can rotate files while the share dialog is open.
  Future<void> retainRecent(File latest) async {
    final root = p.normalize((await directory()).absolute.path);
    final path = p.normalize(latest.absolute.path);
    final folder = p.basename(p.dirname(path));
    final (prefix, suffix) = switch (folder) {
      'backups' => ('lanjiao-complete-backup-', '.zip'),
      'exports' => ('lanjiao-test-records-', '.csv'),
      _ => throw const FormatException('导出缓存路径无效。'),
    };
    bool generated(String name) =>
        name.startsWith(prefix) && name.endsWith(suffix);
    if (p.dirname(path) != p.join(root, folder) ||
        !generated(p.basename(path))) {
      throw const FormatException('不能清理导出缓存以外的文件。');
    }
    final previous = <(File, DateTime)>[];
    await for (final entry in latest.parent.list(followLinks: false)) {
      if (entry is File &&
          p.normalize(entry.absolute.path) != path &&
          generated(p.basename(entry.path))) {
        previous.add((entry, await entry.lastModified()));
      }
    }
    previous.sort((a, b) => b.$2.compareTo(a.$2));
    // Keep the newly generated file and its immediately previous copy.
    for (final (file, _) in previous.skip(1)) {
      await file.delete();
    }
  }
}
