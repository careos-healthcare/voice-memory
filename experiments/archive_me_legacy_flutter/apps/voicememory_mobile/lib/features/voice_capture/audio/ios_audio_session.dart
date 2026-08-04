import 'package:record/record.dart';

import 'capture_audio_session.dart';
import 'ios_native_audio_session.dart';

export 'ios_native_audio_session.dart' show IosCaptureAudioMode;

/// Deprecated source-compatibility shim.
@Deprecated('Use CaptureAudioSessionConfigurator instead.')
abstract class IosAudioSessionConfigurator {
  IosAudioSessionConfigurator._();

  static Future<void> configureForCapture(
    AudioRecorder recorder, {
    IosCaptureAudioMode mode = IosCaptureAudioMode.spokenAudio,
  }) async {
    await CaptureAudioSessionConfigurator.configureForCapture(
      recorder,
      mode: mode == IosCaptureAudioMode.measurement
          ? CaptureAudioSessionMode.measurement
          : CaptureAudioSessionMode.spokenAudio,
    );
  }
}
