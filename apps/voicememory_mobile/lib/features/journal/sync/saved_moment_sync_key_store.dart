import 'dart:convert';
import 'dart:math';

import '../../../storage/secure_storage.dart';

/// Device-protected, account-scoped key boundary for encrypted journal sync.
///
/// The server never receives this key. Until a user-controlled recovery-key
/// exchange exists, another device cannot decrypt this device's cloud copy.
final class SavedMomentSyncKeyStore {
  SavedMomentSyncKeyStore(this._secure);

  final SecureStorageService _secure;

  Future<List<int>> requireKey(String ownerArchiveId) async {
    final normalized = ownerArchiveId.trim();
    if (normalized.isEmpty) {
      throw StateError('Encrypted sync requires an authenticated archive.');
    }
    final storageKey = 'saved_moment_sync_key_v1:$normalized';
    final existing = await _secure.read(storageKey);
    if (existing != null && existing.isNotEmpty) {
      final decoded = base64Decode(existing);
      if (decoded.length == 32) return decoded;
      throw StateError('Encrypted sync key has an invalid length.');
    }
    final random = Random.secure();
    final generated = List<int>.generate(32, (_) => random.nextInt(256));
    await _secure.write(storageKey, base64Encode(generated));
    return generated;
  }

  Future<void> deleteKey(String ownerArchiveId) =>
      _secure.delete('saved_moment_sync_key_v1:${ownerArchiveId.trim()}');
}
