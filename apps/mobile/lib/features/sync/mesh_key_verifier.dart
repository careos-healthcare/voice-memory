import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Stored 256-bit key for mesh payload checks.
abstract class MeshKeyStore {
  Future<List<int>?> read();

  Future<void> write(List<int> key);
}

/// In-memory key store for tests and for a session that has no secure store.
class MemoryMeshKeyStore implements MeshKeyStore {
  MemoryMeshKeyStore([List<int>? initial]) : _key = initial?.toList();

  List<int>? _key;

  @override
  Future<List<int>?> read() async => _key?.toList();

  @override
  Future<void> write(List<int> key) async {
    _key = List<int>.from(key);
  }
}

/// Result of an AES-GCM 256 handshake check.
class MeshKeyCheck {
  const MeshKeyCheck({
    required this.valid,
    required this.fingerprint,
  });

  final bool valid;
  final String fingerprint;
}

/// Sealed handshake a peer can open with the same 256-bit key.
class MeshHandshake {
  const MeshHandshake({
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;

  SecretBox get box => SecretBox(
    cipherText,
    nonce: nonce,
    mac: Mac(mac),
  );
}

/// Local AES-GCM 256 check that a mesh payload was sealed with the device key.
abstract final class MeshKeyVerifier {
  static const handshakeText = 'mesh-handshake-v1';
  static const keyByteLength = 32;

  static final AesGcm _cipher = AesGcm.with256bits();

  static List<int> randomKey() {
    final random = Random.secure();
    return List<int>.generate(keyByteLength, (_) => random.nextInt(256));
  }

  /// Seals a known handshake and opens it again. A bad tag fails the check.
  static Future<MeshKeyCheck> verifyLocal(List<int> key) async {
    if (key.length != keyByteLength) {
      return const MeshKeyCheck(valid: false, fingerprint: '');
    }
    try {
      final handshake = await seal(key);
      final opened = await open(key: key, handshake: handshake);
      if (!opened) {
        return const MeshKeyCheck(valid: false, fingerprint: '');
      }
      return MeshKeyCheck(valid: true, fingerprint: await fingerprintOf(key));
    } on Object {
      return const MeshKeyCheck(valid: false, fingerprint: '');
    }
  }

  static Future<MeshHandshake> seal(List<int> key) async {
    final secretKey = await _cipher.newSecretKeyFromBytes(key);
    final box = await _cipher.encrypt(
      utf8.encode(handshakeText),
      secretKey: secretKey,
    );
    return MeshHandshake(
      nonce: box.nonce,
      cipherText: box.cipherText,
      mac: box.mac.bytes,
    );
  }

  /// Opens a peer handshake. A mismatched key fails the GCM tag.
  static Future<bool> open({
    required List<int> key,
    required MeshHandshake handshake,
  }) async {
    if (key.length != keyByteLength) return false;
    try {
      final secretKey = await _cipher.newSecretKeyFromBytes(key);
      final clear = await _cipher.decrypt(
        handshake.box,
        secretKey: secretKey,
      );
      return utf8.decode(clear) == handshakeText;
    } on SecretBoxAuthenticationError {
      return false;
    } on Object {
      return false;
    }
  }

  static Future<String> fingerprintOf(List<int> key) async {
    final digest = await Sha256().hash(Uint8List.fromList(key));
    final hex = digest.bytes
        .take(4)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return hex;
  }
}
