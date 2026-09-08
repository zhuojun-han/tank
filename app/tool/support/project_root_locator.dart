import 'dart:io';

import 'package:path/path.dart' as path;

/// Locates the repository root without relying on the process working directory.
///
/// Flutter commands for this project can run from an ASCII-only directory
/// junction that points at `app/`. Resolving every starting directory before
/// walking upwards lets the locator reach the real repository in that case.
Future<Directory> locateProjectRoot() async {
  final startingDirectories = <Directory>[
    Directory.current,
    if (Platform.script.scheme == 'file')
      Directory(
        path.dirname(Platform.script.toFilePath(windows: Platform.isWindows)),
      ),
  ];
  final visited = <String>{};

  for (final start in startingDirectories) {
    final candidates = <Directory>[start.absolute];
    try {
      candidates.add(Directory(await start.resolveSymbolicLinks()));
    } on FileSystemException {
      // A script URI can point at a transient test location. The other start
      // and the unresolved path are still valid candidates.
    }

    for (final candidate in candidates) {
      var current = candidate;
      while (true) {
        final normalized = path.normalize(current.absolute.path);
        if (visited.add(normalized) && _hasProjectLayout(current)) {
          return current;
        }

        final parent = current.parent;
        if (path.equals(parent.path, current.path)) break;
        current = parent;
      }
    }
  }

  throw StateError('无法定位项目根目录：需要同时存在 app/pubspec.yaml 和 datasets/no3');
}

bool _hasProjectLayout(Directory directory) {
  return File(path.join(directory.path, 'app', 'pubspec.yaml')).existsSync() &&
      Directory(path.join(directory.path, 'datasets', 'no3')).existsSync();
}
