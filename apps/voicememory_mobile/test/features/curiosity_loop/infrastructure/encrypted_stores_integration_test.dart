import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:voicememory_mobile/features/curiosity_loop/infrastructure/stores/local_cognitive_baseline_store.dart';
import 'package:voicememory_mobile/storage/encrypted_json_storage.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

void main() {
  group('Encrypted Stores Integration Tests', () {
    late Directory tempDir;
    late MobilePrefsStore prefs;
    late List<int> validKeyBytes;
    late EncryptedJsonStorage secureCryptoStorage;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_encrypted_stores_');
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      validKeyBytes = List<int>.generate(32, (i) => i);
      secureCryptoStorage = EncryptedJsonStorage(masterKeyBytes: validKeyBytes);
      await LocalCognitiveBaselineStore.resetForTest(prefs);
    });

    test(
        'Baseline store lifecycle ensures data cannot be read as raw plaintext strings',
        () async {
      final targetStore = LocalCognitiveBaselineStore(
        prefs: prefs,
        cryptoStorage: secureCryptoStorage,
      );

      final snapshot = CognitiveBaselineSnapshot(
        biomarkers: const CognitiveBiomarkers(
          lexicalDiversity: 0.72,
          cohesionDrift: 0.18,
          emotionalVolatility: 0.12,
        ),
        updatedAt: DateTime.utc(2026, 7, 18),
      );

      final writeSuccess = await targetStore.saveSnapshot(snapshot);
      expect(writeSuccess, isTrue);

      final rawPrefsString =
          await prefs.readString(LocalCognitiveBaselineStore.prefsKey);
      expect(rawPrefsString, isNotNull);
      expect(
        rawPrefsString!.contains('lexicalDiversity'),
        isFalse,
        reason: 'Plaintext fields leaked directly to disk storage strings!',
      );
      expect(rawPrefsString.contains('cipher'), isTrue);

      final retrievedSnapshot = await targetStore.loadSnapshot();
      expect(retrievedSnapshot, isNotNull);
      expect(retrievedSnapshot!.biomarkers.lexicalDiversity, equals(0.72));
    });

    test('Baseline store drops keys gracefully if a tampered key context is passed',
        () async {
      final storeWithValidKey = LocalCognitiveBaselineStore(
        prefs: prefs,
        cryptoStorage: secureCryptoStorage,
      );

      await storeWithValidKey.saveSnapshot(
        CognitiveBaselineSnapshot(
          biomarkers: const CognitiveBiomarkers(
            lexicalDiversity: 0.5,
            cohesionDrift: 0.5,
            emotionalVolatility: 0.5,
          ),
          updatedAt: DateTime.now(),
        ),
      );

      final brokenKeyBytes = List<int>.generate(32, (i) => i + 1);
      final compromisedStore = LocalCognitiveBaselineStore(
        prefs: prefs,
        cryptoStorage: EncryptedJsonStorage(masterKeyBytes: brokenKeyBytes),
      );

      final result = await compromisedStore.loadSnapshot();
      expect(
        result,
        isNull,
        reason:
            'System decryption failed to capture authentication tag anomalies.',
      );
    });
  });
}
