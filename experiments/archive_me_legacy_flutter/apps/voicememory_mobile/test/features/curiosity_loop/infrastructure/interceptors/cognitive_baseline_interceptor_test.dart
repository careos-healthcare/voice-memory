import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:voicememory_mobile/features/curiosity_loop/infrastructure/interceptors/cognitive_baseline_interceptor.dart';
import 'package:voicememory_mobile/features/curiosity_loop/repositories/cognitive_baseline_store.dart';
import 'package:voicememory_mobile/features/curiosity_loop/services/cognitive_baseline_telemetry.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

void main() {
  const reflection = Reflection(
    mood: 'calm',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up again today.',
    repeatedSignal: '',
  );

  const firstBiomarkers = CognitiveBiomarkers(
    lexicalDiversity: 0.40,
    cohesionDrift: 0.50,
    emotionalVolatility: 0.60,
  );

  const secondBiomarkers = CognitiveBiomarkers(
    lexicalDiversity: 0.70,
    cohesionDrift: 0.30,
    emotionalVolatility: 0.20,
  );

  JournalEntry entry({required String id, CognitiveBiomarkers? biomarkers}) {
    return JournalEntry(
      id: id,
      createdAt: DateTime.utc(2026, 6, 12, 12),
      transcript: 'Sample transcript with enough words.',
      durationSeconds: 20,
      reflection: reflection,
      syncStatus: SyncStatus.localOnly,
      biomarkers: biomarkers,
    );
  }

  group('LocalCognitiveBaselineStore', () {
    late Directory tempDir;
    late MobilePrefsStore prefs;
    late LocalCognitiveBaselineStore store;
    final testMasterKey = List<int>.generate(32, (i) => i);

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_cognitive_baseline_');
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      await LocalCognitiveBaselineStore.resetForTest(prefs);
      store = LocalCognitiveBaselineStore.forPrefs(
        prefs,
        masterKeyBytes: testMasterKey,
      );
    });

    test('persists and reloads baseline snapshots', () async {
      final snapshot = CognitiveBaselineSnapshot(
        baseline: firstBiomarkers,
        lastEntryId: 'entry_1',
        updatedAt: DateTime.utc(2026, 6, 12, 12),
        observationCount: 1,
      );

      await store.saveSnapshot(snapshot);

      expect(await store.loadSnapshot(), snapshot);
    });

    test('saveSnapshot returns true on successful encrypted write', () async {
      final snapshot = CognitiveBaselineSnapshot(
        baseline: firstBiomarkers,
        lastEntryId: 'entry_1',
        updatedAt: DateTime.utc(2026, 6, 12, 12),
        observationCount: 1,
      );

      expect(await store.saveSnapshot(snapshot), isTrue);
    });

    test(
      'stores encrypted payloads without plaintext biomarker values',
      () async {
        final snapshot = CognitiveBaselineSnapshot(
          baseline: firstBiomarkers,
          lastEntryId: 'entry_1',
          updatedAt: DateTime.utc(2026, 6, 12, 12),
          observationCount: 1,
        );

        await store.saveSnapshot(snapshot);

        final rawPrefs = await prefs.file.readAsString();
        expect(rawPrefs.contains('0.4'), isFalse);
        expect(rawPrefs.contains('cipher'), isTrue);
      },
    );

    test('returns null when encrypted payload cannot be decrypted', () async {
      await prefs.writeString(
        LocalCognitiveBaselineStore.prefsKey,
        '{"cipher":"AAAA","nonce":"AAAA","mac":"AAAA"}',
      );

      expect(await store.loadSnapshot(), isNull);
      expect(await prefs.readString(LocalCognitiveBaselineStore.prefsKey), '');
    });
  });

  group('CognitiveBaselineInterceptor', () {
    late Directory tempDir;
    late MobilePrefsStore prefs;
    late LocalCognitiveBaselineStore store;
    late List<Map<String, Object>> telemetryEvents;
    late List<CognitiveBaselineUpdateRecord> updates;
    final testMasterKey = List<int>.generate(32, (i) => i);

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_baseline_interceptor_');
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      await LocalCognitiveBaselineStore.resetForTest(prefs);
      store = LocalCognitiveBaselineStore.forPrefs(
        prefs,
        masterKeyBytes: testMasterKey,
      );
      telemetryEvents = [];
      updates = [];
    });

    CognitiveBaselineInterceptor buildInterceptor() {
      return CognitiveBaselineInterceptor(
        baselineStore: store,
        telemetry: CognitiveBaselineTelemetry(
          sink: (event, meta) => telemetryEvents.add({'event': event, ...meta}),
        ),
        onBaselineUpdated: updates.add,
        clock: () => DateTime.utc(2026, 6, 12, 16),
      );
    }

    test('ignores entries without biomarkers', () async {
      final interceptor = buildInterceptor();

      await interceptor.onEntrySaved(entry(id: 'plain_entry'));

      expect(await store.loadSnapshot(), isNull);
      expect(telemetryEvents, isEmpty);
    });

    test('seeds baseline on first verified observation', () async {
      final interceptor = buildInterceptor();

      await interceptor.onEntrySaved(
        entry(id: 'entry_1', biomarkers: firstBiomarkers),
      );

      final snapshot = await store.loadSnapshot();
      expect(snapshot?.baseline, firstBiomarkers);
      expect(snapshot?.observationCount, 1);
      expect(snapshot?.lastEntryId, 'entry_1');
      expect(
        telemetryEvents.single['event'],
        CognitiveBaselineTelemetry.baselineUpdatedEvent,
      );
      expect(updates.single.previousBaseline, isNull);
    });

    test('updates persisted baseline using EWMA on subsequent saves', () async {
      final interceptor = buildInterceptor();

      await interceptor.onEntrySaved(
        entry(id: 'entry_1', biomarkers: firstBiomarkers),
      );
      await interceptor.onEntrySaved(
        entry(id: 'entry_2', biomarkers: secondBiomarkers),
      );

      final snapshot = await store.loadSnapshot();
      expect(snapshot?.observationCount, 2);
      expect(snapshot?.baseline.lexicalDiversity, closeTo(0.49, 0.0001));
      expect(snapshot?.baseline.cohesionDrift, closeTo(0.44, 0.0001));
      expect(snapshot?.baseline.emotionalVolatility, closeTo(0.48, 0.0001));
      expect(telemetryEvents, hasLength(2));
      expect(updates.last.previousBaseline, firstBiomarkers);
    });
  });
}
