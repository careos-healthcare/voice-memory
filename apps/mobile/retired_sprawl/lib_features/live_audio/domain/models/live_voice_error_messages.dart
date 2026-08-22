import 'package:archiveme_mobile/features/live_audio/domain/models/live_voice_error_state.dart';

abstract final class LiveVoiceErrorMessages {
  LiveVoiceErrorMessages._();

  static String forState(LiveVoiceErrorState state) {
    return switch (state) {
      LiveVoiceErrorState.none => '',
      LiveVoiceErrorState.networkTimeout =>
        'Connection lost. Check your network and tap Try again.',
      LiveVoiceErrorState.tokenExpired =>
        'This live session expired. Tap Try again to start a new one.',
      LiveVoiceErrorState.hardwareFailure =>
        'Microphone unavailable. Check permissions and try again.',
      LiveVoiceErrorState.unknown =>
        'Live voice stopped unexpectedly. Tap Try again.',
    };
  }
}