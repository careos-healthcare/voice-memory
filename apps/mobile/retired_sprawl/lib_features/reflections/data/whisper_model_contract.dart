/// Bundled Whisper-tiny.en INT8 ONNX contract for on-device STT.
///
/// Export `whisper-tiny.en` (quantized INT8) to
/// [defaultAssetPath] with:
/// - Input `input_features` or `mel`: float32 `[1, nMelBins, maxFrames]`
/// - Output `logits`, `token_ids`, or `text` depending on export tooling.
abstract final class WhisperModelContract {
  WhisperModelContract._();

  static const defaultAssetPath = 'assets/models/whisper_tiny_en_int8.onnx';

  static const inputFeaturesName = 'input_features';
  static const melInputName = 'mel';
  static const logitsOutputName = 'logits';
  static const tokenIdsOutputName = 'token_ids';
  static const textOutputName = 'text';

  static const sampleRateHz = 16000;
  static const nMelBins = 80;
  static const hopLength = 160;
  static const fftSize = 400;
  static const maxAudioSeconds = 30;
  static const maxFrames = (sampleRateHz * maxAudioSeconds) ~/ hopLength;

  static const int startOfTranscriptToken = 50258;
  static const int endOfTextToken = 50257;
  static const int englishToken = 50259;
}
