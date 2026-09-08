import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

typedef DocumentsDirectoryResolver = Future<Directory> Function();

class LocalPhotoStorage {
  const LocalPhotoStorage({
    DocumentsDirectoryResolver? documentsDirectoryResolver,
  }) : this._(documentsDirectoryResolver);

  const LocalPhotoStorage._(this._documentsDirectoryResolver);

  static const managedDirectoryName = 'water_quality_photos';

  final DocumentsDirectoryResolver? _documentsDirectoryResolver;

  Future<File?> resolvePrivatePhoto(String storedPath) async {
    final relativePath = normalizeManagedPhotoReference(storedPath);
    if (relativePath == null) return null;

    final documents =
        await (_documentsDirectoryResolver?.call() ??
            getApplicationDocumentsDirectory());
    final documentsRoot = path.normalize(documents.absolute.path);
    final managedRoot = path.normalize(
      path.join(documentsRoot, managedDirectoryName),
    );
    final candidate = path.normalize(
      path.joinAll([documentsRoot, ...path.posix.split(relativePath)]),
    );
    // Keep the containment check even after validating the portable
    // reference. It is the final guard before this path reaches dart:io.
    // `isWithin` also rejects the managed directory itself.
    if (!path.isWithin(managedRoot, candidate)) return null;
    return File(candidate);
  }

  Future<bool> deletePrivatePhoto(String? storedPath) async {
    if (storedPath == null) return true;
    final file = await resolvePrivatePhoto(storedPath);
    if (file == null) return false;
    try {
      if (await file.exists()) await file.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }
}

/// Validates the portable path stored in the database.
///
/// Only canonical relative references below `water_quality_photos/` are
/// accepted. Requiring the persisted POSIX form keeps backups portable and
/// prevents absolute paths, traversal segments, alternate separators and
/// references to unrelated files in the application Documents directory from
/// reaching [File].
String? normalizeManagedPhotoReference(String storedPath) {
  if (storedPath.isEmpty ||
      storedPath.length > 512 ||
      storedPath.trim() != storedPath ||
      storedPath.contains('\u0000')) {
    return null;
  }
  if (path.posix.isAbsolute(storedPath) ||
      path.windows.isAbsolute(storedPath) ||
      storedPath.contains(r'\')) {
    return null;
  }

  final segments = path.posix.split(storedPath);
  if (segments.length < 2 ||
      segments.first != LocalPhotoStorage.managedDirectoryName ||
      segments.any(
        (segment) => segment.isEmpty || segment == '.' || segment == '..',
      )) {
    return null;
  }

  final normalized = path.posix.normalize(storedPath);
  return normalized == storedPath ? normalized : null;
}
