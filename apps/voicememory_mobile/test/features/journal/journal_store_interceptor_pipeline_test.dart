import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/infrastructure/interceptors/cognitive_alert_interceptor.dart';
import 'package:voicememory_mobile/features/curiosity_loop/infrastructure/interceptors/curiosity_loop_trigger_interceptor.dart';
import 'package:voicememory_mobile/features/curiosity_loop/repositories/curiosity_loop_repository.dart';
import 'package:voicememory_mobile/features/curiosity_loop/services/clinical_cognitive_telemetry.dart';
import 'package:voicememory_mobile/features/journal/infrastructure/journal_save_interceptor_pipeline.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late Directory tempDir;
  late JournalStore store;
  late MobilePrefsStore prefs;
  late LocalCuriosityLoopRepository curiosityLoopRepository;
  late InMemoryPrivateDataEncryptionKeyStore keyStore;
  late List<Map<String, Object>> telemetryEvents;
  late List<ClinicalDriftWarning> warnings;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('vm_journal_interceptors_');
    keyStore = InMemoryPrivateDataEncryptionKeyStore();
    prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
    await LocalCuriosityLoopRepository.resetForTest(prefs);
    curiosityLoopRepository = LocalCuriosityLoopRepository.forPrefs(prefs);
    telemetryEvents = [];
    warnings = [];

    store = await JournalStore.open(
      '${tempDir.path}/entries.json',
      keyStore: keyStore,
      saveInterceptorPipeline: JournalSaveInterceptorPipeline([
        CognitiveAlertInterceptor(
          telemetry: ClinicalCognitiveTelemetry(
            sink: (event, meta) => telemetryEvents.add({
              'event': event,
              ...meta,
            }),
          ),
          onWarning: warnings.add,
        ),
        CuriosityLoopTriggerInterceptor(
          repository: curiosityLoopRepository,
          clock: () => DateTime.utc(2026, 6, 12, 16),
        ),
      ]),
    );
  });

  const reflection = Reflection(
    mood: 'calm',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up again today.',
    repeatedSignal: '',
  );

  JournalEntry entry({
    required String id,
    required String transcript,
  }) {
    return JournalEntry(
      id: id,
      createdAt: DateTime.utc(2026, 6, 12, 12),
      transcript: transcript,
      durationSeconds: 20,
      reflection: reflection,
      syncStatus: SyncStatus.localOnly,
    );
  }

  test('high volatility save triggers clinical drift alert interceptor', () async {
    await store.save(
      entry(
        id: 'volatile_entry',
        transcript: 'WOW!!! NO WAY!!! STOP!!! THIS IS INSANE!!!',
      ),
    );

    expect(
      telemetryEvents.map((event) => event['event']),
      contains(ClinicalCognitiveTelemetry.clinicalDriftDetectedEvent),
    );
    expect(
      warnings.any(
        (warning) =>
            warning.driftType ==
            CognitiveAlertInterceptor.emotionalVolatilityDriftType,
      ),
      isTrue,
    );
  });

  test('verified save updates curiosity loop memory recall seed', () async {
    await store.save(
      entry(
        id: 'verified_entry',
        transcript: 'One two three four five six seven eight.',
      ),
    );

    expect(
      await curiosityLoopRepository.fetchPendingMemoryRecallSeed(),
      CuriosityMemoryRecallSeed(
        sourceEntryId: 'verified_entry',
        seededAt: DateTime.utc(2026, 6, 12, 16),
      ),
    );
  });

  test('disjointed transcript can trigger cohesion drift alert', () async {
    await store.save(
      entry(
        id: 'disjointed_entry',
        transcript:
            'One. One two three four five six seven eight nine ten eleven.',
      ),
    );

    expect(
      warnings.any(
        (warning) =>
            warning.driftType == CognitiveAlertInterceptor.cohesionDriftType,
      ),
      isTrue,
    );
    expect(await curiosityLoopRepository.fetchPendingMemoryRecallSeed(), isNotNull);
  });
}
