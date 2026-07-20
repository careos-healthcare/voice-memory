import 'live_voice_error_state.dart';

LiveVoiceErrorState classifyLiveVoiceFailure(
  String reason, {
  Object? error,
}) {
  final text = '$reason ${error ?? ''}'.toLowerCase();

  if (text.contains('token') ||
      text.contains('auth') ||
      text.contains('401') ||
      text.contains('403') ||
      text.contains('expired') ||
      text.contains('unauthorized') ||
      text.contains('forbidden')) {
    return LiveVoiceErrorState.tokenExpired;
  }

  if (text.contains('microphone') ||
      text.contains('pcm_capture') ||
      text.contains('permission') ||
      text.contains('hardware')) {
    return LiveVoiceErrorState.hardwareFailure;
  }

  if (text.contains('socket') ||
      text.contains('go_away') ||
      text.contains('timeout') ||
      text.contains('reconnect') ||
      text.contains('network') ||
      text.contains('connect failed') ||
      text.contains('timed out')) {
    return LiveVoiceErrorState.networkTimeout;
  }

  return LiveVoiceErrorState.unknown;
}
