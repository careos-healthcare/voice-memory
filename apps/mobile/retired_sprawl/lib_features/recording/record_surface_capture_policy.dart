import 'package:archiveme_mobile/audio/recording_service.dart';
import 'package:archiveme_mobile/features/recording/record_surface_input.dart';
import 'package:archiveme_mobile/features/recording/recording_dependencies.dart' show BuildContext;
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_state.dart';
import 'package:archiveme_mobile/features/voice_capture/record_cta_policy.dart';
import 'package:archiveme_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:archiveme_mobile/product/consumer_copy_guard.dart';
import 'package:flutter/cupertino.dart' show BuildContext;
import 'package:flutter/material.dart' show BuildContext;
import 'package:flutter/widgets.dart' show BuildContext;

/// Mic / CTA policy helpers for record-surface resolution (no [BuildContext]).
abstract final class RecordSurfaceCapturePolicy {
  RecordSurfaceCapturePolicy._();

  static RecordCtaPolicyResolution resolve(
    RecordSurfaceInput input, {
    RecordingPhase? micPhase,
    bool? userDeniedThisSession,
  }) {
    final phase = micPhase ?? input.micPhase;
    final permission = input.micPermissionState;
    final effectiveMicPhase =
        permission == MicrophonePermissionState.granted ||
            permission ==
                MicrophonePermissionState.grantedWithPermissionHandlerMismatch
        ? RecordingPhase.ready
        : phase;
    final userDenied = userDeniedThisSession ?? input.micUserDeniedThisSession;
    return RecordCtaPolicy.resolve(
      ui: input.ui,
      entryCount: input.entryCount,
      entryCountLoaded: input.entryCountLoaded,
      showPostSaveLoop: input.showPostSaveLoop,
      isDegradedVoiceSave: input.lastSavedEntryIsDegraded,
      lastSavedEntry: input.lastSavedEntry,
      micPhase: effectiveMicPhase,
      micPermissionState: permission,
      userDeniedThisSession: userDenied,
      sessionRequiresOpenSettings: input.sessionRequiresOpenSettings,
    );
  }

  static bool shouldHideCompetingRecordCtas(RecordSurfaceInput input) =>
      RecordMicrophonePermissionUi.shouldHideCompetingRecordCtas(
        ui: input.ui,
        micPhase: input.micPhase,
        userDeniedThisSession: input.micUserDeniedThisSession,
      );

  static bool shouldHideCardRecordButtons(
    RecordSurfaceInput input,
    RecordCtaPolicyResolution policy,
  ) {
    if (shouldHideCompetingRecordCtas(input)) return true;
    return RecordCtaPolicy.shouldHideCardRecordCtas(policy);
  }

  static bool shouldPromoteMicCaptureActions(RecordCtaPolicyResolution policy) =>
      policy.showMainBottomCta &&
      policy.action != null &&
      policy.action != RecordCtaAction.startRecording;
}

/// Sanitizes sync note text for record-surface display.
String? recordSurfaceSyncNote(String? raw) =>
    ConsumerCopyGuard.userFacingSyncNote(raw);