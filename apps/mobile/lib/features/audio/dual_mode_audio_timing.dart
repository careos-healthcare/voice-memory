/// Shared timing for the interactive pause gate and the sherpa VAD config.
abstract final class DualModeAudioTiming {
  static const sampleRateHz = 16000;
  static const pause = Duration(milliseconds: 1200);
  static const rollingWindow = Duration(seconds: 30);
}
