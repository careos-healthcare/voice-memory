/// Default on-device Gemma + speech model sources for [AIService].
abstract final class GemmaAiConfig {
  GemmaAiConfig._();

  /// Lightweight moonshine STT (~5 s clips, 16 kHz mono PCM).
  static const moonshineModelUrl =
      'https://huggingface.co/litert-community/moonshine-tiny/resolve/main/moonshine_tiny_5s_f32.tflite';

  static const moonshineTokenizerUrl =
      'https://huggingface.co/UsefulSensors/moonshine/resolve/main/ctranslate2/tiny/tokenizer.json';

  /// Quantized Gemma 3 1B instruction model for structured entity extraction.
  static const entityExtractionModelUrl =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm';

  static const entityExtractionModelFileName =
      'Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm';

  /// Minimum LiteRT-LM context window enforced by the native engine.
  static const litertlmMinContextTokens = 1024;

  /// Default generation cap for JSON entity extraction (keeps NPU/GPU bursts short).
  static const defaultEntityExtractionMaxTokens = 256;

  /// STT input: 16 kHz, mono, 16-bit little-endian PCM.
  static const sttSampleRateHz = 16000;
}
