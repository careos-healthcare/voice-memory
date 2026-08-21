/// Runtime configuration for loading an offline ONNX voice model.
final class OfflineTtsConfig {
  const OfflineTtsConfig({
    required this.vitsModelPath,
    required this.tokensPath,
    this.lexiconPath = '',
    this.dataDir = '',
    this.numThreads = 2,
    this.debug = false,
    this.provider = 'cpu',
    this.speakerId = 0,
    this.speed = 1.0,
    this.silenceScale = 0.2,
    this.noiseScale = 0.667,
    this.noiseScaleW = 0.8,
    this.lengthScale = 1.0,
  });

  /// ONNX model file (VITS / Piper-style voices).
  final String vitsModelPath;

  /// Token vocabulary for the voice model.
  final String tokensPath;

  /// Optional lexicon for phoneme-based voices.
  final String lexiconPath;

  /// Optional espeak-ng data directory required by some Piper/VITS builds.
  final String dataDir;

  final int numThreads;
  final bool debug;
  final String provider;

  /// Built-in speaker id when the model exposes multiple voices.
  final int speakerId;

  /// Playback speed multiplier passed to sherpa-onnx generation.
  final double speed;

  final double silenceScale;
  final double noiseScale;
  final double noiseScaleW;
  final double lengthScale;
}
