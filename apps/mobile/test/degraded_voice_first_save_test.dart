import 'package:archiveme_mobile/design/empty_archive_experience.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/onboarding/record_return_pro_state.dart';
import 'package:archiveme_mobile/features/recording/recording_screen.dart';
import 'package:archiveme_mobile/features/trust/pending_transcript_recovery_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/record_cta_policy.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_models.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_storage_sandbox.dart';

JournalEntry _voiceEntry({
  String id = 'v1',
  String transcript = '',
  String? localAudioPath = '/tmp/audio.m4a',
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript: transcript,
  durationSeconds: 20,
  localAudioPath: localAudioPath,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

JournalEntry _usableVoiceEntry({String id = 'v1'}) => _voiceEntry(
  id: id,
  transcript: 'I said yes when I had no capacity left today.',
);

JournalEntry _degradedVoiceEntry({String id = 'v1'}) => _voiceEntry(
  id: id,
  transcript:
      '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
);

bool firstSavePayoffEligible({
  required int entryCount,
  required JournalEntry savedEntry,
}) =>
    entryCount == 1 && !VoiceCaptureQuality.isDegradedVoiceCapture(savedEntry);

void main() {
  group('degraded voice first save recovery', () {
    late TestStorageSandbox sandbox;

    setUp(() async {
      sandbox = TestStorageSandbox.create();
      await AppServices.resetForTest(journalPath: sandbox.journalPath);
    });

    tearDown(() => sandbox.dispose());

    test('degraded voice draft does not count as archive evidence', () {
      final entries = [_degradedVoiceEntry()];
      expect(archiveEvidenceReflectionCount(entries), 0);
      expect(isIntentionalEmptyArchive(entries), isTrue);
    });

    test('usable voice entry counts as first archive evidence', () {
      final entries = [_usableVoiceEntry()];
      expect(archiveEvidenceReflectionCount(entries), 1);
      expect(isIntentionalEmptyArchive(entries), isFalse);
    });

    test('low-quality voice save does not qualify for first-save payoff', () {
      final degraded = _degradedVoiceEntry();
      expect(
        firstSavePayoffEligible(entryCount: 1, savedEntry: degraded),
        isFalse,
      );
      expect(VoiceCaptureQuality.isDegradedVoiceCapture(degraded), isTrue);
    });

    test('good transcript still qualifies for first-save payoff', () {
      final usable = _usableVoiceEntry();
      expect(
        firstSavePayoffEligible(entryCount: 1, savedEntry: usable),
        isTrue,
      );
    });

    test(
      'typed recovery clears degraded state and enables first-save payoff',
      () async {
        final degraded = _degradedVoiceEntry();
        await AppServices.instance.journalStore.save(degraded);

        final result = (await AppServices.instance.pipeline
                .attachTypedTextToVoiceEntry(
                  entry: degraded,
                  transcript: 'I said yes when I had no capacity left.',
                ))
            .getOrThrow();

        expect(
          VoiceCaptureQuality.isDegradedVoiceCapture(result.entry),
          isFalse,
        );
        expect(
          VoiceCaptureQuality.displayTextLength(result.entry),
          greaterThan(0),
        );
        expect(
          firstSavePayoffEligible(entryCount: 1, savedEntry: result.entry),
          isTrue,
        );
        expect(archiveEvidenceReflectionCount([result.entry]), 1);
      },
    );

    test('degraded post-save policy keeps typed recovery and record again', () {
      final policy = RecordCtaPolicy.resolve(
        ui: RecordUiState.done,
        entryCount: 1,
        entryCountLoaded: true,
        showPostSaveLoop: false,
        isDegradedVoiceSave: true,
        lastSavedEntry: _degradedVoiceEntry(),
      );

      expect(policy.state, RecordCtaPolicyState.postSaveDegraded);
      expect(policy.primaryLabel, PendingTranscriptRecoveryCopy.primaryAction);
      expect(policy.secondaryLabels, contains(VoiceCaptureCopy.recordAgainCta));
    });

    test('good post-save policy keeps normal success path', () {
      final policy = RecordCtaPolicy.resolve(
        ui: RecordUiState.done,
        entryCount: 1,
        entryCountLoaded: true,
        showPostSaveLoop: false,
        isDegradedVoiceSave: false,
        lastSavedEntry: _usableVoiceEntry(),
      );

      expect(policy.state, RecordCtaPolicyState.postSaveSuccess);
      expect(
        policy.primaryLabel,
        isNot(PendingTranscriptRecoveryCopy.primaryAction),
      );
    });

    test('recovery copy matches pending transcript spec', () {
      expect(
        PendingTranscriptRecoveryCopy.postSaveTitle,
        'Saved, but ArchiveMe could not hear enough.',
      );
      expect(
        PendingTranscriptRecoveryCopy.postSaveBody,
        'Add one short sentence so ArchiveMe can compare this moment later.',
      );
      expect(PendingTranscriptRecoveryCopy.primaryAction, 'Add what you said');
      expect(RecordReturnProCopy.evidenceTitle, 'Saved.');
    });
  });
}