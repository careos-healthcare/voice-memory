import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class EncryptedStorageException implements Exception {
  const EncryptedStorageException(this.message);

  final String message;

  @override
  String toString() => 'EncryptedStorageException: $message';
}

/// Authenticated AES-256-GCM encryption for local private payloads.
///
/// Callers own the key lifecycle. This engine never persists, caches, or logs
/// key material or plaintext.
class EncryptedStorageEngine {
  EncryptedStorageEngine({AesGcm? algorithm})
    : _algorithm = algorithm ?? AesGcm.with256bits();

  static const envelopeVersion = 1;
  static const keyLength = 32;

  final AesGcm _algorithm;

  Future<Map<String, dynamic>> encrypt(
    List<int> plaintext, {
    required List<int> keyBytes,
    List<int> associatedData = const [],
  }) async {
    _validateKey(keyBytes);
    final box = await _algorithm.encrypt(
      plaintext,
      secretKey: SecretKey(keyBytes),
      aad: associatedData,
    );
    return {
      'v': envelopeVersion,
      'n': base64Encode(box.nonce),
      'c': base64Encode(box.cipherText),
      'm': base64Encode(box.mac.bytes),
    };
  }

  Future<Uint8List> decrypt(
    Map<String, dynamic> envelope, {
    required List<int> keyBytes,
    List<int> associatedData = const [],
  }) async {
    _validateKey(keyBytes);
    if (envelope['v'] != envelopeVersion) {
      throw const EncryptedStorageException(
        'Unsupported encrypted envelope version.',
      );
    }
    try {
      final clear = await _algorithm.decrypt(
        SecretBox(
          base64Decode(envelope['c'] as String),
          nonce: base64Decode(envelope['n'] as String),
          mac: Mac(base64Decode(envelope['m'] as String)),
        ),
        secretKey: SecretKey(keyBytes),
        aad: associatedData,
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const EncryptedStorageException(
        'Authentication failed; the key or payload is invalid.',
      );
    } on FormatException {
      throw const EncryptedStorageException('Malformed encrypted payload.');
    } on TypeError {
      throw const EncryptedStorageException('Malformed encrypted payload.');
    }
  }

  Future<void> writeFile(
    File file,
    List<int> plaintext, {
    required List<int> keyBytes,
    List<int> associatedData = const [],
  }) async {
    final envelope = await encrypt(
      plaintext,
      keyBytes: keyBytes,
      associatedData: associatedData,
    );
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(envelope), flush: true);
    await temporary.rename(file.path);
  }

  Future<Uint8List> readFile(
    File file, {
    required List<int> keyBytes,
    List<int> associatedData = const [],
  }) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const EncryptedStorageException('Malformed encrypted payload.');
    }
    return decrypt(
      Map<String, dynamic>.from(decoded),
      keyBytes: keyBytes,
      associatedData: associatedData,
    );
  }

  void _validateKey(List<int> keyBytes) {
    if (keyBytes.length != keyLength) {
      throw ArgumentError.value(
        keyBytes.length,
        'keyBytes.length',
        'AES-256 requires exactly $keyLength bytes',
      );
    }
  }
}
