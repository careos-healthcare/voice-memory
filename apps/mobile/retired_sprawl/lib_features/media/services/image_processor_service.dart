import 'dart:io';
import 'dart:math' as math;

import 'package:archiveme_mobile/core/storage/secure_file_storage.dart';
import 'package:archiveme_mobile/storage/app_storage_paths.dart';
import 'package:archiveme_mobile/sync/ulid.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Paths for a stored journal photo and its preview.
class LocalMediaObject {
  const LocalMediaObject({
    required this.highResPath,
    required this.thumbnailPath,
  });

  final String highResPath;
  final String thumbnailPath;
}

/// Shrinks a photo so the archive keeps a readable copy and a small preview.
///
/// Files land in application support at `photos/<entryId>/`. GPS is dropped
/// unless the caller is keeping location.
class ImageProcessorService {
  ImageProcessorService({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? AppStoragePaths.applicationSupportDirectory;

  static const maxEdge = 2048;
  static const thumbnailSize = 400;

  /// 0.85 on the JPEG 0–100 scale.
  static const jpegQuality = 85;

  static const photosFolderName = 'photos';

  /// Preview written beside [highResPath] by [processAndStoreImage].
  static String thumbnailPathFor(String highResPath) {
    if (highResPath.endsWith('_thumb.jpg')) return highResPath;
    final slash = highResPath.lastIndexOf('/');
    final dot = highResPath.lastIndexOf('.');
    if (dot <= slash) return '${highResPath}_thumb.jpg';
    return '${highResPath.substring(0, dot)}_thumb${highResPath.substring(dot)}';
  }

  /// The 400px preview when it is on disk, otherwise the stored photo.
  static String previewPath(String highResPath) {
    final thumb = thumbnailPathFor(highResPath);
    if (thumb != highResPath && File(thumb).existsSync()) return thumb;
    return highResPath;
  }

  static Directory photosRoot(Directory support) =>
      Directory('${support.path}/$photosFolderName');

  static Directory entryDirectory(Directory support, String entryId) =>
      Directory('${photosRoot(support).path}/${_safeId(entryId)}');

  final Future<Directory> Function() _documentsDirectory;

  Future<LocalMediaObject> processAndStoreImage(
    File rawImage, {
    String? entryId,
    bool keepGps = false,
  }) async {
    final decoded = img.decodeImage(await rawImage.readAsBytes());
    if (decoded == null) {
      throw FormatException('Could not read image at ${rawImage.path}');
    }
    final oriented = img.bakeOrientation(decoded);
    final gps = oriented.exif.imageIfd.sub.directories['gps']?.clone();
    final full = _fitWithin(oriented, maxEdge);
    final fittedThumb = _fitWithin(oriented, thumbnailSize);
    final thumb = identical(fittedThumb, full)
        ? img.copyResize(fittedThumb, width: fittedThumb.width)
        : fittedThumb;
    if (keepGps && gps != null) {
      full.exif.imageIfd.sub.directories['gps'] = gps;
    } else {
      full.exif.imageIfd.sub.directories.remove('gps');
    }
    thumb.exif.imageIfd.sub.directories.remove('gps');

    final support = await _documentsDirectory();
    final owner = (entryId == null || entryId.trim().isEmpty)
        ? '_inbox'
        : _safeId(entryId);
    final folder = Directory('${photosRoot(support).path}/$owner');
    await folder.create(recursive: true);
    final id = generateUlid();
    final highResPath = '${folder.path}/$id.jpg';
    final thumbnailPath = '${folder.path}/${id}_thumb.jpg';

    await SecureFileStorage.writeImage(
      path: highResPath,
      bytes: img.encodeJpg(full, quality: jpegQuality),
    );
    await SecureFileStorage.writeImage(
      path: thumbnailPath,
      bytes: img.encodeJpg(thumb, quality: jpegQuality),
    );
    return LocalMediaObject(
      highResPath: highResPath,
      thumbnailPath: thumbnailPath,
    );
  }

  /// Moves a stored photo into `photos/<entryId>/` once the entry exists.
  static Future<String> adoptIntoEntry(
    String path,
    String entryId, {
    Directory? supportDirectory,
  }) async {
    final file = File(path);
    final safe = _safeId(entryId);
    if (safe.isEmpty) return path;
    final parent = file.parent;
    final photos = parent.parent;
    final Directory destDir;
    if (p.basename(photos.path) == photosFolderName) {
      destDir = Directory('${photos.path}/$safe');
    } else if (supportDirectory != null) {
      destDir = entryDirectory(supportDirectory, safe);
    } else {
      return path;
    }
    if (parent.path == destDir.path) return path;
    await destDir.create(recursive: true);
    final target = File('${destDir.path}/${p.basename(path)}');
    if (file.existsSync()) {
      await _moveFile(file, target);
    }
    final thumb = File(thumbnailPathFor(path));
    if (thumb.existsSync()) {
      await _moveFile(thumb, File(thumbnailPathFor(target.path)));
    }
    return target.path;
  }

  static Future<void> _moveFile(File from, File to) async {
    try {
      await from.rename(to.path);
    } on FileSystemException {
      await to.writeAsBytes(await from.readAsBytes());
      if (from.existsSync()) await from.delete();
    }
  }

  static String _safeId(String entryId) =>
      entryId.trim().replaceAll(RegExp(r'[/\\]'), '');

  img.Image _fitWithin(img.Image source, int maxEdge) {
    final longest = math.max(source.width, source.height);
    if (longest <= maxEdge) return source;
    if (source.width >= source.height) {
      return img.copyResize(
        source,
        width: maxEdge,
        interpolation: img.Interpolation.linear,
      );
    }
    return img.copyResize(
      source,
      height: maxEdge,
      interpolation: img.Interpolation.linear,
    );
  }
}
