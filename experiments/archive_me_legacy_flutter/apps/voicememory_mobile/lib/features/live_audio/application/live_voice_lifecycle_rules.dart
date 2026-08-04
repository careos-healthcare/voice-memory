import 'package:flutter/widgets.dart';

/// Pure lifecycle decision rules for live voice capture pause/resume.
abstract final class LiveVoiceLifecycleRules {
  LiveVoiceLifecycleRules._();

  static bool shouldPauseCapture(AppLifecycleState state) {
    return state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;
  }

  static bool isForegroundForCapture(AppLifecycleState state) {
    return state == AppLifecycleState.resumed;
  }

  static bool shouldAttemptCaptureResume({
    required AppLifecycleState state,
    required bool sessionActive,
    required bool hasError,
    required bool isSaving,
  }) {
    return LiveVoiceLifecycleRules.isForegroundForCapture(state) &&
        sessionActive &&
        !hasError &&
        !isSaving;
  }

  static bool shouldPauseActiveSession({
    required AppLifecycleState state,
    required bool sessionActive,
    required bool hasError,
    required bool isSaving,
    required bool isConnectingOrActive,
  }) {
    return shouldPauseCapture(state) &&
        sessionActive &&
        !hasError &&
        !isSaving &&
        isConnectingOrActive;
  }
}
