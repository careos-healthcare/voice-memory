import 'package:record/record.dart';

/// Echo-cancelled capture while Reflect with me is speaking a question.
abstract final class ReflectCaptureAudio {
  static var enabled = false;

  static RecordConfig apply(RecordConfig config) {
    if (!enabled) return config;
    return config.copyWith(
      echoCancel: true,
      androidConfig: const AndroidRecordConfig(
        audioSource: AndroidAudioSource.voiceCommunication,
        audioManagerMode: AudioManagerMode.modeInCommunication,
      ),
    );
  }
}
