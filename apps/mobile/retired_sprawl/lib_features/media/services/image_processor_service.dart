import 'dart:io';
import 'dart:math' as math;

import 'package:archiveme_mobile/core/storage/secure_file_storage.dart';
import 'package:archiveme_mobile/storage/app_storage_paths.dart';
import 'package:archiveme_mobile/sync/ulid.dart';
import 'package:image/image.dart' as img;

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
class ImageProcessorService {
  ImageProcessorService({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? AppStoragePaths.applicationDocumentsDirectory;

  static const maxEdge = 2048;
  static const thumbnailSize = 256;
  static const jpegQuality = 80;

  final Future<Directory> Function() _documentsDirectory;

  Future<LocalMediaObject> processAndStoreImage(File rawImage) async {
    final decoded = img.decodeImage(await rawImage.readAsBytes());
    if (decoded == null) {
      throw FormatException('Could not read image at ${rawImage.path}');
    }
    final oriented = img.bakeOrientation(decoded);
    final full = _fitWithin(oriented, maxEdge);
    final thumb = img.copyResizeCropSquare(
      oriented,
      size: thumbnailSize,
      interpolation: img.Interpolation.linear,
    );

    final docs = await _documentsDirectory();
    final folder = Directory('${docs.path}/journal-images');
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
