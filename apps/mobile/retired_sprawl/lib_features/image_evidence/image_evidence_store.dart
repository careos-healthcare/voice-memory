import 'dart:io';

import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Persists image-evidence blobs under the app documents directory.
abstract final class ImageEvidenceStore {
  ImageEvidenceStore._();

  static const _uuid = Uuid();

  static Future<String> imagesRoot() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/image_evidence');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  static Future<ImageEvidence> persist({
    required File sourceFile,
    required String caption,
    String source = 'gallery',
    String? mimeType,
  }) async {
    final bytes = await sourceFile.readAsBytes();
    final hash = sha256.convert(bytes).toString();
    final evidenceId = _uuid.v4();
    final ext = _extensionForMime(mimeType ?? 'image/jpeg');
    final root = await imagesRoot();
    final destPath = '$root/$evidenceId$ext';
    await sourceFile.copy(destPath);

    return ImageEvidence(
      evidenceId: evidenceId,
      caption: caption.trim(),
      mimeType: mimeType ?? 'image/jpeg',
      attachedAt: DateTime.now().toUtc(),
      filename: sourceFile.uri.pathSegments.lastOrNull,
      byteLength: bytes.length,
      contentHash: hash,
      source: source,
      localPath: destPath,
    );
  }

  static Future<File?> openBlob(ImageEvidence evidence) async {
    final path = evidence.localPath;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file;
  }

  static String _extensionForMime(String mime) {
    return switch (mime) {
      'image/png' => '.png',
      'image/webp' => '.webp',
      'image/heic' || 'image/heif' => '.heic',
      _ => '.jpg',
    };
  }
}