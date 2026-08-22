import 'package:archiveme_mobile/features/encrypted_sync/sync_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encrypt decrypt round trip preserves journal snapshot json', () async {
    final key = List<int>.generate(32, (i) => i + 1);
    final crypto = SyncCrypto(key);
    const payload = {
      'envelope': {'schemaVersion': 2, 'deviceId': 'dev-1'},
      'entries': [],
    };

    final encrypted = await crypto.encryptJson(payload);
    expect(encrypted.version, 1);
    expect(encrypted.iv, isNotEmpty);
    expect(encrypted.ciphertext, isNotEmpty);

    final decrypted = await crypto.decryptJson(encrypted);
    expect(decrypted['envelope'], payload['envelope']);
  });

  test('decrypt fails on tampered ciphertext', () async {
    final key = List<int>.generate(32, (i) => i + 1);
    final crypto = SyncCrypto(key);
    final encrypted = await crypto.encryptJson({'x': 1});
    final tampered = EncryptedPayload(
      ciphertext: '${encrypted.ciphertext}x',
      iv: encrypted.iv,
    );
    expect(() => crypto.decryptJson(tampered), throwsA(anything));
  });
}