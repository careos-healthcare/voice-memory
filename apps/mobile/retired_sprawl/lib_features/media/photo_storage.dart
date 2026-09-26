import 'dart:io';

/// How much space journal photos take, and how to drop leftover originals.
abstract final class PhotoStorage {
  PhotoStorage._();

  static int bytesUsed(Directory root) {
    if (!root.existsSync()) return 0;
    var total = 0;
    for (final entity in root.listSync(recursive: true)) {
      if (entity is File) total += entity.lengthSync();
    }
    return total;
  }

  static bool hasOriginals(Directory root) {
    if (!root.existsSync()) return false;
    for (final entity in root.listSync(recursive: true)) {
      if (entity is File && _isOriginal(entity.path)) return true;
    }
    return false;
  }

  /// Deletes leftover full-quality files. The downscaled copy and its
  /// thumbnail stay.
  static int removeOriginalQualityCopies(Directory root) {
    if (!root.existsSync()) return 0;
    var freed = 0;
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !_isOriginal(entity.path)) continue;
      freed += entity.lengthSync();
      entity.deleteSync();
    }
    return freed;
  }

  static String labelFor(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static bool _isOriginal(String path) {
    final name = path.split(RegExp(r'[/\\]')).last.toLowerCase();
    return name == 'original.jpg' || name.endsWith('_original.jpg');
  }
}
