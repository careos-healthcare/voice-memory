import 'package:voicememory_mobile/features/voice_capture/microphone_permission_state.dart';
import 'package:voicememory_mobile/audio/recording_service.dart';
import 'package:voicememory_mobile/features/voice_capture/record_microphone_permission_ui.dart';

/// Microphone permission and phase boundary for Record capture.
class MicrophonePermissionController {
  RecordingPhase phase = RecordingPhase.idle;
  MicrophonePermissionState permissionState = MicrophonePermissionState.unknown;
  bool userDeniedThisSession = false;
  bool sessionRequiresOpenSettings = false;

  RecordUiState get uiState => RecordMicrophonePermissionUi.uiForMicPhase(
        phase: phase,
        userDeniedThisSession: userDeniedThisSession,
      );

  void applyPhase(RecordingPhase next, {bool userDenied = false}) {
    phase = next;
    if (userDenied) userDeniedThisSession = true;
  }

  void markGranted(MicrophonePermissionState state) {
    phase = RecordingPhase.ready;
    permissionState = state;
    userDeniedThisSession = false;
    sessionRequiresOpenSettings = false;
  }

  void resetSession() {
    userDeniedThisSession = false;
    sessionRequiresOpenSettings = false;
  }
}
