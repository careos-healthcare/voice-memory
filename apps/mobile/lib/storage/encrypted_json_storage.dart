import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// A secure persistence wrapper that uses authenticated AES-GCM encryption
/// to shield sensitive biomarker telemetry strings before storage.
class EncryptedJsonStorage {

  EncryptedJsonStorage({required List<int> masterKeyBytes})
    : _secretKey = SecretKey(masterKeyBytes);
  final SecretKey _secretKey;
  final AesGcm _algorithm = AesGcm.with256bits();

  /// Ciphers raw JSON string maps into a securely sealed transit payload.
  Future<String> encryptData(Map<String, dynamic> rawJson) async {
    final clearTextBytes = utf8.encode(jsonEncode(rawJson));

    final secretBox = await _algorithm.encrypt(
      clearTextBytes,
      secretKey: _secretKey,
    );

    final transportPayload = {
      'cipher': base64.encode(secretBox.cipherText),
      'nonce': base64.encode(secretBox.nonce),
      'mac': base64.encode(secretBox.mac.bytes),
    };

    return jsonEncode(transportPayload);
  }

  /// Validates signature authenticity and decodes secure string storage frames.
  Future<Map<String, dynamic>?> decryptData(String encryptedJsonString) async {
    try {
      final payload = jsonDecode(encryptedJsonString) as Map<String, dynamic>;

      final cipherText = base64.decode(payload['cipher'] as String);
      final nonce = base64.decode(payload['nonce'] as String);
      final macBytes = base64.decode(payload['mac'] as String);

      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));

      final clearTextBytes = await _algorithm.decrypt(
        secretBox,
        secretKey: _secretKey,
      );

      return jsonDecode(utf8.decode(clearTextBytes)) as Map<String, dynamic>;
    } on Object catch (_, stackTrace) {
      return null;
    }
  }
}