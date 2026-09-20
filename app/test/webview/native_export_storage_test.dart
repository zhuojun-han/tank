import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/webview/native_export_storage.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'sharing copies rotate without deleting recovery or unrelated files',
    () async {
      final support = await Directory.systemTemp.createTemp('native-exports-');
      try {
        final storage = NativeExportStorage(
          supportDirectory: () async => support,
        );
        final legacy = File(
          p.join(support.path, 'backups', 'user-recovery.zip'),
        );
        await legacy.parent.create(recursive: true);
        await legacy.writeAsString('preserve');
        final root = await storage.directory();
        for (final (folder, prefix, suffix) in [
          ('backups', 'lanjiao-complete-backup-', '.zip'),
          ('exports', 'lanjiao-test-records-', '.csv'),
        ]) {
          final directory = Directory(p.join(root.path, folder));
          await directory.create(recursive: true);
          final unrelated = File(p.join(directory.path, 'other$suffix'));
          await unrelated.writeAsString('preserve');
          final files = <File>[];
          for (var i = 0; i < 4; i++) {
            final file = File(p.join(directory.path, '$prefix$i$suffix'));
            await file.writeAsString('$i');
            await file.setLastModified(DateTime.utc(2026, 9, 12, 0, i));
            files.add(file);
            await storage.retainRecent(file);
          }
          expect(await files[0].exists(), isFalse);
          expect(await files[1].exists(), isFalse);
          expect(await files[2].readAsString(), '2');
          expect(await files[3].readAsString(), '3');
          expect(await unrelated.readAsString(), 'preserve');
        }
        await expectLater(storage.retainRecent(legacy), throwsFormatException);
        expect(await legacy.readAsString(), 'preserve');
      } finally {
        await support.delete(recursive: true);
      }
    },
  );
}
