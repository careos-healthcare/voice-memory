import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/domain/models/live_session_state.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/live_voice_session_copy.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/live_voice_session_presentation.dart';

void main() {
  group('LiveVoiceSessionPresentation', () {
    test('maps connecting session state to connecting visual state', () {
      expect(
        LiveVoiceSessionPresentation.resolveVisualState(
          phase: LiveVoiceUiPhase.active,
          sessionState: LiveSessionState.connecting,
          modelSpeaking: false,
        ),
        LiveVoiceVisualState.connecting,
      );
    });

    test('prefers reconnecting over listening', () {
      expect(
        LiveVoiceSessionPresentation.resolveVisualState(
          phase: LiveVoiceUiPhase.active,
          sessionState: LiveSessionState.reconnecting,
          modelSpeaking: false,
        ),
        LiveVoiceVisualState.reconnecting,
      );
    });

    test('shows speaking when model audio is active', () {
      expect(
        LiveVoiceSessionPresentation.resolveVisualState(
          phase: LiveVoiceUiPhase.active,
          sessionState: LiveSessionState.streaming,
          modelSpeaking: true,
        ),
        LiveVoiceVisualState.speaking,
      );
    });

    test('formats timer as mm:ss', () {
      expect(LiveVoiceSessionPresentation.formatTimer(65), '01:05');
    });

    test('record entry CTA copy is Live conversation', () {
      expect(LiveVoiceSessionCopy.recordEntryCta, 'Live conversation');
    });
  });
}
