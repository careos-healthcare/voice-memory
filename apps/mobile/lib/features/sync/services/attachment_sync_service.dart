import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/sync/services/entry_encryption_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter/foundation.dart';

/// A short-lived permission to upload or download one encrypted file.
class SignedObjectGrant {
  const SignedObjectGrant({required this.url, this.headers = const {}});

  final Uri url;
  final Map<String, String> headers;
}

/// Encrypts each audio or image file, then stores only the ciphertext.
class AttachmentSyncService {
  AttachmentSyncService({
    required EntryEncryptionService encryption,
    required this.sign,
    required this.putBytes,
    required this.getBytes,
  }) : _encryption = encryption;

  final EntryEncryptionService _encryption;
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

  /// Downloads a missing local file, decrypts it, and writes it beside the entry.
  Future<bool> ensureLocalFile({
    required String entryId,
    required String path,
  }) async {
    final file = File(path);
    if (file.existsSync() && file.lengthSync() > 0) return false;
    final name = _name(path);
    final grant = await sign(entryId: entryId, name: name, method: 'GET');
    final body = await getBytes(grant);
    final decoded = jsonDecode(utf8.decode(body));
    if (decoded is! Map) {
      throw const FormatException('Encrypted attachment was not an object.');
    }
    final clear = await _encryption.decryptBytes(
      nonce: decoded['nonce'] as String,
      ciphertext: decoded['ciphertext'] as String,
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
    final sealed = await _encryption.encryptBytes(await file.readAsBytes());
    final body = utf8.encode(
      jsonEncode({
        'version': EntryEncryptionService.version,
        'nonce': sealed.nonce,
        'ciphertext': sealed.ciphertext,
      }),
    );
    final grant = await sign(
      entryId: entryId,
      name: _name(file.path),
      method: 'PUT',
    );
    await putBytes(grant, body);
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
