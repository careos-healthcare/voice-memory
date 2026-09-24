import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/live_audio/live_audio_constants.dart';
import 'package:archiveme_mobile/storage/private_data_encryption_key_store.dart';
import 'package:archiveme_mobile/storage/secure_storage.dart';
import 'package:cryptography/cryptography.dart';

/// Reads encrypted offline vault files for local fallback recovery.
class LocalAudioVaultReader {
  LocalAudioVaultReader({
    PrivateDataEncryptionKeyStore? keyStore,
    AesGcm? algorithm,
  }) : _keyStore =
           keyStore ??
           SecurePrivateDataEncryptionKeyStore(store: SecureStorageService()),
       _algorithm = algorithm ?? AesGcm.with256bits();

  static const _magic = [0x41, 0x56, 0x4d, 0x45];
  static const _formatVersion = 1;

  final PrivateDataEncryptionKeyStore _keyStore;
  final AesGcm _algorithm;

  Future<Uint8List> decryptVaultFile(
    File vaultFile, {
    List<int>? recoverySecretKeyBytes,
  }) async {
    final bytes = await vaultFile.readAsBytes();
    final secretKey = recoverySecretKeyBytes != null
        ? SecretKey(recoverySecretKeyBytes)
        : SecretKey(await _deviceKeyBytes());
    return _decryptBytes(bytes, secretKey);
  }

  Future<List<int>> _deviceKeyBytes() async {
    if (_keyStore is SecurePrivateDataEncryptionKeyStore) {
      await _keyStore.ensureKey();
    } else if (_keyStore is InMemoryPrivateDataEncryptionKeyStore) {
      await _keyStore.ensureKey();
    }
    final keyBytes = await _keyStore.readKeyBytes();
    if (keyBytes == null || keyBytes.length != 32) {
      throw StateError('Missing encryption key for vault reader.');
    }
    return keyBytes;
  }

  Future<Uint8List> _decryptBytes(Uint8List bytes, SecretKey secretKey) async {
    if (bytes.length < 10 || !_matchesMagic(bytes)) {
      throw const FormatException('Invalid vault file.');
    }
    if (bytes[4] != _formatVersion) {
      throw FormatException('Unsupported vault version ${bytes[4]}.');
    }

    var offset = 10;
    final pcm = BytesBuilder(copy: false);
    while (offset < bytes.length) {
      if (offset + 4 > bytes.length) break;
      final cipherLength = bytes.buffer.asByteData().getUint32(
        offset,
        Endian.little,
      );
      offset += 4;
      const nonceLength = 12;
      const macLength = 16;
      final frameEnd = offset + nonceLength + macLength + cipherLength;
      if (cipherLength <= 0 || frameEnd > bytes.length) {
        throw const FormatException('Corrupt encrypted vault frame.');
      }

      final nonce = bytes.sublist(offset, offset + nonceLength);
      offset += nonceLength;
      final mac = bytes.sublist(offset, offset + macLength);
      offset += macLength;
      final cipherText = bytes.sublist(offset, offset + cipherLength);
      offset += cipherLength;

      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));
      final frame = await _algorithm.decrypt(secretBox, secretKey: secretKey);
      pcm.add(frame);
    }

    final pcmBytes = pcm.toBytes();
    if (pcmBytes.isEmpty) {
      throw const FormatException('Vault contains no audio frames.');
    }
    return Uint8List.fromList(pcmBytes);
  }

  bool _matchesMagic(Uint8List bytes) {
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return false;
    }
    return true;
  }

  static List<int>? decodeRecoverySecret(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final bytes = base64Url.decode(encoded);
      return bytes.length == 32 ? bytes : null;
    } catch (_, stackTrace) {
      return null;
    }
  }

  static int estimateDurationSeconds({
    required int frameCount,
    int frameDurationMs = liveInputFrameDurationMs,
  }) {
    if (frameCount <= 0) return 1;
    return ((frameCount * frameDurationMs) / 1000).ceil().clamp(1, 999999);
  }
}
