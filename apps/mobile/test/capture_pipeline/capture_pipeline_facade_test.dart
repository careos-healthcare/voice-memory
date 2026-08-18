import 'dart:io';

import 'package:archiveme_mobile/features/moment_quality/post_save_moment_detail_model.dart';
import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_facade.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_models.dart';
import 'package:archiveme_mobile/services/capture_pipeline/voice_capture_handler.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_pipeline_test_support.dart';

void main() {
  setUp(ApiUsageGuard.resetForTest);

  group('CapturePipelineFacade', () {
    late Directory tempDir;
    late JournalStore journal;
    late MobilePrefsStore prefs;
    late RemoteProcessingConsentStore consentStore;
    late CapturePipelineFacade facade;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('capture_pipeline_facade_');
      journal = JournalStore(file: File('${tempDir.path}/journal.json'));
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      await OnDeviceProcessingStore.resetForTest();
      await OnDeviceProcessingStore.setEnabled(false);
      consentStore = RemoteProcessingConsentStore(prefs);
      await consentStore.grant();
      final built = await buildCapturePipelineFacade(
        prefs: prefs,
        journal: journal,
        consentStore: consentStore,
      );
      facade = built.facade;
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('saveTextThought rejects empty transcript', () async {
      final outcome = await facade.saveTextThought(transcript: '   ');
      expect(outcome.isLeft(), isTrue);
    });

    test('saveTextThought saves locally when consent is withdrawn', () async {
      await consentStore.withdraw();

      final result = (await facade.saveTextThought(
        transcript: 'I keep saying I want more balance but I still take on extra work.',
      )).getOrThrow();

      expect(result.localSaved, isTrue);
      expect(result.syncSucceeded, isFalse);
      expect(result.syncNote, isNotNull);
      final saved = await journal.loadAll();
      expect(saved, hasLength(1));
      expect(saved.single.transcript, contains('balance'));
    });

    test('saveTextThought analyzes and saves when consent is granted', () async {
      final stages = <PipelineStage>[];
      final result = (await facade.saveTextThought(
        transcript: 'I keep saying I want more balance but I still take on extra work every week.',
        onStage: stages.add,
      )).getOrThrow();

      expect(result.localSaved, isTrue);
      expect(result.syncSucceeded, isTrue);
      expect(stages, contains(PipelineStage.analyzing));
      expect(stages.last, PipelineStage.done);
      final saved = await journal.loadAll();
      expect(saved.single.verifiedProof, isNotNull);
    });

    test('attachTypedTextToVoiceEntry rejects empty transcript', () async {
      final entry = JournalEntry(
        id: 'voice-entry',
        createdAt: DateTime.utc(2026, 8, 18),
        transcript: '[draft]',
        durationSeconds: 12,
        reflection: const Reflection(
          mood: 'neutral',
          emotionalIntensity: 0,
          recurringThemes: [],
          exactLanguagePattern: '',
          concreteObservation: '',
          repeatedSignal: '',
        ),
        syncStatus: SyncStatus.pendingUpload,
        localAudioPath: '/tmp/voice.m4a',
      );

      final outcome = await facade.attachTypedTextToVoiceEntry(
        entry: entry,
        transcript: ' ',
      );
      expect(outcome.isLeft(), isTrue);
    });

    test('saveLiveVoiceTranscript rejects empty transcript', () async {
      final outcome = await facade.saveLiveVoiceTranscript(
        transcript: '',
        durationSeconds: 10,
      );
      expect(outcome.isLeft(), isTrue);
    });

    test('partial handler injection shares one middleware instance', () {
      final voiceHandler = VoiceCaptureHandler(
        deps: facade.dependencies,
        middleware: facade.middleware,
      );
      final partialFacade = CapturePipelineFacade(
        dependencies: facade.dependencies,
        voiceHandler: voiceHandler,
      );

      expect(
        partialFacade.middleware,
        same(partialFacade.textHandlerMiddlewareForTest),
      );
    });

    test(
      'findByCaptureContextTag lookup avoids creating duplicate linked entries',
      () async {
        final parent = JournalEntry(
          id: 'parent-entry',
          createdAt: DateTime.utc(2026, 8, 18),
          transcript: 'Parent moment',
          durationSeconds: 12,
          reflection: const Reflection(
            mood: 'neutral',
            emotionalIntensity: 0,
            recurringThemes: [],
            exactLanguagePattern: '',
            concreteObservation: '',
            repeatedSignal: '',
          ),
        );
        await journal.save(parent);

        (await facade.savePostSaveMomentDetail(
          parentEntry: parent,
          detailType: PostSaveMomentDetailType.situation,
          detailText: 'At the office.',
        )).getOrThrow();
        (await facade.savePostSaveMomentDetail(
          parentEntry: parent,
          detailType: PostSaveMomentDetailType.situation,
          detailText: 'Updated detail.',
        )).getOrThrow();

        final all = await journal.loadAll();
        expect(all, hasLength(2));
        final detail = all.firstWhere((entry) => entry.id != parent.id);
        expect(detail.transcript, 'Updated detail.');
      },
    );

    test(
      'concurrent savePostSaveMomentDetail creates exactly one linked entry',
      () async {
        final parent = JournalEntry(
          id: 'race-parent',
          createdAt: DateTime.utc(2026, 8, 18),
          transcript: 'Race parent',
          durationSeconds: 8,
          reflection: const Reflection(
            mood: 'neutral',
            emotionalIntensity: 0,
            recurringThemes: [],
            exactLanguagePattern: '',
            concreteObservation: '',
            repeatedSignal: '',
          ),
        );
        await journal.save(parent);

        await Future.wait([
          facade.savePostSaveMomentDetail(
            parentEntry: parent,
            detailType: PostSaveMomentDetailType.changed,
            detailText: 'First concurrent save.',
          ),
          facade.savePostSaveMomentDetail(
            parentEntry: parent,
            detailType: PostSaveMomentDetailType.changed,
            detailText: 'Second concurrent save.',
          ),
        ]);

        final all = await journal.loadAll();
        expect(all, hasLength(2));
      },
    );

    test('savePostSaveMomentDetail preserves inner exception on failure', () async {
      final parent = JournalEntry(
        id: 'fail-parent',
        createdAt: DateTime.utc(2026, 8, 18),
        transcript: 'Failure parent',
        durationSeconds: 8,
        reflection: const Reflection(
          mood: 'neutral',
          emotionalIntensity: 0,
          recurringThemes: [],
          exactLanguagePattern: '',
          concreteObservation: '',
          repeatedSignal: '',
        ),
      );

      final throwingJournal = _ThrowingJournalStore(
        file: File('${tempDir.path}/throwing-journal.json'),
      );
      await throwingJournal.save(parent);

      final injected = StateError('journal save failed');
      throwingJournal.nextError = injected;

      final built = await buildCapturePipelineFacade(
        prefs: prefs,
        journal: throwingJournal,
        consentStore: consentStore,
      );
      final failingFacade = built.facade;

      final outcome = await failingFacade.savePostSaveMomentDetail(
        parentEntry: parent,
        detailType: PostSaveMomentDetailType.stoodOut,
        detailText: 'Should fail.',
      );

      expect(outcome.isLeft(), isTrue);
      outcome.fold(
        (failure) {
          expect(identical(failure.innerException, injected), isTrue);
          expect(identical(failure.cause, injected), isTrue);
        },
        (_) => fail('expected Left'),
      );
    });
  });
}

class _ThrowingJournalStore extends JournalStore {
  _ThrowingJournalStore({required super.file});

  Object? nextError;

  @override
  Future<void> save(
    JournalEntry entry, {
    String first25Source = 'journal_save',
    String captureKind = 'typed',
  }) async {
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
    return super.save(
      entry,
      first25Source: first25Source,
      captureKind: captureKind,
    );
  }
}
