import 'dart:convert';
import 'dart:math';

import '../../../storage/secure_storage.dart';

final class SavedMomentSyncKeyMaterial {
  const SavedMomentSyncKeyMaterial({required this.bytes, required this.epoch});
  final List<int> bytes;
  final int epoch;
}

/// Device-protected, account-scoped key boundary for encrypted journal sync.
///
/// The server never receives this key in plaintext. Recovery only stores an
/// authenticated, secret-derived wrapping of the same random data key.
final class SavedMomentSyncKeyStore {
  SavedMomentSyncKeyStore(this._secure);

  final SecureStorageService _secure;

  Future<List<int>> requireKey(String ownerArchiveId) async =>
      (await requireKeyMaterial(ownerArchiveId)).bytes;

  Future<SavedMomentSyncKeyMaterial> requireKeyMaterial(
    String ownerArchiveId,
  ) async {
    final normalized = ownerArchiveId.trim();
    if (normalized.isEmpty) {
      throw StateError('Encrypted sync requires an authenticated archive.');
    }
    final storageKey = 'saved_moment_sync_key_v1:$normalized';
    final existing = await _secure.read(storageKey);
    if (existing != null && existing.isNotEmpty) {
      final decoded = base64Decode(existing);
      if (decoded.length == 32) {
        return SavedMomentSyncKeyMaterial(bytes: decoded, epoch: 1);
      }
      throw StateError('Encrypted sync key has an invalid length.');
    }
    final random = Random.secure();
    final generated = List<int>.generate(32, (_) => random.nextInt(256));
    await _secure.write(storageKey, base64Encode(generated));
    return SavedMomentSyncKeyMaterial(bytes: generated, epoch: 1);
  }

  Future<List<int>?> readKey(String ownerArchiveId) async {
    final raw = await _secure.read(
      'saved_moment_sync_key_v1:${ownerArchiveId.trim()}',
    );
    if (raw == null || raw.isEmpty) return null;
    final decoded = base64Decode(raw);
    if (decoded.length != 32) {
      throw StateError('Encrypted sync key has an invalid length.');
    }
    return decoded;
  }

  Future<void> installRecoveredKey(
    String ownerArchiveId,
    List<int> keyBytes, {
    required int epoch,
  }) async {
    final normalized = ownerArchiveId.trim();
    if (normalized.isEmpty || keyBytes.length != 32 || epoch != 1) {
      throw StateError('Recovered sync key metadata is invalid.');
    }
    await _secure.write(
      'saved_moment_sync_key_v1:$normalized',
      base64Encode(keyBytes),
    );
  }

  Future<int?> readRecoveryRevision(String ownerAccountId) async {
    final raw = await _secure.read(
      'sync_recovery_revision_v1:${ownerAccountId.trim()}',
    );
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> recordRecoveryRevision(
    String ownerAccountId,
    int revision,
  ) async {
    final account = ownerAccountId.trim();
    if (account.isEmpty || revision < 1) {
      throw StateError('Recovery revision is invalid.');
    }
    final current = await readRecoveryRevision(account);
    if (current != null && revision < current) {
      throw StateError('Recovery revision rollback rejected.');
    }
    await _secure.write(
      'sync_recovery_revision_v1:$account',
      revision.toString(),
    );
  }

  Future<void> deleteKey(String ownerArchiveId) =>
      _secure.delete('saved_moment_sync_key_v1:${ownerArchiveId.trim()}');
}
