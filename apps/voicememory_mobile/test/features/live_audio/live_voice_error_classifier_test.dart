import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/domain/models/live_voice_error_classifier.dart';
import 'package:voicememory_mobile/features/live_audio/domain/models/live_voice_error_state.dart';

void main() {
  group('classifyLiveVoiceFailure', () {
    test('maps socket and timeout reasons to networkTimeout', () {
      expect(
        classifyLiveVoiceFailure('socket_closed'),
        LiveVoiceErrorState.networkTimeout,
      );
      expect(
        classifyLiveVoiceFailure('Timed out waiting for setupComplete.'),
        LiveVoiceErrorState.networkTimeout,
      );
    });

    test('maps auth and token reasons to tokenExpired', () {
      expect(
        classifyLiveVoiceFailure('server_error:401 unauthorized'),
        LiveVoiceErrorState.tokenExpired,
      );
      expect(
        classifyLiveVoiceFailure('session token expired'),
        LiveVoiceErrorState.tokenExpired,
      );
    });

    test('maps microphone failures to hardwareFailure', () {
      expect(
        classifyLiveVoiceFailure('pcm_capture_stream'),
        LiveVoiceErrorState.hardwareFailure,
      );
      expect(
        classifyLiveVoiceFailure('Microphone permission is required'),
        LiveVoiceErrorState.hardwareFailure,
      );
    });

    test('falls back to unknown', () {
      expect(
        classifyLiveVoiceFailure('unexpected_fault'),
        LiveVoiceErrorState.unknown,
      );
    });
  });
}
