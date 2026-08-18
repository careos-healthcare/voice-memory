import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// AES-GCM transport for mesh compute frames (handshake + inference payloads).
class MeshEncryptedTransport {
  MeshEncryptedTransport({required List<int> sessionKeyBytes})
      : _secretKey = SecretKey(sessionKeyBytes),
        _algorithm = AesGcm.with256bits();

  final SecretKey _secretKey;
  final AesGcm _algorithm;

  /// Derives a 256-bit session key from client/server handshake nonces.
  static Future<List<int>> deriveSessionKey({
    required String clientId,
    required String clientNonce,
    required String peerId,
    required String peerNonce,
  }) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final input = utf8.encode('$clientId:$clientNonce:$peerId:$peerNonce');
    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(input),
      info: utf8.encode('archiveme-mesh-v1'),
    );
    final bytes = await derived.extractBytes();
    return bytes;
  }

  /// Seals a JSON map into a base64 transport frame.
  Future<String> encryptJson(Map<String, dynamic> payload) async {
    final clearTextBytes = utf8.encode(jsonEncode(payload));
    final secretBox = await _algorithm.encrypt(
      clearTextBytes,
      secretKey: _secretKey,
    );
    final frame = {
      'cipher': base64.encode(secretBox.cipherText),
      'nonce': base64.encode(secretBox.nonce),
      'mac': base64.encode(secretBox.mac.bytes),
    };
    return jsonEncode(frame);
  }

  /// Opens a transport frame back into a JSON map.
  Future<Map<String, dynamic>?> decryptJson(String encryptedFrame) async {
    try {
      final frame = jsonDecode(encryptedFrame) as Map<String, dynamic>;
      final cipherText = base64.decode(frame['cipher'] as String);
      final nonce = base64.decode(frame['nonce'] as String);
      final macBytes = base64.decode(frame['mac'] as String);
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
      final clearTextBytes = await _algorithm.decrypt(
        secretBox,
        secretKey: _secretKey,
      );
      return jsonDecode(utf8.decode(clearTextBytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Convenience for binary prompt payloads embedded in inference requests.
  Future<Uint8List> encryptBytes(Uint8List bytes) async {
    final secretBox = await _algorithm.encrypt(bytes, secretKey: _secretKey);
    final nonceLength = secretBox.nonce.length;
    final macLength = secretBox.mac.bytes.length;
    final out = Uint8List(nonceLength + secretBox.cipherText.length + macLength);
    out.setRange(0, nonceLength, secretBox.nonce);
    out.setRange(nonceLength, nonceLength + secretBox.cipherText.length, secretBox.cipherText);
    out.setRange(
      nonceLength + secretBox.cipherText.length,
      out.length,
      secretBox.mac.bytes,
    );
    return out;
  }
}
