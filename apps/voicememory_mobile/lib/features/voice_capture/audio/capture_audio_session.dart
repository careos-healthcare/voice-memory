import 'package:record/record.dart';

import 'audio_diag_log.dart';
import 'ios_native_audio_session.dart';

enum CaptureAudioSessionMode {
  spokenAudio('spokenAudio'),
  measurement('measurement');

  const CaptureAudioSessionMode(this.value);
  final String value;
}

/// Configures capture-session controls when the current platform exposes them.
///
/// Android capture through `record` owns its audio controls, so this is a
/// no-op there. iOS keeps the explicit AVAudioSession setup needed to avoid
/// silent physical-device captures.
abstract class CaptureAudioSessionConfigurator {
  CaptureAudioSessionConfigurator._();

  static Future<void> configureForCapture(
    AudioRecorder recorder, {
    CaptureAudioSessionMode mode = CaptureAudioSessionMode.spokenAudio,
  }) async {
    await IosNativeAudioSession.configureForCapture(
      mode: mode == CaptureAudioSessionMode.measurement
          ? IosCaptureAudioMode.measurement
          : IosCaptureAudioMode.spokenAudio,
    );

    final ios = recorder.ios;
    if (ios == null) return;

    try {
      await ios.manageAudioSession(false);
      await ios.setAudioSessionActive(true);
    } catch (error) {
      AudioDiagLog.iosAudioSession(
        configured: false,
        category: 'playAndRecord',
        mode: mode.value,
        detail: 'recorder_session=$error',
      );
    }
  }
}
