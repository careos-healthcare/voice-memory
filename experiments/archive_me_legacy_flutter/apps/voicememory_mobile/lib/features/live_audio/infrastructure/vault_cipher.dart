import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// AES-GCM encrypt/decrypt helper for vault PCM chunk payloads.
///
/// Authenticated blob format: nonce (12 bytes) + MAC (16 bytes) + ciphertext.
///
/// On-disk / emergency upload frame record format:
/// `uint32 ciphertextLength + authenticated blob`.
class VaultCipher {
  VaultCipher({AesGcm? algorithm})
    : _aesGcm = algorithm ?? AesGcm.with256bits();

  static const int nonceLength = 12;
  static const int macLength = 16;
  static const int authenticatedOverhead = nonceLength + macLength;

  final AesGcm _aesGcm;

  /// Encrypts raw PCM bytes returning [nonce (12b) + mac (16b) + ciphertext].
  Future<Uint8List> encryptChunk({
    required List<int> rawBytes,
    required SecretKey secretKey,
  }) async {
    final nonce = _aesGcm.newNonce();
    final secretBox = await _aesGcm.encrypt(
      rawBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final builder = BytesBuilder(copy: false)
      ..add(secretBox.nonce)
      ..add(secretBox.mac.bytes)
      ..add(secretBox.cipherText);

    return builder.toBytes();
  }

  /// Encrypts PCM bytes into an AVME vault frame / emergency upload record.
  Future<Uint8List> encryptVaultFrameRecord({
    required List<int> rawBytes,
    required SecretKey secretKey,
  }) async {
    final authenticatedBlob = await encryptChunk(
      rawBytes: rawBytes,
      secretKey: secretKey,
    );
    final cipherTextLength = authenticatedBlob.length - authenticatedOverhead;

    final record = BytesBuilder(copy: false)
      ..add(_uint32Le(cipherTextLength))
      ..add(authenticatedBlob);

    return record.toBytes();
  }

  /// Decrypts authenticated cipher payload.
  Future<Uint8List> decryptChunk({
    required List<int> encryptedBytes,
    required SecretKey secretKey,
  }) async {
    if (encryptedBytes.length < authenticatedOverhead) {
      throw FormatException(
        'Encrypted payload too short to contain Nonce and MAC tag',
      );
    }

    final nonce = encryptedBytes.sublist(0, nonceLength);
    final macBytes = encryptedBytes.sublist(nonceLength, authenticatedOverhead);
    final cipherText = encryptedBytes.sublist(authenticatedOverhead);

    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));

    final clearBytes = await _aesGcm.decrypt(secretBox, secretKey: secretKey);

    return Uint8List.fromList(clearBytes);
  }

  /// Decrypts one AVME vault frame / emergency upload record.
  Future<Uint8List> decryptVaultFrameRecord({
    required List<int> encryptedRecordBytes,
    required SecretKey secretKey,
  }) async {
    final frameLength = vaultFrameRecordLength(encryptedRecordBytes, 0);
    if (frameLength == null) {
      throw FormatException('Corrupt encrypted vault frame record.');
    }

    final authenticatedBlob = encryptedRecordBytes.sublist(4, frameLength);
    return decryptChunk(
      encryptedBytes: authenticatedBlob,
      secretKey: secretKey,
    );
  }

  /// Returns total byte length for a frame record starting at [offset], or null.
  static int? vaultFrameRecordLength(List<int> bytes, int offset) {
    if (offset + 4 > bytes.length) {
      return null;
    }

    final cipherTextLength = _readUint32Le(bytes, offset);
    if (cipherTextLength <= 0) {
      return null;
    }

    final frameEnd = offset + 4 + authenticatedOverhead + cipherTextLength;
    if (frameEnd > bytes.length) {
      return null;
    }

    return frameEnd;
  }

  static int _readUint32Le(List<int> bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  static Uint8List _uint32Le(int value) {
    final bytes = Uint8List(4);
    bytes.buffer.asByteData().setUint32(0, value, Endian.little);
    return bytes;
  }
}
