import 'dart:convert';

import 'package:archiveme_crypto/archiveme_crypto.dart';
import 'package:test/test.dart';

void main() {
  final key = List<int>.filled(32, 0x3c);
  const payload = {'kind': 'synthetic', 'n': 7};

  test('encrypt then decrypt returns the original map', () async {
    final storage = EncryptedJsonStorage(masterKeyBytes: key);
    final envelope = await storage.encryptData(payload);
    expect(jsonDecode(envelope), containsPair('cipher', isA<String>()));
    expect(jsonDecode(envelope), containsPair('nonce', isA<String>()));
    expect(jsonDecode(envelope), containsPair('mac', isA<String>()));
    expect(await storage.decryptData(envelope), payload);
  });

  test('two encryptions of the same map differ (random nonce)', () async {
    final storage = EncryptedJsonStorage(masterKeyBytes: key);
    final a = await storage.encryptData(payload);
    final b = await storage.encryptData(payload);
    expect(a, isNot(b));
    expect(await storage.decryptData(a), payload);
    expect(await storage.decryptData(b), payload);
  });

  test('wrong key returns null (fail closed, no throw)', () async {
    final writer = EncryptedJsonStorage(masterKeyBytes: key);
    final envelope = await writer.encryptData(payload);
    final reader = EncryptedJsonStorage(masterKeyBytes: List<int>.filled(32, 0x3d));
    expect(await reader.decryptData(envelope), isNull);
  });

  test('tampered mac returns null', () async {
    final storage = EncryptedJsonStorage(masterKeyBytes: key);
    final envelope = jsonDecode(await storage.encryptData(payload)) as Map<String, dynamic>;
    final mac = envelope['mac'] as String;
    envelope['mac'] = mac.replaceRange(0, 1, mac[0] == 'A' ? 'B' : 'A');
    expect(await storage.decryptData(jsonEncode(envelope)), isNull);
  });

  test('garbage input returns null', () async {
    final storage = EncryptedJsonStorage(masterKeyBytes: key);
    expect(await storage.decryptData('not-json'), isNull);
    expect(await storage.decryptData('{}'), isNull);
  });
}
