import 'dart:io';
import 'dart:typed_data';

import '../export_backup/vault_backup_models.dart';
import '../export_backup/vault_format.dart';
import '../../services/security/sync_identity_service.dart';

typedef SanctuaryOwnerAuthenticator = Future<bool> Function(String reason);
typedef SanctuarySyncKeyRotator = Future<String> Function();

final class SanctuaryKeyringManager {
  SanctuaryKeyringManager({
    required this.identity,
    required this.portableKeys,
    required this.authenticateOwner,
    required this.rotateSyncKey,
    VaultCryptography? cryptography,
    DateTime Function()? clock,
  }) : _cryptography = cryptography ?? VaultCryptography(),
       _clock = clock ?? DateTime.now;

  final SyncIdentityService identity;
  final VaultPortableKeyProvider portableKeys;
  final SanctuaryOwnerAuthenticator authenticateOwner;
  final SanctuarySyncKeyRotator rotateSyncKey;
  final VaultCryptography _cryptography;
  final DateTime Function() _clock;

  Future<String?> revealRecoveryPhrase() async {
    if (!await authenticateOwner('Reveal your sync recovery phrase')) {
      return null;
    }
    return identity.recoveryPhrase();
  }

  Future<bool> verifyRecoveryPhrase(String candidate) async {
    if (!await authenticateOwner('Verify your sync recovery phrase')) {
      return false;
    }
    final actual = await identity.recoveryPhrase();
    if (actual == null) return false;
    return _normalize(actual) == _normalize(candidate);
  }

  /// Rotates the E2EE sync master key generation. Local at-rest keys are not
  /// replaced without a full transactional re-encryption migration.
  Future<String?> rotateSyncMasterKey() async {
    if (!await authenticateOwner('Rotate your encrypted sync master key')) {
      return null;
    }
    return rotateSyncKey();
  }

  Future<File?> exportEncryptedKeyBackup({
    required Directory directory,
    required String password,
  }) async {
    if (!await authenticateOwner('Export an encrypted Sanctuary key backup')) {
      return null;
    }
    final credential = VaultCredential.password(password);
    final keyring = await portableKeys.exportPortableKeys(
      includeSyncPhrase: true,
    );
    Uint8List? clear;
    Uint8List? encrypted;
    try {
      clear = keyring.toBytes();
      encrypted = (await _cryptography.encrypt(clear, credential)).toBytes();
      await directory.create(recursive: true);
      final stamp = _clock().toUtc().toIso8601String().replaceAll(
        RegExp(r'[:.]'),
        '-',
      );
      final output = File(
        '${directory.path}/sanctuary-key-$stamp.sanctuary-key',
      );
      final temporary = File('${output.path}.tmp');
      await temporary.writeAsBytes(encrypted, flush: true);
      return temporary.rename(output.path);
    } finally {
      keyring.wipe();
      wipeBytes(clear);
      wipeBytes(encrypted);
    }
  }
}

String _normalize(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
