import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/audio/recording_service.dart';
import 'package:voicememory_mobile/design/empty_archive_experience.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/trust/pending_transcript_recovery_copy.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_copy.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_state.dart';
import 'package:voicememory_mobile/features/voice_capture/record_cta_policy.dart';
import 'package:voicememory_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:voicememory_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';

JournalEntry _degradedVoiceEntry() => JournalEntry(
  id: 'v1',
  createdAt: DateTime(2026, 6, 12),
  transcript:
      '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
  durationSeconds: 12,
  localAudioPath: '/tmp/audio.m4a',
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
  syncStatus: SyncStatus.pendingUpload,
);

JournalEntry _usableVoiceEntry() => JournalEntry(
  id: 'v2',
  createdAt: DateTime(2026, 6, 12),
  transcript: 'I felt pressure before saying yes again today.',
  durationSeconds: 12,
  localAudioPath: '/tmp/audio.m4a',
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: 'I felt pressure before saying yes again today.',
    repeatedSignal: '',
  ),
  syncStatus: SyncStatus.pendingUpload,
);

void main() {
  group('RecordCtaPolicy', () {
    test('first-use mic ready shows Use voice to record + Type instead', () {
      final policy = RecordCtaPolicy.resolve(
        ui: RecordUiState.ready,
        entryCount: 0,
        entryCountLoaded: true,
        showPostSaveLoop: false,
        isDegradedVoiceSave: false,
        micPhase: RecordingPhase.ready,
        micPermissionState: MicrophonePermissionState.granted,
      );

      expect(policy.state, RecordCtaPolicyState.firstUse);
      expect(
        policy.primaryLabel,
        MicrophonePermissionCopy.requestMicrophoneCta,
      );
      expect(policy.secondaryLabels, [EmptyArchiveCopy.typeInsteadCta]);
      expect(policy.action, RecordCtaAction.startRecording);
      expect(policy.micPermissionState, MicrophonePermissionState.granted);
      expect(policy.hideCardRecordCtas, isTrue);
    });

    test('returning mic ready shows Record moment + Type instead', () {
      final policy = RecordCtaPolicy.resolve(
        ui: RecordUiState.ready,
        entryCount: 2,
        entryCountLoaded: true,
        showPostSaveLoop: false,
        isDegradedVoiceSave: false,
        micPhase: RecordingPhase.ready,
        micPermissionState: MicrophonePermissionState.granted,
      );

      expect(policy.state, RecordCtaPolicyState.returning);
      expect(policy.primaryLabel, ConsumerUiCopy.recordMomentCta);
      expect(policy.secondaryLabels, [EmptyArchiveCopy.typeInsteadCta]);
      expect(policy.action, RecordCtaAction.startRecording);
    });

    test('physical mismatch shows Record moment and start_recording', () {
      final policy = RecordCtaPolicy.resolve(
        ui: RecordUiState.ready,
        entryCount: 2,
        entryCountLoaded: true,
        showPostSaveLoop: false,
        isDegradedVoiceSave: false,
        micPhase: RecordingPhase.ready,
        micPermissionState:
            MicrophonePermissionState.grantedWithPermissionHandlerMismatch,
      );

      expect(policy.primaryLabel, ConsumerUiCopy.recordMomentCta);
      expect(policy.action, RecordCtaAction.startRecording);
      expect(
        policy.micPermissionState,
        MicrophonePermissionState.grantedWithPermissionHandlerMismatch,
      );
    });

    test('returning deniedCanAskAgain shows Use voice', () {
      final policy = RecordCtaPolicy.resolve(
        ui: RecordUiState.ready,
        entryCount: 2,
        entryCountLoaded: true,
        showPostSaveLoop: false,
        isDegradedVoiceSave: false,
        micPhase: RecordingPhase.permissionDenied,
        micPermissionState: MicrophonePermissionState.deniedCanAskAgain,
      );

      expect(policy.state, RecordCtaPolicyState.returning);
      expect(
        policy.primaryLabel,
        MicrophonePermissionCopy.requestMicrophoneCta,
      );
      expect(policy.secondaryLabels, [EmptyArchiveCopy.typeInsteadCta]);
      expect(policy.action, RecordCtaAction.requestPermission);
      expect(
        policy.micPermissionState,
        MicrophonePermissionState.deniedCanAskAgain,
      );
    });

    test('first-use deniedCanAskAgain shows Use voice', () {
      final policy = RecordCtaPolicy.resolve(
        ui: RecordUiState.ready,
        entryCount: 0,
        entryCountLoaded: true,
        showPostSaveLoop: false,
        isDegradedVoiceSave: false,
        micPhase: RecordingPhase.permissionDenied,
        micPermissionState: MicrophonePermissionState.deniedCanAskAgain,
      );

      expect(policy.state, RecordCtaPolicyState.firstUse);
      expect(
        policy.primaryLabel,
        MicrophonePermissionCopy.requestMicrophoneCta,
      );
      expect(policy.action, RecordCtaAction.requestPermission);
    });

    test(
      'denied + hasRecorder without prefer flag shows Use voice not Open Settings',
      () {
        final policy = RecordCtaPolicy.resolve(
          ui: RecordUiState.ready,
          entryCount: 2,
          entryCountLoaded: true,
          showPostSaveLoop: false,
          isDegradedVoiceSave: false,
          micPhase: RecordingPhase.permissionDenied,
          micPermissionState: MicrophonePermissionState.deniedCanAskAgain,
        );

        expect(
          policy.primaryLabel,
          MicrophonePermissionCopy.requestMicrophoneCta,
        );
        expect(
          policy.primaryLabel,
          isNot(MicrophonePermissionCopy.openSettingsCta),
        );
        expect(policy.action, RecordCtaAction.requestPermission);
      },
    );

    test(
      'simulator mismatch granted shows Record moment not Open Settings',
      () {
        final policy = RecordCtaPolicy.resolve(
          ui: RecordUiState.ready,
          entryCount: 2,
          entryCountLoaded: true,
          showPostSaveLoop: false,
          isDegradedVoiceSave: false,
          micPhase: RecordingPhase.ready,
          micPermissionState: MicrophonePermissionState.granted,
        );

        expect(policy.primaryLabel, ConsumerUiCopy.recordMomentCta);
        expect(policy.action, RecordCtaAction.startRecording);
        expect(
          policy.primaryLabel,
          isNot(MicrophonePermissionCopy.openSettingsCta),
        );
      },
    );

    test('after requestPermission grant refresh shows Record moment', () {
      final applied = RecordMicrophonePermissionUi.applyMicRefresh(
        phase: RecordingPhase.ready,
        userDeniedThisSession: true,
        currentUi: RecordUiState.requestingPermission,
        ignoreAfterGrant: false,
        fromUserRequest: true,
      );
      expect(applied.ui, RecordUiState.ready);
      expect(applied.userDenied, isFalse);

      final policy = RecordCtaPolicy.resolve(
        ui: applied.ui!,
        entryCount: 2,
        entryCountLoaded: true,
        showPostSaveLoop: false,
        isDegradedVoiceSave: false,
        micPhase: applied.mic!,
        micPermissionState: MicrophonePermissionState.granted,
        userDeniedThisSession: applied.userDenied!,
      );

      expect(policy.primaryLabel, ConsumerUiCopy.recordMomentCta);
      expect(policy.action, RecordCtaAction.startRecording);
    });

    test(
      'simulator mismatch permanentlyDenied CTA is Record moment not Open Settings',
      () {
        final policy = RecordCtaPolicy.resolve(
          ui: RecordUiState.ready,
          entryCount: 2,
          entryCountLoaded: true,
          showPostSaveLoop: false,
          isDegradedVoiceSave: false,
          micPhase: RecordingPhase.ready,
          micPermissionState: MicrophonePermissionState.granted,
        );

        expect(policy.primaryLabel, ConsumerUiCopy.recordMomentCta);
        expect(policy.action, RecordCtaAction.startRecording);
        expect(
          policy.primaryLabel,
          isNot(MicrophonePermissionCopy.openSettingsCta),
        );
      },
    );

    test('returning permanentlyDenied shows Open Settings', () {
      final policy = RecordCtaPolicy.resolve(
        ui: RecordUiState.ready,
        entryCount: 2,
        entryCountLoaded: true,
        showPostSaveLoop: false,
        isDegradedVoiceSave: false,
        micPhase: RecordingPhase.permissionPermanentlyDenied,
        micPermissionState: MicrophonePermissionState.deniedOpenSettings,
      );

      expect(policy.state, RecordCtaPolicyState.returning);
      expect(policy.primaryLabel, MicrophonePermissionCopy.openSettingsCta);
      expect(policy.action, RecordCtaAction.openSettings);
      expect(
        policy.micPermissionState,
        MicrophonePermissionState.deniedOpenSettings,
      );
    });

    test('physical iOS mismatch ready still shows Record moment', () {
      final policy = RecordCtaPolicy.resolve(
        ui: RecordUiState.ready,
        entryCount: 2,
        entryCountLoaded: true,
        showPostSaveLoop: false,
        isDegradedVoiceSave: false,
        micPhase: RecordingPhase.ready,
        micPermissionState: MicrophonePermissionState.granted,
      );

      expect(policy.primaryLabel, ConsumerUiCopy.recordMomentCta);
      expect(policy.action, RecordCtaAction.startRecording);
      expect(policy.micPhase, RecordingPhase.ready);
    });

    test('recording shows Stop recording only', () {
      final policy = RecordCtaPolicy.resolve(
        ui: RecordUiState.recording,
        entryCount: 1,
        entryCountLoaded: true,
        showPostSaveLoop: false,
        isDegradedVoiceSave: false,
      );

      expect(policy.state, RecordCtaPolicyState.recording);
      expect(policy.primaryLabel, ConsumerUiCopy.stopRecordingCta);
      expect(policy.secondaryLabels, isEmpty);
      expect(policy.hideCardRecordCtas, isTrue);
    });

    test('post-save success shows Done + Record another', () {
      final policy = RecordCtaPolicy.resolve(
        ui: RecordUiState.done,
        entryCount: 1,
        entryCountLoaded: true,
        showPostSaveLoop: false,
        isDegradedVoiceSave: false,
      );

      expect(policy.state, RecordCtaPolicyState.postSaveSuccess);
      expect(policy.primaryLabel, ConsumerUiCopy.doneCta);
      expect(policy.secondaryLabels, [ConsumerUiCopy.recordAnotherCta]);
    });

    test(
      'transcript present after analysis failure stays post-save success',
      () {
        final policy = RecordCtaPolicy.resolve(
          ui: RecordUiState.done,
          entryCount: 1,
          entryCountLoaded: true,
          showPostSaveLoop: false,
          isDegradedVoiceSave: false,
          lastSavedEntry: _usableVoiceEntry(),
        );

        expect(policy.state, RecordCtaPolicyState.postSaveSuccess);
        expect(policy.primaryLabel, ConsumerUiCopy.doneCta);
        expect(
          policy.primaryLabel,
          isNot(PendingTranscriptRecoveryCopy.primaryAction),
        );
      },
    );

    test('degraded post-save shows typed fallback actions', () {
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
      expect(policy.secondaryLabels, [
        VoiceCaptureCopy.recordAgainCta,
        ConsumerUiCopy.doneCta,
      ]);
    });

    test('permission blocked shows Open Settings and Type Instead', () {
      final policy = RecordCtaPolicy.resolve(
        ui: RecordUiState.permissionBlocked,
        entryCount: 0,
        entryCountLoaded: true,
        showPostSaveLoop: false,
        isDegradedVoiceSave: false,
        micPhase: RecordingPhase.permissionDenied,
        micPermissionState: MicrophonePermissionState.deniedCanAskAgain,
        userDeniedThisSession: true,
      );

      expect(policy.state, RecordCtaPolicyState.permissionBlocked);
      expect(policy.primaryLabel, MicrophonePermissionCopy.openSettingsCta);
      expect(policy.action, RecordCtaAction.openSettings);
      expect(policy.secondaryLabels, [EmptyArchiveCopy.typeInsteadCta]);
      expect(policy.hideCardRecordCtas, isTrue);
      expect(policy.primaryLabel, isNotNull);
      expect(policy.action, isNotNull);
    });

    test('requestable denied state shows Use voice', () {
      final policy = RecordCtaPolicy.resolve(
        ui: RecordUiState.ready,
        entryCount: 0,
        entryCountLoaded: true,
        showPostSaveLoop: false,
        isDegradedVoiceSave: false,
        micPhase: RecordingPhase.permissionDenied,
        micPermissionState: MicrophonePermissionState.deniedCanAskAgain,
        userDeniedThisSession: false,
      );

      expect(
        policy.primaryLabel,
        MicrophonePermissionCopy.requestMicrophoneCta,
      );
      expect(policy.action, RecordCtaAction.requestPermission);
      expect(policy.secondaryLabels, [EmptyArchiveCopy.typeInsteadCta]);
    });

    test('session denial on ready shows Open Settings', () {
      final policy = RecordCtaPolicy.resolve(
        ui: RecordUiState.ready,
        entryCount: 0,
        entryCountLoaded: true,
        showPostSaveLoop: false,
        isDegradedVoiceSave: false,
        micPhase: RecordingPhase.permissionDenied,
        micPermissionState: MicrophonePermissionState.deniedCanAskAgain,
        userDeniedThisSession: true,
      );

      expect(policy.primaryLabel, MicrophonePermissionCopy.openSettingsCta);
      expect(policy.action, RecordCtaAction.openSettings);
    });

    test('permanentlyDenied maps to Open Settings', () {
      final policy = RecordCtaPolicy.resolve(
        ui: RecordUiState.permissionBlocked,
        entryCount: 0,
        entryCountLoaded: true,
        showPostSaveLoop: false,
        isDegradedVoiceSave: false,
        micPhase: RecordingPhase.permissionPermanentlyDenied,
        micPermissionState: MicrophonePermissionState.deniedOpenSettings,
        sessionRequiresOpenSettings: true,
      );

      expect(policy.primaryLabel, MicrophonePermissionCopy.openSettingsCta);
      expect(policy.action, RecordCtaAction.openSettings);
      expect(
        policy.micPermissionState,
        MicrophonePermissionState.deniedOpenSettings,
      );
    });
  });
}
