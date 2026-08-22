import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/models/encrypted_payload_dto.dart';
import 'package:archiveme_mobile/sync/sync_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncCrypto reflection', () {
    test('serializeReflectionDto produces stable JSON', () {
      const reflection = ReflectionDto(
        mood: 'calm',
        emotionalIntensity: 3,
        recurringThemes: ['work', 'rest'],
        hiddenConcern: 'deadline pressure',
        positiveSignal: 'finished a walk',
        recommendation: 'sleep earlier',
        exactLanguagePattern: 'I keep saying tomorrow',
        concreteObservation: 'Skipped lunch twice',
        repeatedSignal: 'avoidance',
        tensionOrContradiction: 'wants rest but keeps working',
        nextSmallAction: 'block 30 minutes offline',
        patternObservations: ['evening rumination'],
      );

      final jsonString = SyncCrypto.serializeReflectionDto(reflection);
      expect(jsonString, contains('"mood":"calm"'));
      final roundTripped = SyncCrypto.deserializeReflectionDto(jsonString);
      expect(roundTripped.mood, reflection.mood);
      expect(roundTripped.emotionalIntensity, reflection.emotionalIntensity);
      expect(roundTripped.recurringThemes, reflection.recurringThemes);
      expect(roundTripped.hiddenConcern, reflection.hiddenConcern);
      expect(roundTripped.positiveSignal, reflection.positiveSignal);
      expect(roundTripped.recommendation, reflection.recommendation);
    });

    test('encryptReflection round trip preserves ReflectionDto', () async {
      const reflection = ReflectionDto(
        mood: 'focused',
        emotionalIntensity: 7,
        recurringThemes: const ['health'],
        positiveSignal: 'good workout',
      );
      final crypto = SyncCrypto(List<int>.generate(32, (i) => i + 1));

      final encrypted = await crypto.encryptReflection(reflection);
      expect(encrypted, isA<EncryptedPayloadDto>());
      expect(encrypted.ciphertext, isNotEmpty);
      expect(encrypted.iv, isNotEmpty);
      expect(encrypted.version, 1);

      final decrypted = await crypto.decryptReflection(encrypted);
      expect(decrypted.mood, reflection.mood);
      expect(decrypted.emotionalIntensity, reflection.emotionalIntensity);
      expect(decrypted.recurringThemes, reflection.recurringThemes);
      expect(decrypted.positiveSignal, reflection.positiveSignal);
    });

    test('decrypt fails on tampered reflection ciphertext', () async {
      final crypto = SyncCrypto(List<int>.generate(32, (i) => i + 1));
      const reflection = ReflectionDto(mood: 'x', emotionalIntensity: 1);
      final encrypted = await crypto.encryptReflection(reflection);
      final tampered = EncryptedPayloadDto(
        ciphertext: '${encrypted.ciphertext}x',
        iv: encrypted.iv,
      );
      expect(
        () => crypto.decryptReflection(tampered),
        throwsA(anything),
      );
    });
  });

  group('ReflectionEncryptionService', () {
    test('uses in-memory key store for encrypt/decrypt', () async {
      final service = ReflectionEncryptionService(
        keyStore: InMemorySyncCryptoKeyStore(),
      );
      const reflection = ReflectionDto(
        mood: 'hopeful',
        emotionalIntensity: 5,
        recommendation: 'journal again tomorrow',
      );

      final encrypted = await service.encryptReflection(reflection);
      final decrypted = await service.decryptReflection(encrypted);
      expect(decrypted.mood, reflection.mood);
      expect(decrypted.recommendation, reflection.recommendation);
    });
  });

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
