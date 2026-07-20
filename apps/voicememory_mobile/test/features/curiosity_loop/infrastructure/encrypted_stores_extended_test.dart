import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/services/cognitive_trajectory_evaluator.dart';
import 'package:voicememory_mobile/features/curiosity_loop/infrastructure/stores/local_cognitive_baseline_store.dart';
import 'package:voicememory_mobile/features/curiosity_loop/repositories/clinical_trajectory_history_store.dart';
import 'package:voicememory_mobile/storage/encrypted_json_storage.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

void main() {
  group('Encrypted Stores Extended Tests', () {
    late Directory tempDir;
    late MobilePrefsStore prefs;
    late EncryptedJsonStorage secureCryptoStorage;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_encrypted_stores_ext_');
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      secureCryptoStorage =
          EncryptedJsonStorage(masterKeyBytes: List<int>.generate(32, (i) => i));
      await LocalCognitiveBaselineStore.resetForTest(prefs);
      await LocalClinicalTrajectoryHistoryStore.resetForTest(prefs);
    });

    test('Baseline store migrates legacy prefs key to secure key on read', () async {
      await prefs.writeJsonMap(
        LocalCognitiveBaselineStore.legacyPrefsKey,
        CognitiveBaselineSnapshot(
          biomarkers: const CognitiveBiomarkers(
            lexicalDiversity: 0.61,
            cohesionDrift: 0.22,
            emotionalVolatility: 0.31,
          ),
          updatedAt: DateTime.utc(2026, 7, 18, 12),
        ).toJson(),
      );

      final migratedStore = LocalCognitiveBaselineStore(
        prefs: prefs,
        cryptoStorage: secureCryptoStorage,
      );

      final snapshot = await migratedStore.loadSnapshot();
      expect(snapshot?.biomarkers.lexicalDiversity, closeTo(0.61, 0.0001));
      expect(
        await prefs.readJsonMap(LocalCognitiveBaselineStore.legacyPrefsKey),
        isEmpty,
      );
      expect(
        await prefs.readString(LocalCognitiveBaselineStore.prefsKey),
        isNotEmpty,
      );
    });

    test(
        'Trajectory store lifecycle ensures data cannot be read as raw plaintext strings',
        () async {
      final targetStore = LocalClinicalTrajectoryHistoryStore(
        prefs: prefs,
        cryptoStorage: secureCryptoStorage,
      );

      expect(
        await targetStore.appendRecord(
          StoredTrajectoryRecord.fromAssessment(
            date: DateTime.utc(2026, 7, 17, 12),
            entryId: 'entry_1',
            hookId: 'hook_1',
            assessment: const TrajectoryAssessment(
              lexicalDelta: 0.12,
              driftDelta: -0.08,
              volatilityDelta: -0.03,
              direction: CognitiveDirection.recovering,
            ),
          ),
        ),
        isTrue,
      );

      final rawPrefsString =
          await prefs.readString(LocalClinicalTrajectoryHistoryStore.prefsKey);
      expect(rawPrefsString, isNotNull);
      expect(rawPrefsString!.contains('entry_1'), isFalse);
      expect(rawPrefsString.contains('cipher'), isTrue);

      final points = await targetStore.loadRecent(
        now: DateTime.utc(2026, 7, 18, 12),
      );
      expect(points, hasLength(1));
      expect(points.single.lexicalDelta, closeTo(0.12, 0.0001));
    });
  });
}
