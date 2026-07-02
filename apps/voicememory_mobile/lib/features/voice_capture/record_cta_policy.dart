import 'package:flutter/foundation.dart';

import '../../audio/recording_service.dart';
import '../../product/consumer_ui_copy.dart';
import 'microphone_permission_copy.dart';
import 'microphone_permission_state.dart';
import 'record_microphone_permission_ui.dart';
import 'voice_capture_post_save.dart';
import '../../models/journal_entry.dart';
import '../../design/empty_archive_experience.dart';
import '../archive_proof/visible_archive_proof_copy.dart';
import 'voice_capture_copy.dart';

/// High-level Record screen moment for CTA selection.
enum RecordCtaPolicyState {
  firstUse,
  returning,
  recording,
  postSaveSuccess,
  postSaveDegraded,
  permissionBlocked,
  processing,
  error,
  idle,
}

extension RecordCtaPolicyStateLabel on RecordCtaPolicyState {
  String get logLabel => switch (this) {
    RecordCtaPolicyState.firstUse => 'first_use',
    RecordCtaPolicyState.returning => 'returning',
    RecordCtaPolicyState.recording => 'recording',
    RecordCtaPolicyState.postSaveSuccess => 'post_save_success',
    RecordCtaPolicyState.postSaveDegraded => 'post_save_degraded',
    RecordCtaPolicyState.permissionBlocked => 'permission_blocked',
    RecordCtaPolicyState.processing => 'processing',
    RecordCtaPolicyState.error => 'error',
    RecordCtaPolicyState.idle => 'idle',
  };
}

extension RecordCtaActionLabel on RecordCtaAction {
  String get logLabel => switch (this) {
    RecordCtaAction.startRecording => 'start_recording',
    RecordCtaAction.requestPermission => 'request_permission',
    RecordCtaAction.routeToBlockedPanel => 'route_to_blocked_panel',
    RecordCtaAction.openSettings => 'open_settings',
  };
}

class RecordCtaPolicyResolution {
  const RecordCtaPolicyResolution({
    required this.state,
    this.primaryLabel,
    this.secondaryLabels = const [],
    this.showMainBottomCta = false,
    this.hideCardRecordCtas = false,
    this.showTypeInsteadSecondary = false,
    this.action,
    this.micPhase = RecordingPhase.idle,
    this.micPermissionState = MicrophonePermissionState.unknown,
  });

  final RecordCtaPolicyState state;
  final String? primaryLabel;
  final List<String> secondaryLabels;
  final bool showMainBottomCta;
  final bool hideCardRecordCtas;
  final bool showTypeInsteadSecondary;
  final RecordCtaAction? action;
  final RecordingPhase micPhase;
  final MicrophonePermissionState micPermissionState;
}

/// Single source of truth for Record screen voice CTA labels and visibility.
abstract class RecordCtaPolicy {
  RecordCtaPolicy._();

  static const logPrefix = 'ARCHIVEME_RECORD_CTA_POLICY:';

  static RecordCtaPolicyResolution resolve({
    required RecordUiState ui,
    required int entryCount,
    required bool entryCountLoaded,
    required bool showPostSaveLoop,
    required bool isDegradedVoiceSave,
    RecordingPhase micPhase = RecordingPhase.ready,
    MicrophonePermissionState micPermissionState =
        MicrophonePermissionState.granted,
    bool userDeniedThisSession = false,
    bool sessionRequiresOpenSettings = false,
    JournalEntry? lastSavedEntry,
  }) {
    if (ui == RecordUiState.permissionBlocked) {
      return _blockedPermissionPolicy(
        micPhase: micPhase,
        micPermissionState: micPermissionState,
        userDeniedThisSession: userDeniedThisSession,
        sessionRequiresOpenSettings: sessionRequiresOpenSettings,
      );
    }

    if (ui == RecordUiState.processing) {
      return RecordCtaPolicyResolution(
        state: RecordCtaPolicyState.processing,
        hideCardRecordCtas: true,
        micPhase: micPhase,
        micPermissionState: micPermissionState,
      );
    }

    if (ui == RecordUiState.recording) {
      return RecordCtaPolicyResolution(
        state: RecordCtaPolicyState.recording,
        primaryLabel: ConsumerUiCopy.stopRecordingCta,
        showMainBottomCta: true,
        hideCardRecordCtas: true,
        micPhase: micPhase,
        micPermissionState: micPermissionState,
      );
    }

    if (ui == RecordUiState.done && !showPostSaveLoop) {
      if (isDegradedVoiceSave ||
          VoiceCapturePostSave.showTypedFallbackPrimary(lastSavedEntry)) {
        return RecordCtaPolicyResolution(
          state: RecordCtaPolicyState.postSaveDegraded,
          primaryLabel: VoiceCaptureCopy.typeWhatYouSaid,
          secondaryLabels: [
            VoiceCaptureCopy.recordAgainCta,
            ConsumerUiCopy.doneCta,
          ],
          showMainBottomCta: true,
          hideCardRecordCtas: true,
          micPhase: micPhase,
          micPermissionState: micPermissionState,
        );
      }
      return RecordCtaPolicyResolution(
        state: RecordCtaPolicyState.postSaveSuccess,
        primaryLabel: ConsumerUiCopy.doneCta,
        secondaryLabels: [ConsumerUiCopy.recordAnotherCta],
        showMainBottomCta: true,
        hideCardRecordCtas: true,
        micPhase: micPhase,
        micPermissionState: micPermissionState,
      );
    }

    if (ui == RecordUiState.error) {
      return RecordCtaPolicyResolution(
        state: RecordCtaPolicyState.error,
        primaryLabel: ConsumerUiCopy.recordAnotherCta,
        secondaryLabels: [EmptyArchiveCopy.typeInsteadCta],
        showMainBottomCta: true,
        hideCardRecordCtas: true,
        showTypeInsteadSecondary: true,
        micPhase: micPhase,
        micPermissionState: micPermissionState,
      );
    }

    if (ui == RecordUiState.ready && entryCountLoaded) {
      return _readyCapturePolicy(
        entryCount: entryCount,
        micPhase: micPhase,
        micPermissionState: micPermissionState,
        userDeniedThisSession: userDeniedThisSession,
        sessionRequiresOpenSettings: sessionRequiresOpenSettings,
      );
    }

    return RecordCtaPolicyResolution(
      state: RecordCtaPolicyState.idle,
      hideCardRecordCtas: false,
      micPhase: micPhase,
      micPermissionState: micPermissionState,
    );
  }

  static RecordCtaPolicyResolution _blockedPermissionPolicy({
    required RecordingPhase micPhase,
    required MicrophonePermissionState micPermissionState,
    required bool userDeniedThisSession,
    required bool sessionRequiresOpenSettings,
  }) {
    const secondaryLabels = [EmptyArchiveCopy.typeInsteadCta];
    final effectivePermission =
        sessionRequiresOpenSettings ||
            userDeniedThisSession ||
            micPermissionState == MicrophonePermissionState.deniedOpenSettings ||
            micPhase == RecordingPhase.permissionPermanentlyDenied
        ? MicrophonePermissionState.deniedOpenSettings
        : micPermissionState;

    return RecordCtaPolicyResolution(
      state: RecordCtaPolicyState.permissionBlocked,
      primaryLabel: MicrophonePermissionCopy.openSettingsCta,
      secondaryLabels: secondaryLabels,
      showMainBottomCta: true,
      hideCardRecordCtas: true,
      showTypeInsteadSecondary: true,
      action: RecordCtaAction.openSettings,
      micPhase: micPhase,
      micPermissionState: effectivePermission,
    );
  }

  static RecordCtaPolicyResolution _readyCapturePolicy({
    required int entryCount,
    required RecordingPhase micPhase,
    required MicrophonePermissionState micPermissionState,
    required bool userDeniedThisSession,
    required bool sessionRequiresOpenSettings,
  }) {
    final isFirstUse = entryCount == 0;
    final state = isFirstUse
        ? RecordCtaPolicyState.firstUse
        : RecordCtaPolicyState.returning;
    const secondaryLabels = [EmptyArchiveCopy.typeInsteadCta];

    if (micPhase == RecordingPhase.permissionPermanentlyDenied ||
        micPermissionState == MicrophonePermissionState.deniedOpenSettings ||
        sessionRequiresOpenSettings ||
        userDeniedThisSession) {
      return RecordCtaPolicyResolution(
        state: state,
        primaryLabel: MicrophonePermissionCopy.openSettingsCta,
        secondaryLabels: secondaryLabels,
        showMainBottomCta: true,
        hideCardRecordCtas: true,
        showTypeInsteadSecondary: true,
        action: RecordCtaAction.openSettings,
        micPhase: micPhase,
        micPermissionState: micPermissionState ==
                MicrophonePermissionState.deniedCanAskAgain
            ? MicrophonePermissionState.deniedOpenSettings
            : micPermissionState,
      );
    }

    if (micPhase == RecordingPhase.permissionDenied ||
        micPermissionState == MicrophonePermissionState.deniedCanAskAgain) {
      return RecordCtaPolicyResolution(
        state: state,
        primaryLabel: MicrophonePermissionCopy.allowMicrophoneCta,
        secondaryLabels: secondaryLabels,
        showMainBottomCta: true,
        hideCardRecordCtas: true,
        showTypeInsteadSecondary: true,
        action: RecordCtaAction.requestPermission,
        micPhase: micPhase,
        micPermissionState: micPermissionState,
      );
    }

    if (micPhase == RecordingPhase.ready ||
        micPermissionState == MicrophonePermissionState.granted ||
        micPermissionState ==
            MicrophonePermissionState.grantedWithPermissionHandlerMismatch) {
      return RecordCtaPolicyResolution(
        state: state,
        primaryLabel: isFirstUse
            ? VisibleArchiveProofCopy.firstUseCaptureCta
            : ConsumerUiCopy.recordMomentCta,
        secondaryLabels: secondaryLabels,
        showMainBottomCta: true,
        hideCardRecordCtas: true,
        showTypeInsteadSecondary: true,
        action: RecordCtaAction.startRecording,
        micPhase: RecordingPhase.ready,
        micPermissionState: micPermissionState,
      );
    }

    final action = RecordMicrophonePermissionUi.recordCtaAction(
      micPhase: micPhase,
      userDeniedThisSession: userDeniedThisSession,
    );
    return RecordCtaPolicyResolution(
      state: state,
      primaryLabel: isFirstUse
          ? VisibleArchiveProofCopy.firstUseCaptureCta
          : ConsumerUiCopy.recordMomentCta,
      secondaryLabels: secondaryLabels,
      showMainBottomCta: true,
      hideCardRecordCtas: true,
      showTypeInsteadSecondary: true,
      action: action,
      micPhase: micPhase,
      micPermissionState: micPermissionState,
    );
  }

  static bool shouldHideCardRecordCtas(RecordCtaPolicyResolution resolution) =>
      resolution.hideCardRecordCtas;

  static void log(RecordCtaPolicyResolution resolution) {
    final secondary = resolution.secondaryLabels.isEmpty
        ? 'none'
        : resolution.secondaryLabels.join(',');
    final action = resolution.action?.logLabel ?? 'none';
    debugPrint(
      '$logPrefix state=${resolution.state.logLabel} '
      'mic=${resolution.micPermissionState.name} '
      'primary=${resolution.primaryLabel ?? 'none'} '
      'action=$action '
      'secondary=$secondary',
    );
  }
}
