import 'dart:convert';
import 'dart:math';

import 'package:archiveme_mobile/sync/sync_crypto.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Reads and writes the 256-bit AES-GCM key used by the cloud relay.
///
/// The stored bytes live in the iOS Keychain and the Android Keystore
/// through `flutter_secure_storage`. A 12-word BIP-39 phrase can derive
/// the same key on another device.
class SecureKeyManager implements SyncCryptoKeyStore {
  SecureKeyManager({
    FlutterSecureStorage? secureStorage,
    this.storageKey = defaultStorageKey,
    this.verifiedKey = defaultVerifiedKey,
  }) : _secureStorage =
           secureStorage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions.defaultOptions,
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock_this_device,
             ),
           );

  static const defaultStorageKey = 'cloud_relay_aes256_gcm_v1';
  static const defaultVerifiedKey = 'cloud_backup_recovery_verified_v1';
  static const keyByteLength = 32;
  static const phraseWordCount = 12;

  final FlutterSecureStorage _secureStorage;
  final String storageKey;
  final String verifiedKey;

  /// Twelve words. The phrase itself is not written to storage.
  String createRecoveryPhrase() => bip39.generateMnemonic();

  /// First 32 bytes of the BIP-39 seed. That is the AES-256-GCM master key.
  static List<int> keyFromMnemonic(String phrase) {
    final normalized = normalizePhrase(phrase);
    final words = normalized.split(' ');
    if (words.length != phraseWordCount ||
        !bip39.validateMnemonic(normalized)) {
      throw const FormatException('Enter the 12-word recovery phrase.');
    }
    final seed = bip39.mnemonicToSeed(normalized);
    return seed.sublist(0, keyByteLength);
  }

  static String normalizePhrase(String phrase) =>
      phrase.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// True after the phrase has been re-entered on this device.
  Future<bool> hasVerifiedRecoveryPhrase() async {
    return await _secureStorage.read(key: verifiedKey) == '1';
  }

  /// Stores the derived key and marks the phrase confirmed.
  Future<void> confirmRecoveryPhrase(String phrase) async {
    await writeKeyBytes(keyFromMnemonic(phrase));
    await _secureStorage.write(key: verifiedKey, value: '1');
  }

  /// Regenerates the master key from a phrase written down on another device.
  Future<List<int>> restoreFromPhrase(String phrase) async {
    await confirmRecoveryPhrase(phrase);
    final key = await readKeyBytes();
    if (key == null) {
      throw StateError('Restored key was not stored.');
    }
    return key;
  }

  /// Three word positions the user must confirm before backup can turn on.
  static List<int> selectWordIndexes(
    String phrase, {
    int count = 3,
    Random? random,
  }) {
    final words = normalizePhrase(phrase).split(' ');
    if (words.length < count) {
      throw const FormatException('Enter the 12-word recovery phrase.');
    }
    final indexes = List<int>.generate(words.length, (index) => index);
    indexes.shuffle(random ?? Random.secure());
    return indexes.take(count).toList()..sort();
  }

  /// True when every selected position matches the shown phrase.
  static bool confirmsSelectedWords({
    required String shownPhrase,
    required Map<int, String> answers,
  }) {
    final words = normalizePhrase(shownPhrase).split(' ');
    if (answers.length < 3) return false;
    for (final entry in answers.entries) {
      if (entry.key < 0 || entry.key >= words.length) return false;
      if (normalizePhrase(entry.value) != words[entry.key]) return false;
    }
    return true;
  }

  /// Premium cloud backup stays off until the selected words match.
  Future<bool> enableCloudBackup({
    required bool hasPremium,
    required String shownPhrase,
    required Map<int, String> confirmedWords,
  }) async {
    if (!hasPremium) return false;
    if (!confirmsSelectedWords(
      shownPhrase: shownPhrase,
      answers: confirmedWords,
    )) {
      return false;
    }
    await confirmRecoveryPhrase(shownPhrase);
    return true;
  }

  /// Returns the stored key, creating a 256-bit key on first boot.
  Future<List<int>> loadOrCreate() => ensureKey();

  @override
  Future<List<int>?> readKeyBytes() async {
    final encoded = await _secureStorage.read(key: storageKey);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final bytes = base64Decode(encoded);
      if (bytes.length != keyByteLength) return null;
      return bytes;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> writeKeyBytes(List<int> keyBytes) async {
    if (keyBytes.length != keyByteLength) {
      throw ArgumentError.value(
        keyBytes.length,
        'keyBytes',
        'expected $keyByteLength bytes',
      );
    }
    await _secureStorage.write(
      key: storageKey,
      value: base64Encode(keyBytes),
    );
  }

  @override
  Future<void> deleteKey() => _secureStorage.delete(key: storageKey);

  @override
  Future<List<int>> ensureKey() async {
    final existing = await readKeyBytes();
    if (existing != null) return existing;
    final random = Random.secure();
    final created = List<int>.generate(
      keyByteLength,
      (_) => random.nextInt(256),
    );
    await writeKeyBytes(created);
    return created;
  }
}
