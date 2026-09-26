import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/sync/record_sync.dart';
import 'package:flutter/foundation.dart';

/// A short-lived permission to upload or download one encrypted file.
class SignedObjectGrant {
  const SignedObjectGrant({required this.url, this.headers = const {}});

  final Uri url;
  final Map<String, String> headers;
}

/// Encrypts each audio or image file into 4 MB chunks and stores only those
/// bytes in object storage.
class AttachmentSyncService {
  AttachmentSyncService({
    required List<int> accountKey,
    required this.sign,
    required this.putBytes,
    required this.getBytes,
  }) : _accountKey = accountKey;

  final List<int> _accountKey;
  final Future<SignedObjectGrant> Function({
    required String entryId,
    required String name,
    required String method,
  })
  sign;
  final Future<void> Function(SignedObjectGrant grant, List<int> body) putBytes;
  final Future<List<int>> Function(SignedObjectGrant grant) getBytes;

  @visibleForTesting
  static Future<void> Function(JournalEntry entry)? debugRestore;

  static const audioExtension = '.m4a';
  static const imageExtensions = {'.jpg', '.jpeg', '.png', '.heic', '.webp'};

  static AttachmentSyncService? active;

  /// Restores missing media when an entry is opened.
  static Future<void> restoreIfConfigured(JournalEntry entry) async {
    final hook = debugRestore;
    if (hook != null) return hook(entry);
    final service = active;
    if (service == null || !V1CapabilityRegistry.e2eeSync) return;
    await service.restoreMissingMedia(entry);
  }

  Future<void> uploadEntryAttachments(JournalEntry entry) async {
    for (final path in mediaPaths(entry)) {
      final file = File(path);
      if (!file.existsSync()) continue;
      await _upload(entry.id, file);
    }
  }

  /// Downloads missing chunk objects, decrypts them, and writes the file.
  Future<bool> ensureLocalFile({
    required String entryId,
    required String path,
  }) async {
    final file = File(path);
    if (file.existsSync() && file.lengthSync() > 0) return false;
    final name = _name(path);
    final chunks = <SealedMediaChunk>[];
    for (var index = 0; index < 1024; index++) {
      try {
        final grant = await sign(
          entryId: entryId,
          name: '$name-$index',
          method: 'GET',
        );
        final body = await getBytes(grant);
        chunks.add(
          SealedMediaChunk.fromObjectBytes(
            blobId: '$name-$index',
            index: index,
            objectBytes: body,
          ),
        );
      } on Object {
        break;
      }
    }
    if (chunks.isEmpty) {
      throw StateError('Encrypted attachment was missing.');
    }
    final clear = await RecordSync.openMedia(
      accountKey: _accountKey,
      chunks: chunks,
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(clear, flush: true);
    return true;
  }

  Future<void> restoreMissingMedia(JournalEntry entry) async {
    for (final path in mediaPaths(entry)) {
      final file = File(path);
      if (file.existsSync() && file.lengthSync() > 0) continue;
      await ensureLocalFile(entryId: entry.id, path: path);
    }
  }

  static List<String> mediaPaths(JournalEntry entry) {
    final paths = <String>[];
    final audio = entry.localAudioPath?.trim() ?? '';
    if (_isMedia(audio)) paths.add(audio);
    for (final image in entry.images) {
      final trimmed = image.trim();
      if (_isMedia(trimmed)) paths.add(trimmed);
    }
    return paths;
  }

  Future<void> _upload(String entryId, File file) async {
    final chunks = await RecordSync.sealMedia(
      accountKey: _accountKey,
      bytes: await file.readAsBytes(),
      blobPrefix: _name(file.path),
    );
    for (final chunk in chunks) {
      final grant = await sign(
        entryId: entryId,
        name: chunk.blobId,
        method: 'PUT',
      );
      await putBytes(grant, chunk.objectBytes);
    }
  }

  static bool _isMedia(String path) {
    if (path.isEmpty) return false;
    final lower = path.toLowerCase();
    if (lower.endsWith(audioExtension)) return true;
    return imageExtensions.any(lower.endsWith);
  }

  static String _name(String path) {
    final slash = path.lastIndexOf(Platform.pathSeparator);
    if (slash < 0) return path;
    return path.substring(slash + 1);
  }
}
