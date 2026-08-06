import '../../../audio/recording_service.dart';

/// Maps microphone permission phases to Record screen UI states.
/// What happens when the user taps a record CTA on the Record screen.
enum RecordCtaAction {
  startRecording,
  requestPermission,
  routeToBlockedPanel,
  openSettings,
}

abstract class RecordMicrophonePermissionUi {
  RecordMicrophonePermissionUi._();

  static const String logPrefix = 'ARCHIVEME_RECORD_PERMISSION_UI:';
  static const String recordCtaLogPrefix = 'ARCHIVEME_RECORD_CTA:';

  static RecordUiState uiForMicPhase({
    required RecordingPhase phase,
    required bool userDeniedThisSession,
  }) {
    if (phase == RecordingPhase.ready) return RecordUiState.ready;
    if (phase == RecordingPhase.permissionPermanentlyDenied) {
      return RecordUiState.permissionBlocked;
    }
    if (phase == RecordingPhase.permissionDenied) {
      return userDeniedThisSession
          ? RecordUiState.permissionBlocked
          : RecordUiState.ready;
    }
    return RecordUiState.idle;
  }

  static bool shouldShowBlockedPanel(RecordUiState ui) =>
      ui == RecordUiState.permissionBlocked;

  static bool shouldHideBlockedPanelDuringRequest(RecordUiState ui) =>
      ui == RecordUiState.requestingPermission;

  /// Blocked panel only after explicit user denial or permanent platform denial.
  static bool shouldRenderBlockedPanel({
    required RecordUiState ui,
    required RecordingPhase micPhase,
    required bool userDeniedThisSession,
  }) {
    if (shouldHideBlockedPanelDuringRequest(ui)) return false;
    if (micPhase == RecordingPhase.permissionPermanentlyDenied) {
      return ui == RecordUiState.permissionBlocked;
    }
    if (micPhase == RecordingPhase.permissionDenied) {
      return userDeniedThisSession && ui == RecordUiState.permissionBlocked;
    }
    return ui == RecordUiState.permissionBlocked;
  }

  static MicrophoneBlockedPanelKind blockedPanelKind({
    required RecordingPhase micPhase,
    required bool userDeniedThisSession,
    bool sessionRequiresOpenSettings = false,
  }) {
    if (sessionRequiresOpenSettings ||
        micPhase == RecordingPhase.permissionPermanentlyDenied) {
      return MicrophoneBlockedPanelKind.openSettings;
    }
    if (micPhase == RecordingPhase.permissionDenied && userDeniedThisSession) {
      return MicrophoneBlockedPanelKind.openSettings;
    }
    return MicrophoneBlockedPanelKind.none;
  }

  /// Ignore background mic refresh while permission is settling or capture is active.
  /// User-initiated requests ([fromUserRequest]) always apply so the post-dialog
  /// state is never stale.
  static bool shouldIgnoreStaleMicRefresh({
    required bool ignoreAfterGrant,
    required RecordUiState currentUi,
    bool fromUserRequest = false,
  }) {
    if (fromUserRequest) return false;
    if (ignoreAfterGrant) return true;
    return currentUi == RecordUiState.requestingPermission ||
        currentUi == RecordUiState.recording ||
        currentUi == RecordUiState.processing;
  }

  /// Applies a background refresh result unless the current session should ignore it.
  static RecordMicRefreshApplyResult applyMicRefresh({
    required RecordingPhase phase,
    required bool userDeniedThisSession,
    required RecordUiState currentUi,
    required bool ignoreAfterGrant,
    required bool fromUserRequest,
    bool sessionRequiresOpenSettings = false,
  }) {
    if (shouldIgnoreStaleMicRefresh(
      ignoreAfterGrant: ignoreAfterGrant,
      currentUi: currentUi,
      fromUserRequest: fromUserRequest,
    )) {
      return const RecordMicRefreshApplyResult.ignored();
    }

    final nextUserDenied = switch (phase) {
      RecordingPhase.ready => false,
      RecordingPhase.permissionPermanentlyDenied => true,
      RecordingPhase.permissionDenied =>
        fromUserRequest || userDeniedThisSession,
      _ => userDeniedThisSession,
    };

    final nextSessionRequiresOpenSettings =
        sessionRequiresOpenSettings ||
        phase == RecordingPhase.permissionPermanentlyDenied ||
        (fromUserRequest && phase != RecordingPhase.ready);

    final nextUi = uiForMicPhase(
      phase: phase,
      userDeniedThisSession: nextUserDenied,
    );

    return RecordMicRefreshApplyResult.applied(
      mic: phase,
      userDenied: nextUserDenied,
      ui: nextUi,
      sessionRequiresOpenSettings: nextSessionRequiresOpenSettings,
      initialDeniedCanAskAgain:
          !fromUserRequest &&
          phase == RecordingPhase.permissionDenied &&
          !nextUserDenied,
      permanentDenied:
          phase == RecordingPhase.permissionPermanentlyDenied ||
          nextSessionRequiresOpenSettings,
      userDeniedBlocked:
          fromUserRequest &&
          phase == RecordingPhase.permissionDenied &&
          nextUserDenied,
    );
  }

  static RecordMicGrantResult onPermissionGranted() {
    return const RecordMicGrantResult(
      mic: RecordingPhase.ready,
      userDenied: false,
      uiBeforeRecording: RecordUiState.ready,
      ignoreStaleRefreshAfterGrant: true,
    );
  }

  /// Central routing for every record CTA tap on the Record screen.
  static RecordCtaAction recordCtaAction({
    required RecordingPhase micPhase,
    required bool userDeniedThisSession,
  }) {
    if (micPhase == RecordingPhase.ready) {
      return RecordCtaAction.startRecording;
    }
    if (micPhase == RecordingPhase.permissionPermanentlyDenied) {
      return RecordCtaAction.openSettings;
    }
    if (micPhase == RecordingPhase.permissionDenied) {
      return userDeniedThisSession
          ? RecordCtaAction.openSettings
          : RecordCtaAction.requestPermission;
    }
    return RecordCtaAction.requestPermission;
  }

  /// Hide duplicate record CTAs above the blocked permission panel.
  static bool shouldHideCompetingRecordCtas({
    required RecordUiState ui,
    required RecordingPhase micPhase,
    required bool userDeniedThisSession,
  }) {
    return shouldRenderBlockedPanel(
      ui: ui,
      micPhase: micPhase,
      userDeniedThisSession: userDeniedThisSession,
    );
  }

  static String micBlockedStateLabel({
    required RecordingPhase micPhase,
    required bool userDeniedThisSession,
  }) {
    if (micPhase == RecordingPhase.permissionPermanentlyDenied) {
      return 'permanentlyDenied';
    }
    if (micPhase == RecordingPhase.permissionDenied && userDeniedThisSession) {
      return 'deniedThisSession';
    }
    if (micPhase == RecordingPhase.permissionDenied) {
      return 'deniedCanAskAgain';
    }
    return micPhase.name;
  }
}

enum MicrophoneBlockedPanelKind { none, allowMicrophone, openSettings }

class RecordMicRefreshApplyResult {
  const RecordMicRefreshApplyResult._({
    required this.ignored,
    this.mic,
    this.userDenied,
    this.ui,
    this.sessionRequiresOpenSettings = false,
    this.initialDeniedCanAskAgain = false,
    this.permanentDenied = false,
    this.userDeniedBlocked = false,
  });

  const RecordMicRefreshApplyResult.ignored() : this._(ignored: true);

  const RecordMicRefreshApplyResult.applied({
    required RecordingPhase mic,
    required bool userDenied,
    required RecordUiState ui,
    bool sessionRequiresOpenSettings = false,
    bool initialDeniedCanAskAgain = false,
    bool permanentDenied = false,
    bool userDeniedBlocked = false,
  }) : this._(
         ignored: false,
         mic: mic,
         userDenied: userDenied,
         ui: ui,
         sessionRequiresOpenSettings: sessionRequiresOpenSettings,
         initialDeniedCanAskAgain: initialDeniedCanAskAgain,
         permanentDenied: permanentDenied,
         userDeniedBlocked: userDeniedBlocked,
       );

  final bool ignored;
  final RecordingPhase? mic;
  final bool? userDenied;
  final RecordUiState? ui;
  final bool sessionRequiresOpenSettings;
  final bool initialDeniedCanAskAgain;
  final bool permanentDenied;
  final bool userDeniedBlocked;
}

class RecordMicGrantResult {
  const RecordMicGrantResult({
    required this.mic,
    required this.userDenied,
    required this.uiBeforeRecording,
    required this.ignoreStaleRefreshAfterGrant,
  });

  final RecordingPhase mic;
  final bool userDenied;
  final RecordUiState uiBeforeRecording;
  final bool ignoreStaleRefreshAfterGrant;
}

/// Record screen UI states for microphone permission handling.
enum RecordUiState {
  idle,
  requestingPermission,
  permissionBlocked,
  ready,
  recording,
  processing,
  done,
  error,
}
