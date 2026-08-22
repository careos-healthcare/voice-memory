import 'dart:convert';

import 'package:archiveme_mobile/storage/encrypted_json_storage.dart';
import 'package:flutter_test/flutter_test.dart';

final _testKey = List<int>.filled(32, 7);

void main() {
  group('EncryptedJsonStorage', () {
    test('round-trips JSON maps through authenticated encryption', () async {
      final storage = EncryptedJsonStorage(masterKeyBytes: _testKey);
      const payload = {
        'baseline': {
          'lexicalDiversity': 0.55,
          'cohesionDrift': 0.35,
          'emotionalVolatility': 0.40,
        },
        'observationCount': 3,
      };

      final encrypted = await storage.encryptData(payload);
      final decoded = await storage.decryptData(encrypted);

      expect(decoded, payload);
      expect(encrypted.contains('0.55'), isFalse);
    });

    test(
      'returns null when ciphertext is decrypted with the wrong key',
      () async {
        final writer = EncryptedJsonStorage(masterKeyBytes: _testKey);
        final reader = EncryptedJsonStorage(
          masterKeyBytes: List<int>.filled(32, 9),
        );

        final encrypted = await writer.encryptData({'entryId': 'entry_1'});
        expect(await reader.decryptData(encrypted), isNull);
      },
    );

    test('returns null when authentication tag is tampered', () async {
      final storage = EncryptedJsonStorage(masterKeyBytes: _testKey);
      final encrypted = await storage.encryptData({'entryId': 'entry_1'});

      final payload = jsonDecode(encrypted) as Map<String, dynamic>;
      payload['mac'] = base64.encode(List<int>.filled(16, 0));
      final tampered = jsonEncode(payload);

      expect(await storage.decryptData(tampered), isNull);
    });

    test('returns null for malformed transport payloads', () async {
      final storage = EncryptedJsonStorage(masterKeyBytes: _testKey);

      expect(await storage.decryptData('not-json'), isNull);
      expect(await storage.decryptData('{}'), isNull);
    });
  });
}