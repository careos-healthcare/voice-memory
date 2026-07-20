import '../domain/models/live_session_state.dart';
import 'live_voice_session_copy.dart';

enum LiveVoiceUiPhase {
  starting,
  active,
  saving,
  error,
}

enum LiveVoiceVisualState {
  connecting,
  reconnecting,
  listening,
  speaking,
  saving,
  error,
}

abstract final class LiveVoiceSessionPresentation {
  LiveVoiceSessionPresentation._();

  static LiveVoiceVisualState resolveVisualState({
    required LiveVoiceUiPhase phase,
    required LiveSessionState sessionState,
    required bool modelSpeaking,
  }) {
    if (phase == LiveVoiceUiPhase.saving) {
      return LiveVoiceVisualState.saving;
    }
    if (phase == LiveVoiceUiPhase.error) {
      return LiveVoiceVisualState.error;
    }
    if (sessionState == LiveSessionState.reconnecting) {
      return LiveVoiceVisualState.reconnecting;
    }
    if (sessionState == LiveSessionState.connecting ||
        sessionState == LiveSessionState.awaitingSetupComplete) {
      return LiveVoiceVisualState.connecting;
    }
    if (modelSpeaking) {
      return LiveVoiceVisualState.speaking;
    }
    return LiveVoiceVisualState.listening;
  }

  static String statusLabel(LiveVoiceVisualState state) {
    return switch (state) {
      LiveVoiceVisualState.connecting => LiveVoiceSessionCopy.connecting,
      LiveVoiceVisualState.reconnecting => LiveVoiceSessionCopy.reconnecting,
      LiveVoiceVisualState.listening => LiveVoiceSessionCopy.listening,
      LiveVoiceVisualState.speaking => LiveVoiceSessionCopy.speaking,
      LiveVoiceVisualState.saving => LiveVoiceSessionCopy.savingTitle,
      LiveVoiceVisualState.error => LiveVoiceSessionCopy.tryAgain,
    };
  }

  static String helperText(LiveVoiceVisualState state) {
    return switch (state) {
      LiveVoiceVisualState.speaking => LiveVoiceSessionCopy.helperSpeaking,
      LiveVoiceVisualState.listening => LiveVoiceSessionCopy.helperListening,
      LiveVoiceVisualState.connecting ||
      LiveVoiceVisualState.reconnecting =>
        LiveVoiceSessionCopy.settingUp,
      LiveVoiceVisualState.saving => LiveVoiceSessionCopy.savingBody,
      LiveVoiceVisualState.error => LiveVoiceSessionCopy.discardBody,
    };
  }

  static String connectionPillLabel(LiveVoiceVisualState state) {
    return switch (state) {
      LiveVoiceVisualState.connecting => LiveVoiceSessionCopy.connectionConnecting,
      LiveVoiceVisualState.reconnecting =>
        LiveVoiceSessionCopy.connectionReconnecting,
      LiveVoiceVisualState.error => LiveVoiceSessionCopy.connectionConnecting,
      _ => LiveVoiceSessionCopy.connectionLive,
    };
  }

  static String formatTimer(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
