/// Bundled offline TTS ONNX contract (VITS / Piper-style voice).
///
/// Export a quantized VITS model to [modelAssetPath] with matching
/// [tokensAssetPath]. Piper voices also require [espeakDataAssetDir].
abstract final class OfflineTtsModelContract {
  OfflineTtsModelContract._();

  static const modelAssetPath = 'assets/models/offline_tts/model.onnx';
  static const tokensAssetPath = 'assets/models/offline_tts/tokens.txt';
  static const espeakDataAssetDir = 'assets/models/offline_tts/espeak-ng-data';

  /// On-disk folder under the app documents directory for sideloaded voices.
  static const sideloadDirectoryName = 'offline_tts';

  static const sideloadModelFileName = 'model.onnx';
  static const sideloadTokensFileName = 'tokens.txt';
  static const sideloadEspeakDirName = 'espeak-ng-data';

  /// Nominal sample rate for bundled Piper EN voices (used before load).
  static const defaultSampleRateHz = 22050;
}
