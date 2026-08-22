/// Target upload encoding for cloud transcription.
abstract final class CaptureAudioCompressorConfig {
  CaptureAudioCompressorConfig._();

  static const sampleRateHz = 16000;
  static const bitRateBps = 32000;
  static const channelCount = 1;
  static const containerExtension = 'm4a';
}