import 'dart:io';

import 'package:archiveme_mobile/features/voice_capture/audio/ios_native_audio_session.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// Voice-chat audio route for "Reflect with me".
///
/// Echo cancellation has to be on so the microphone does not transcribe the
/// question the app is speaking.
class AudioSessionManager {
  AudioSessionManager({
    Future<void> Function()? configureIos,
    Future<void> Function()? configureAndroid,
    bool? ios,
    bool? android,
  }) : _configureIos = configureIos ?? _nativeIosVoiceChat,
       _configureAndroid = configureAndroid ?? _androidInCommunication,
       _ios = ios ?? (!kIsWeb && Platform.isIOS),
       _android = android ?? (!kIsWeb && Platform.isAndroid);

  /// `AVAudioSessionCategoryPlayAndRecord`.
  static const iosCategory = 'playAndRecord';

  /// `AVAudioSessionModeVoiceChat`.
  static const iosMode = 'voiceChat';

  /// `AudioManager.MODE_IN_COMMUNICATION`.
  static const androidMode = 'MODE_IN_COMMUNICATION';

  final Future<void> Function() _configureIos;
  final Future<void> Function() _configureAndroid;
  final bool _ios;
  final bool _android;

  Future<void> enterReflectMode() async {
    if (_ios) await _configureIos();
    if (_android) await _configureAndroid();
  }
}

Future<void> _nativeIosVoiceChat() {
  return IosNativeAudioSession.configureForCapture(
    mode: IosCaptureAudioMode.voiceChat,
  );
}

Future<void> _androidInCommunication() {
  return AndroidAudioManager().setMode(AndroidAudioHardwareMode.inCommunication);
}
