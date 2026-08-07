import 'package:record/record.dart';

import 'audio_diag_log.dart';
import 'ios_native_audio_session.dart';

export 'ios_native_audio_session.dart' show IosCaptureAudioMode;

/// Configures iOS AVAudioSession before capture via native AppDelegate hook.
abstract class IosAudioSessionConfigurator {
  IosAudioSessionConfigurator._();

  static Future<void> configureForCapture(
    AudioRecorder recorder, {
    IosCaptureAudioMode mode = IosCaptureAudioMode.spokenAudio,
  }) async {
    await IosNativeAudioSession.configureForCapture(mode: mode);

    final ios = recorder.ios;
    if (ios == null) return;

    try {
      await ios.manageAudioSession(false);
      await ios.setAudioSessionActive(true);
    } catch (e) {
      AudioDiagLog.iosAudioSession(
        configured: false,
        category: 'playAndRecord',
        mode: mode.value,
        detail: 'recorder_session=$e',
      );
    }
  }
}
