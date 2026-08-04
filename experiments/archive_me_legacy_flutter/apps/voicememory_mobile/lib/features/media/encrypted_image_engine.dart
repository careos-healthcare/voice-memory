import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;
import 'package:uuid/uuid.dart';

import '../../services/local_storage/encrypted_storage_engine.dart';
import '../../services/security/biometric_vault_service.dart';
import 'media_attachment.dart';
import 'media_picker_gateway.dart';

class EncryptedImageException implements Exception {
  const EncryptedImageException(this.message);

  final String message;

  @override
  String toString() => 'EncryptedImageException: $message';
}

typedef MediaAttachmentIdFactory = String Function();

/// Imports images without ever writing a plaintext derivative to disk.
class EncryptedImageEngine {
  EncryptedImageEngine({
    required Directory storageDirectory,
    required BiometricVaultService vault,
    EncryptedStorageEngine? storageEngine,
    MediaAttachmentIdFactory? idFactory,
    DateTime Function()? clock,
    this.fullImageMaxDimension = 2560,
    this.thumbnailMaxDimension = 320,
    this.fullImageJpegQuality = 88,
    this.thumbnailJpegQuality = 72,
  }) : // Public named parameters cannot initialize private fields directly.
       // ignore: prefer_initializing_formals
       _storageDirectory = storageDirectory,
       // ignore: prefer_initializing_formals
       _vault = vault,
       _storageEngine = storageEngine ?? EncryptedStorageEngine(),
       _idFactory = idFactory ?? const Uuid().v4,
       _clock = clock ?? DateTime.now;

  final Directory _storageDirectory;
  final BiometricVaultService _vault;
  final EncryptedStorageEngine _storageEngine;
  final MediaAttachmentIdFactory _idFactory;
  final DateTime Function() _clock;

  final int fullImageMaxDimension;
  final int thumbnailMaxDimension;
  final int fullImageJpegQuality;
  final int thumbnailJpegQuality;

  Future<MediaAttachment?> pickAndImport({
    required MediaPickerGateway picker,
    required MediaPickSource source,
  }) async {
    final picked = await picker.pickImage(source);
    return picked == null ? null : importPickedSource(picked);
  }

  Future<MediaAttachment> importPickedSource(PickedMediaSource source) async {
    final sourceFile = File(source.path);
    Uint8List? sourceBytes;
    Uint8List? fullJpeg;
    Uint8List? thumbnailJpeg;
    MediaAttachment? attachment;
    final id = _idFactory();
    final fullFile = File('${_storageDirectory.path}/$id.full.vault');
    final thumbnailFile = File('${_storageDirectory.path}/$id.thumb.vault');

    try {
      // This is deliberately the only read of the picker-provided source.
      sourceBytes = await sourceFile.readAsBytes();
      image.Image? decoded;
      try {
        decoded = image.decodeImage(sourceBytes);
      } on Object {
        throw const EncryptedImageException('The selected image is invalid.');
      }
      if (decoded == null) {
        throw const EncryptedImageException('The selected image is invalid.');
      }
      final oriented = image.bakeOrientation(decoded);
      final full = _resizeToFit(oriented, fullImageMaxDimension);
      final thumbnail = _resizeToFit(oriented, thumbnailMaxDimension);
      fullJpeg = Uint8List.fromList(
        image.encodeJpg(full, quality: fullImageJpegQuality),
      );
      thumbnailJpeg = Uint8List.fromList(
        image.encodeJpg(thumbnail, quality: thumbnailJpegQuality),
      );

      await _vault.withUnlockedKey((key) async {
        await _storageEngine.writeFile(
          fullFile,
          fullJpeg!,
          keyBytes: key,
          associatedData: _aad(id, _ImageVariant.full),
        );
        await _storageEngine.writeFile(
          thumbnailFile,
          thumbnailJpeg!,
          keyBytes: key,
          associatedData: _aad(id, _ImageVariant.thumbnail),
        );
      });

      attachment = MediaAttachment(
        id: id,
        kind: MediaAttachmentKind.image,
        localPath: fullFile.path,
        fileSize: await fullFile.length(),
        encryptedThumbnailPath: thumbnailFile.path,
        encryptedHash: await _encryptedFileHash(fullFile),
        encryptedThumbnailSha256: await _encryptedFileHash(thumbnailFile),
        width: full.width,
        height: full.height,
        createdAt: _clock(),
      );
      return attachment;
    } finally {
      _zero(sourceBytes);
      _zero(fullJpeg);
      _zero(thumbnailJpeg);
      if (attachment == null) {
        await _deleteIfPresent(fullFile);
        await _deleteIfPresent(thumbnailFile);
      }
      if (source.cleanupOwnership ==
          MediaSourceCleanupOwnership.appOwnedTemporary) {
        await _deleteIfPresent(sourceFile);
      }
    }
  }

  /// Imports an already-compressed JPEG received in memory.
  ///
  /// The caller retains ownership of [jpegBytes]. No plaintext derivative is
  /// written to disk; the full JPEG and generated thumbnail are vault-encrypted.
  Future<MediaAttachment> importBytes(
    Uint8List jpegBytes, {
    required String attachmentId,
    required DateTime createdAt,
    String mimeType = 'image/jpeg',
    String caption = '',
  }) async {
    if (mimeType != 'image/jpeg') {
      throw const EncryptedImageException('Only JPEG media can be imported.');
    }
    final fullFile = File('${_storageDirectory.path}/$attachmentId.full.vault');
    final thumbnailFile = File(
      '${_storageDirectory.path}/$attachmentId.thumb.vault',
    );
    Uint8List? thumbnailJpeg;
    MediaAttachment? attachment;

    try {
      image.Image? decoded;
      try {
        decoded = image.decodeJpg(jpegBytes);
      } on Object {
        throw const EncryptedImageException('The received image is invalid.');
      }
      if (decoded == null) {
        throw const EncryptedImageException('The received image is invalid.');
      }
      final oriented = image.bakeOrientation(decoded);
      final thumbnail = _resizeToFit(oriented, thumbnailMaxDimension);
      thumbnailJpeg = Uint8List.fromList(
        image.encodeJpg(thumbnail, quality: thumbnailJpegQuality),
      );

      await _vault.withUnlockedKey((key) async {
        await _storageEngine.writeFile(
          fullFile,
          jpegBytes,
          keyBytes: key,
          associatedData: _aad(attachmentId, _ImageVariant.full),
        );
        await _storageEngine.writeFile(
          thumbnailFile,
          thumbnailJpeg!,
          keyBytes: key,
          associatedData: _aad(attachmentId, _ImageVariant.thumbnail),
        );
      });

      attachment = MediaAttachment(
        id: attachmentId,
        kind: MediaAttachmentKind.image,
        localPath: fullFile.path,
        fileSize: await fullFile.length(),
        encryptedThumbnailPath: thumbnailFile.path,
        encryptedHash: await _encryptedFileHash(fullFile),
        encryptedThumbnailSha256: await _encryptedFileHash(thumbnailFile),
        width: oriented.width,
        height: oriented.height,
        createdAt: createdAt,
        mimeType: mimeType,
        caption: caption,
      );
      return attachment;
    } finally {
      _zero(thumbnailJpeg);
      if (attachment == null) {
        await _deleteIfPresent(fullFile);
        await _deleteIfPresent(thumbnailFile);
      }
    }
  }

  /// Normalizes an in-memory share-extension image before vault encryption.
  ///
  /// No plaintext file is created. The normalized JPEG buffer is wiped after
  /// [importBytes] has encrypted the full image and thumbnail.
  Future<MediaAttachment> importEncodedBytes(
    Uint8List encodedBytes, {
    required String attachmentId,
    required DateTime createdAt,
    String caption = '',
  }) async {
    Uint8List? jpegBytes;
    try {
      image.Image? decoded;
      try {
        decoded = image.decodeImage(encodedBytes);
      } on Object {
        throw const EncryptedImageException('The shared image is invalid.');
      }
      if (decoded == null) {
        throw const EncryptedImageException('The shared image is invalid.');
      }
      final oriented = image.bakeOrientation(decoded);
      final full = _resizeToFit(oriented, fullImageMaxDimension);
      jpegBytes = Uint8List.fromList(
        image.encodeJpg(full, quality: fullImageJpegQuality),
      );
      return await importBytes(
        jpegBytes,
        attachmentId: attachmentId,
        createdAt: createdAt,
        caption: caption,
      );
    } finally {
      _zero(jpegBytes);
    }
  }

  Future<T> withDecryptedFullImage<T>(
    MediaAttachment attachment,
    Future<T> Function(Uint8List jpegBytes) operation,
  ) {
    return _withDecrypted(attachment, _ImageVariant.full, operation);
  }

  Future<T> withDecryptedThumbnail<T>(
    MediaAttachment attachment,
    Future<T> Function(Uint8List jpegBytes) operation,
  ) {
    return _withDecrypted(attachment, _ImageVariant.thumbnail, operation);
  }

  Future<void> delete(MediaAttachment attachment) async {
    await _deleteIfPresent(File(attachment.encryptedFilePath));
    await _deleteIfPresent(File(attachment.encryptedThumbnailPath));
  }

  Future<void> clearAll() async {
    if (!await _storageDirectory.exists()) return;
    await for (final entity in _storageDirectory.list()) {
      if (entity is File &&
          (entity.path.endsWith('.full.vault') ||
              entity.path.endsWith('.thumb.vault'))) {
        await _deleteIfPresent(entity);
      }
    }
  }

  Future<T> _withDecrypted<T>(
    MediaAttachment attachment,
    _ImageVariant variant,
    Future<T> Function(Uint8List jpegBytes) operation,
  ) async {
    final file = File(
      variant == _ImageVariant.full
          ? attachment.encryptedFilePath
          : attachment.encryptedThumbnailPath,
    );
    final expectedHash = variant == _ImageVariant.full
        ? attachment.encryptedFileSha256
        : attachment.encryptedThumbnailSha256;
    final actualHash = await _encryptedFileHash(file);
    if (!_constantTimeEquals(expectedHash, actualHash)) {
      throw const EncryptedImageException(
        'Encrypted image integrity check failed.',
      );
    }

    return _vault.withUnlockedKey((key) async {
      Uint8List? clear;
      try {
        clear = await _storageEngine.readFile(
          file,
          keyBytes: key,
          associatedData: _aad(attachment.id, variant),
        );
        return await operation(clear);
      } finally {
        _zero(clear);
      }
    });
  }

  image.Image _resizeToFit(image.Image source, int maxDimension) {
    final largest = source.width > source.height ? source.width : source.height;
    if (largest <= maxDimension) return source.clone();
    final scale = maxDimension / largest;
    return image.copyResize(
      source,
      width: (source.width * scale).round(),
      height: (source.height * scale).round(),
      interpolation: image.Interpolation.average,
    );
  }

  Future<String> _encryptedFileHash(File file) async {
    final bytes = await file.readAsBytes();
    try {
      return sha256.convert(bytes).toString();
    } finally {
      _zero(bytes);
    }
  }

  List<int> _aad(String attachmentId, _ImageVariant variant) {
    return utf8.encode('voicememory:media:v1:$attachmentId:${variant.name}');
  }

  bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }
    return difference == 0;
  }

  void _zero(Uint8List? bytes) {
    bytes?.fillRange(0, bytes.length, 0);
  }

  Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) await file.delete();
  }
}

enum _ImageVariant { full, thumbnail }
