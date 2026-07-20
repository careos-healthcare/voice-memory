import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:voicememory_mobile/features/curiosity_loop/infrastructure/interceptors/cognitive_alert_interceptor.dart';
import 'package:voicememory_mobile/features/curiosity_loop/infrastructure/interceptors/curiosity_loop_trigger_interceptor.dart';
import 'package:voicememory_mobile/features/curiosity_loop/repositories/curiosity_loop_repository.dart';
import 'package:voicememory_mobile/features/curiosity_loop/services/clinical_cognitive_telemetry.dart';
import 'package:voicememory_mobile/features/journal/domain/interceptors/journal_save_interceptor.dart';
import 'package:voicememory_mobile/features/journal/infrastructure/journal_save_interceptor_pipeline.dart';
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

  JournalEntry entry({
    required String id,
    String transcript = 'Sample transcript with enough words.',
    CognitiveBiomarkers? biomarkers,
  }) {
    return JournalEntry(
      id: id,
      createdAt: DateTime.utc(2026, 6, 12, 12),
      transcript: transcript,
      durationSeconds: 20,
      reflection: reflection,
      syncStatus: SyncStatus.localOnly,
      biomarkers: biomarkers,
    );
  }

  group('JournalSaveInterceptorPipeline', () {
    test('execute runs all interceptors', () async {
      final seen = <String>[];
      final pipeline = JournalSaveInterceptorPipeline([
        _RecordingInterceptor('first', seen),
        _RecordingInterceptor('second', seen),
      ]);

      await pipeline.execute(entry(id: 'entry_1'));

      expect(seen, ['first', 'second']);
    });
  });

  group('CognitiveAlertInterceptor', () {
    test('emits clinical drift telemetry for high emotional volatility', () async {
      final events = <String>[];
      final warnings = <ClinicalDriftWarning>[];
      final interceptor = CognitiveAlertInterceptor(
        telemetry: ClinicalCognitiveTelemetry(
          sink: (event, _) => events.add(event),
        ),
        onWarning: warnings.add,
      );

      await interceptor.onEntrySaved(
        entry(
          id: 'volatile_entry',
          biomarkers: const CognitiveBiomarkers(
            lexicalDiversity: 0.7,
            cohesionDrift: 0.2,
            emotionalVolatility: 0.91,
          ),
        ),
      );

      expect(events, [ClinicalCognitiveTelemetry.clinicalDriftDetectedEvent]);
      expect(warnings.single.driftType,
          CognitiveAlertInterceptor.emotionalVolatilityDriftType);
      expect(warnings.single.score, 0.91);
    });

    test('emits clinical drift telemetry for high cohesion drift', () async {
      final warnings = <ClinicalDriftWarning>[];
      final interceptor = CognitiveAlertInterceptor(onWarning: warnings.add);

      await interceptor.onEntrySaved(
        entry(
          id: 'disjointed_entry',
          biomarkers: const CognitiveBiomarkers(
            lexicalDiversity: 0.7,
            cohesionDrift: 0.85,
            emotionalVolatility: 0.3,
          ),
        ),
      );

      expect(warnings.single.driftType,
          CognitiveAlertInterceptor.cohesionDriftType);
      expect(warnings.single.score, 0.85);
    });

    test('ignores entries without biomarkers', () async {
      final warnings = <ClinicalDriftWarning>[];
      final interceptor = CognitiveAlertInterceptor(onWarning: warnings.add);

      await interceptor.onEntrySaved(entry(id: 'plain_entry'));

      expect(warnings, isEmpty);
    });
  });

  group('CuriosityLoopTriggerInterceptor', () {
    late Directory tempDir;
    late MobilePrefsStore prefs;
    late LocalCuriosityLoopRepository repository;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_curiosity_loop_repo_');
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      await LocalCuriosityLoopRepository.resetForTest(prefs);
      repository = LocalCuriosityLoopRepository.forPrefs(prefs);
    });

    test('seeds memory recall check when biomarkers are valid', () async {
      final seededAt = DateTime.utc(2026, 6, 12, 15);
      final interceptor = CuriosityLoopTriggerInterceptor(
        repository: repository,
        clock: () => seededAt,
      );

      await interceptor.onEntrySaved(
        entry(
          id: 'verified_entry',
          biomarkers: const CognitiveBiomarkers(
            lexicalDiversity: 0.72,
            cohesionDrift: 0.18,
            emotionalVolatility: 0.41,
          ),
        ),
      );

      expect(
        await repository.fetchPendingMemoryRecallSeed(),
        CuriosityMemoryRecallSeed(
          sourceEntryId: 'verified_entry',
          seededAt: seededAt,
        ),
      );
    });

    test('does not seed when biomarkers are missing', () async {
      final interceptor = CuriosityLoopTriggerInterceptor(
        repository: repository,
      );

      await interceptor.onEntrySaved(entry(id: 'missing_biomarkers'));

      expect(await repository.fetchPendingMemoryRecallSeed(), isNull);
    });

    test('does not overwrite an existing pending seed', () async {
      final seededAt = DateTime.utc(2026, 6, 12, 10);
      await repository.seedMemoryRecallCheck(
        sourceEntryId: 'existing_entry',
        seededAt: seededAt,
      );
      final interceptor = CuriosityLoopTriggerInterceptor(
        repository: repository,
      );

      await interceptor.onEntrySaved(
        entry(
          id: 'new_entry',
          biomarkers: const CognitiveBiomarkers(
            lexicalDiversity: 0.72,
            cohesionDrift: 0.18,
            emotionalVolatility: 0.41,
          ),
        ),
      );

      expect(
        await repository.fetchPendingMemoryRecallSeed(),
        CuriosityMemoryRecallSeed(
          sourceEntryId: 'existing_entry',
          seededAt: seededAt,
        ),
      );
    });
  });
}

class _RecordingInterceptor implements JournalSaveInterceptor {
  _RecordingInterceptor(this.label, this.seen);

  final String label;
  final List<String> seen;

  @override
  Future<void> onEntrySaved(JournalEntry entry) async {
    seen.add(label);
  }
}
