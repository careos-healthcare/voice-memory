import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/services/cognitive_trajectory_evaluator.dart';
import 'package:voicememory_mobile/features/curiosity_loop/repositories/clinical_trajectory_history_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

void main() {
  group('LocalClinicalTrajectoryHistoryStore', () {
    late Directory tempDir;
    late MobilePrefsStore prefs;
    late LocalClinicalTrajectoryHistoryStore store;
    final testMasterKey = List<int>.generate(32, (i) => i);

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_trajectory_history_');
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      await LocalClinicalTrajectoryHistoryStore.resetForTest(prefs);
      store = LocalClinicalTrajectoryHistoryStore.forPrefs(
        prefs,
        masterKeyBytes: testMasterKey,
      );
    });

    test('appendRecord persists chronological telemetry points', () async {
      await store.appendRecord(
        StoredTrajectoryRecord.fromAssessment(
          date: DateTime.utc(2026, 6, 10, 12),
          entryId: 'entry_1',
          hookId: 'hook_1',
          assessment: const TrajectoryAssessment(
            lexicalDelta: 0.20,
            driftDelta: -0.25,
            volatilityDelta: -0.10,
            direction: CognitiveDirection.recovering,
          ),
        ),
      );

      final points = await store.loadRecent(now: DateTime.utc(2026, 6, 12, 12));

      expect(points, hasLength(1));
      expect(points.single.direction, CognitiveDirection.recovering);
      expect(points.single.recoveryIndex, closeTo(0.45, 0.0001));
    });

    test('loadRecent excludes records outside the rolling window', () async {
      await store.appendRecord(
        StoredTrajectoryRecord.fromAssessment(
          date: DateTime.utc(2026, 6, 1, 12),
          entryId: 'entry_old',
          hookId: 'hook_old',
          assessment: const TrajectoryAssessment(
            lexicalDelta: 0.05,
            driftDelta: 0.05,
            volatilityDelta: 0.05,
            direction: CognitiveDirection.stagnant,
          ),
        ),
      );
      await store.appendRecord(
        StoredTrajectoryRecord.fromAssessment(
          date: DateTime.utc(2026, 6, 11, 12),
          entryId: 'entry_new',
          hookId: 'hook_new',
          assessment: const TrajectoryAssessment(
            lexicalDelta: 0.15,
            driftDelta: -0.20,
            volatilityDelta: -0.05,
            direction: CognitiveDirection.recovering,
          ),
        ),
      );

      final points = await store.loadRecent(now: DateTime.utc(2026, 6, 12, 12));

      expect(points, hasLength(1));
      expect(points.single.lexicalDelta, closeTo(0.15, 0.0001));
    });

    test(
      'stores encrypted payloads without plaintext trajectory values',
      () async {
        await store.appendRecord(
          StoredTrajectoryRecord.fromAssessment(
            date: DateTime.utc(2026, 6, 11, 12),
            entryId: 'entry_new',
            hookId: 'hook_new',
            assessment: const TrajectoryAssessment(
              lexicalDelta: 0.15,
              driftDelta: -0.20,
              volatilityDelta: -0.05,
              direction: CognitiveDirection.recovering,
            ),
          ),
        );

        final rawPrefs = await prefs.file.readAsString();
        expect(rawPrefs.contains('entry_new'), isFalse);
        expect(
          rawPrefs.contains('secure_clinical_trajectory_history_records'),
          isTrue,
        );
        expect(rawPrefs.contains('cipher'), isTrue);
      },
    );

    test('appendRecord returns true on successful encrypted write', () async {
      expect(
        await store.appendRecord(
          StoredTrajectoryRecord.fromAssessment(
            date: DateTime.utc(2026, 6, 11, 12),
            entryId: 'entry_new',
            hookId: 'hook_new',
            assessment: const TrajectoryAssessment(
              lexicalDelta: 0.15,
              driftDelta: -0.20,
              volatilityDelta: -0.05,
              direction: CognitiveDirection.recovering,
            ),
          ),
        ),
        isTrue,
      );
    });

    test(
      'returns empty history when encrypted payload cannot be decrypted',
      () async {
        await prefs.writeString(
          LocalClinicalTrajectoryHistoryStore.prefsKey,
          '{"cipher":"AAAA","nonce":"AAAA","mac":"AAAA"}',
        );

        expect(
          await store.loadRecent(now: DateTime.utc(2026, 6, 12, 12)),
          isEmpty,
        );
        expect(
          await prefs.readString(LocalClinicalTrajectoryHistoryStore.prefsKey),
          '',
        );
      },
    );

    test('serializes wasGrounded in trajectory record json', () {
      final record = StoredTrajectoryRecord(
        date: DateTime.utc(2026, 6, 11, 12),
        directionValue: CognitiveDirection.recovering.name,
        lexicalDelta: 0.15,
        driftDelta: -0.20,
        wasGrounded: true,
      );

      final json = record.toJson();
      expect(json['wasGrounded'], isTrue);
      expect(json['date'], isNotNull);

      final restored = StoredTrajectoryRecord.fromJsonMap(json);
      expect(restored.wasGrounded, isTrue);
      expect(restored.directionValue, 'recovering');
    });

    test('migrates legacy recordedAt payloads during fromJson', () {
      final restored = StoredTrajectoryRecord.fromJson({
        'recordedAt': DateTime.utc(2026, 6, 11, 12).toIso8601String(),
        'direction': CognitiveDirection.recovering.name,
        'lexicalDelta': 0.15,
        'driftDelta': -0.20,
      });

      expect(restored, isNotNull);
      expect(restored!.date, DateTime.utc(2026, 6, 11, 12));
      expect(restored.wasGrounded, isFalse);
    });

    test('migrates legacy prefs key to secure key on read', () async {
      await prefs.writeJsonMap(
        LocalClinicalTrajectoryHistoryStore.legacyPrefsKey,
        {
          'records': [
            {
              'date': DateTime.utc(2026, 6, 11, 12).toIso8601String(),
              'entryId': 'entry_legacy',
              'hookId': 'hook_legacy',
              'lexicalDelta': 0.15,
              'driftDelta': -0.20,
              'volatilityDelta': -0.05,
              'direction': CognitiveDirection.recovering.name,
              'wasGrounded': false,
            },
          ],
        },
      );

      final points = await store.loadRecent(now: DateTime.utc(2026, 6, 12, 12));

      expect(points, hasLength(1));
      expect(
        await prefs.readJsonMap(
          LocalClinicalTrajectoryHistoryStore.legacyPrefsKey,
        ),
        isEmpty,
      );
      expect(
        await prefs.readString(LocalClinicalTrajectoryHistoryStore.prefsKey),
        isNotEmpty,
      );
    });
  });
}
