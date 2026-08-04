import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../models/journal_entry.dart';
import '../sync/e2ee_sync_models.dart';
import '../sync/encrypted_sync_engine.dart';
import 'encrypted_image_engine.dart';
import 'media_attachment.dart';

class MediaSyncException implements Exception {
  const MediaSyncException(this.message);

  final String message;

  @override
  String toString() => 'MediaSyncException: $message';
}

typedef ImportedMediaCallback =
    Future<void> Function(
      String ownerKind,
      String ownerId,
      MediaAttachment attachment,
    );

/// Produces portable, shared-key-encrypted CRDT operations from local media.
class MediaSyncCoordinator {
  MediaSyncCoordinator({
    required EncryptedSyncEngine syncEngine,
    required EncryptedImageEngine imageEngine,
    this.chunkSize = maxChunkSize,
  }) : // Public named parameters cannot initialize private fields directly.
       // ignore: prefer_initializing_formals
       _syncEngine = syncEngine,
       // ignore: prefer_initializing_formals
       _imageEngine = imageEngine {
    if (chunkSize <= 0 || chunkSize > maxChunkSize) {
      throw ArgumentError.value(chunkSize, 'chunkSize');
    }
  }

  static const int maxChunkSize = 256 * 1024;
  static const int maxChunkCount = 4096;

  final EncryptedSyncEngine _syncEngine;
  final EncryptedImageEngine _imageEngine;
  final int chunkSize;
  final Set<String> _sentAttachmentIds = {};

  Future<int> enqueueAttachment({
    required String journalEntryId,
    required MediaAttachment attachment,
  }) => _enqueueAttachment(
    ownerKind: 'journalEntry',
    ownerId: journalEntryId,
    attachment: attachment,
  );

  Future<int> enqueueGraphNodeAttachment({
    required String nodeId,
    required MediaAttachment attachment,
  }) => _enqueueAttachment(
    ownerKind: 'graphNode',
    ownerId: nodeId,
    attachment: attachment,
  );

  Future<int> _enqueueAttachment({
    required String ownerKind,
    required String ownerId,
    required MediaAttachment attachment,
  }) async {
    if (_syncEngine.isApplyingRemote) return 0;
    if (!_sentAttachmentIds.add(attachment.id)) return 0;
    try {
      return await _imageEngine.withDecryptedFullImage(attachment, (
        jpegBytes,
      ) async {
        if (jpegBytes.isEmpty) {
          throw const MediaSyncException('Media cannot be empty.');
        }
        final chunkCount = (jpegBytes.length + chunkSize - 1) ~/ chunkSize;
        if (chunkCount > maxChunkCount) {
          throw const MediaSyncException('Media exceeds the chunk limit.');
        }
        final plainHash = sha256.convert(jpegBytes).toString();
        await _syncEngine.record(
          entityKind: CrdtEntityKind.mediaManifest,
          entityId: attachment.id,
          mutation: CrdtMutation.upsert,
          payload: {
            'version': 1,
            'attachmentId': attachment.id,
            'ownerKind': ownerKind,
            'ownerId': ownerId,
            'kind': attachment.kind.name,
            'mimeType': attachment.mimeType,
            'caption': attachment.caption,
            'width': attachment.width,
            'height': attachment.height,
            'createdAt': attachment.createdAt.toIso8601String(),
            'byteLength': jpegBytes.length,
            'chunkCount': chunkCount,
            'plainSha256': plainHash,
          },
        );

        for (var index = 0; index < chunkCount; index++) {
          final start = index * chunkSize;
          final end = start + chunkSize < jpegBytes.length
              ? start + chunkSize
              : jpegBytes.length;
          final chunk = Uint8List.fromList(jpegBytes.sublist(start, end));
          try {
            await _syncEngine.record(
              entityKind: CrdtEntityKind.mediaChunk,
              entityId: '${attachment.id}:$index',
              mutation: CrdtMutation.upsert,
              payload: {
                'version': 1,
                'attachmentId': attachment.id,
                'index': index,
                'chunkCount': chunkCount,
                'byteLength': chunk.length,
                'bytes': base64Encode(chunk),
              },
            );
          } finally {
            _zero(chunk);
          }
        }
        return chunkCount;
      });
    } catch (_) {
      _sentAttachmentIds.remove(attachment.id);
      rethrow;
    }
  }

  Future<void> enqueueEntries(Iterable<JournalEntry> entries) async {
    for (final entry in entries) {
      for (final attachment in entry.mediaAttachments) {
        await enqueueAttachment(
          journalEntryId: entry.id,
          attachment: attachment,
        );
      }
    }
  }
}

/// Reassembles chunks only in memory and imports the JPEG into the local vault.
class MediaSyncAssembler {
  MediaSyncAssembler({
    required EncryptedImageEngine imageEngine,
    ImportedMediaCallback? onImported,
  }) : // Public named parameters cannot initialize private fields directly.
       // ignore: prefer_initializing_formals
       _imageEngine = imageEngine,
       // ignore: prefer_initializing_formals
       _onImported = onImported;

  final EncryptedImageEngine _imageEngine;
  final ImportedMediaCallback? _onImported;
  final Map<String, _IncomingMedia> _incoming = {};

  Future<MediaAttachment?> apply(CrdtOperation operation) async {
    if (operation.entityKind != CrdtEntityKind.mediaManifest &&
        operation.entityKind != CrdtEntityKind.mediaChunk) {
      throw const MediaSyncException('Unsupported media operation.');
    }
    if (operation.mutation == CrdtMutation.delete) {
      _discard(operation.entityId.split(':').first);
      return null;
    }
    return operation.entityKind == CrdtEntityKind.mediaManifest
        ? _applyManifest(operation.payload)
        : _applyChunk(operation.payload);
  }

  Future<MediaAttachment?> _applyManifest(Map<String, dynamic> payload) async {
    final manifest = _MediaManifest.parse(payload);
    final state = _incoming.putIfAbsent(
      manifest.attachmentId,
      () => _IncomingMedia(manifest.chunkCount),
    );
    if (state.chunkCount != manifest.chunkCount) {
      _reject(manifest.attachmentId, 'Chunk count does not match manifest.');
    }
    state.manifest = manifest;
    return _tryAssemble(manifest.attachmentId, state);
  }

  Future<MediaAttachment?> _applyChunk(Map<String, dynamic> payload) async {
    final attachmentId = _requiredString(payload, 'attachmentId');
    final index = _requiredInt(payload, 'index');
    final chunkCount = _requiredInt(payload, 'chunkCount');
    final declaredLength = _requiredInt(payload, 'byteLength');
    if (chunkCount <= 0 || chunkCount > MediaSyncCoordinator.maxChunkCount) {
      throw const MediaSyncException('Invalid chunk count.');
    }
    if (index < 0 || index >= chunkCount) {
      throw const MediaSyncException('Invalid chunk index.');
    }
    Uint8List bytes;
    try {
      bytes = base64Decode(_requiredString(payload, 'bytes'));
    } on FormatException {
      throw const MediaSyncException('Chunk is not valid base64.');
    }
    if (bytes.isEmpty ||
        bytes.length > MediaSyncCoordinator.maxChunkSize ||
        bytes.length != declaredLength) {
      _zero(bytes);
      throw const MediaSyncException('Invalid chunk size.');
    }

    final state = _incoming.putIfAbsent(
      attachmentId,
      () => _IncomingMedia(chunkCount),
    );
    if (state.chunkCount != chunkCount) {
      _zero(bytes);
      _reject(attachmentId, 'Chunk count changed during transfer.');
    }
    final existing = state.chunks[index];
    if (existing != null) {
      final duplicateMatches = _constantTimeEquals(existing, bytes);
      _zero(bytes);
      if (!duplicateMatches) {
        _reject(attachmentId, 'Duplicate chunk content does not match.');
      }
    } else {
      state.chunks[index] = bytes;
    }
    return _tryAssemble(attachmentId, state);
  }

  Future<MediaAttachment?> _tryAssemble(
    String attachmentId,
    _IncomingMedia state,
  ) async {
    final manifest = state.manifest;
    if (manifest == null || state.chunks.length != state.chunkCount) {
      return null;
    }
    final totalLength = state.chunks.values.fold<int>(
      0,
      (total, chunk) => total + chunk.length,
    );
    if (totalLength != manifest.byteLength) {
      _reject(attachmentId, 'Assembled media length does not match manifest.');
    }

    final assembled = Uint8List(totalLength);
    var offset = 0;
    try {
      for (var index = 0; index < state.chunkCount; index++) {
        final chunk = state.chunks[index];
        if (chunk == null) {
          _reject(attachmentId, 'A media chunk is missing.');
        }
        assembled.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      if (!_constantTimeStringEquals(
        sha256.convert(assembled).toString(),
        manifest.plainSha256,
      )) {
        throw const MediaSyncException('Plaintext media hash does not match.');
      }
      final attachment = await _imageEngine.importBytes(
        assembled,
        attachmentId: manifest.attachmentId,
        createdAt: manifest.createdAt,
        mimeType: manifest.mimeType,
        caption: manifest.caption,
      );
      if (attachment.width != manifest.width ||
          attachment.height != manifest.height) {
        await _imageEngine.delete(attachment);
        throw const MediaSyncException('Media dimensions do not match.');
      }
      try {
        await _onImported?.call(
          manifest.ownerKind,
          manifest.ownerId,
          attachment,
        );
      } catch (_) {
        await _imageEngine.delete(attachment);
        rethrow;
      }
      return attachment;
    } finally {
      _zero(assembled);
      _discard(attachmentId);
    }
  }

  Never _reject(String attachmentId, String message) {
    _discard(attachmentId);
    throw MediaSyncException(message);
  }

  void _discard(String attachmentId) {
    final state = _incoming.remove(attachmentId);
    if (state == null) return;
    for (final chunk in state.chunks.values) {
      _zero(chunk);
    }
    state.chunks.clear();
  }
}

class _MediaManifest {
  const _MediaManifest({
    required this.attachmentId,
    required this.ownerKind,
    required this.ownerId,
    required this.mimeType,
    required this.caption,
    required this.width,
    required this.height,
    required this.createdAt,
    required this.byteLength,
    required this.chunkCount,
    required this.plainSha256,
  });

  final String attachmentId;
  final String ownerKind;
  final String ownerId;
  final String mimeType;
  final String caption;
  final int width;
  final int height;
  final DateTime createdAt;
  final int byteLength;
  final int chunkCount;
  final String plainSha256;

  factory _MediaManifest.parse(Map<String, dynamic> payload) {
    final attachmentId = _requiredString(payload, 'attachmentId');
    final ownerKind = payload['ownerKind'] is String
        ? (payload['ownerKind'] as String).trim()
        : 'journalEntry';
    final ownerId = payload['ownerId'] is String
        ? (payload['ownerId'] as String).trim()
        : _requiredString(payload, 'journalEntryId');
    final mimeType = _requiredString(payload, 'mimeType');
    final caption = payload['caption'] is String
        ? (payload['caption'] as String).trim()
        : '';
    final kind = _requiredString(payload, 'kind');
    final width = _requiredInt(payload, 'width');
    final height = _requiredInt(payload, 'height');
    final byteLength = _requiredInt(payload, 'byteLength');
    final chunkCount = _requiredInt(payload, 'chunkCount');
    final hash = _requiredString(payload, 'plainSha256');
    final createdAt = DateTime.tryParse(_requiredString(payload, 'createdAt'));
    if ((ownerKind != 'journalEntry' && ownerKind != 'graphNode') ||
        ownerId.isEmpty ||
        kind != MediaAttachmentKind.image.name ||
        mimeType != 'image/jpeg' ||
        width <= 0 ||
        height <= 0 ||
        byteLength <= 0 ||
        chunkCount <= 0 ||
        chunkCount > MediaSyncCoordinator.maxChunkCount ||
        hash.length != 64 ||
        createdAt == null) {
      throw const MediaSyncException('Invalid media manifest.');
    }
    return _MediaManifest(
      attachmentId: attachmentId,
      ownerKind: ownerKind,
      ownerId: ownerId,
      mimeType: mimeType,
      caption: caption,
      width: width,
      height: height,
      createdAt: createdAt.toUtc(),
      byteLength: byteLength,
      chunkCount: chunkCount,
      plainSha256: hash,
    );
  }
}

class _IncomingMedia {
  _IncomingMedia(this.chunkCount);

  final int chunkCount;
  final Map<int, Uint8List> chunks = {};
  _MediaManifest? manifest;
}

String _requiredString(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value is! String || value.isEmpty) {
    throw MediaSyncException('Missing $key.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value is! num || value.toInt() != value) {
    throw MediaSyncException('Invalid $key.');
  }
  return value.toInt();
}

bool _constantTimeEquals(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

bool _constantTimeStringEquals(String left, String right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
  }
  return difference == 0;
}

void _zero(Uint8List bytes) => bytes.fillRange(0, bytes.length, 0);
