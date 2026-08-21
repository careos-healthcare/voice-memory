import 'package:path/path.dart' as p;

/// Expected on-disk layout and quantization for bundled / sideloaded GGUF models.
abstract final class LocalLlmModelContract {
  LocalLlmModelContract._();

  /// Recommended mobile quantization — ~4-bit K-quant, medium quality/size tradeoff.
  static const preferredQuantization = 'Q4_K_M';

  /// `<app-documents>/local_llm/` download / sideload directory name.
  static const sideloadDirectoryName = 'local_llm';

  /// Default sideload filename when users drop a single GGUF file.
  static const sideloadModelFileName = 'model-q4_k_m.gguf';

  /// Conservative context window for phones with ≤4 GB RAM.
  static const defaultContextSize = 2048;

  /// Upper bound for prompt + completion tokens in the llama context.
  static const defaultMaxContextSize = 4096;

  /// Default generation cap — keeps decode memory predictable on older devices.
  static const defaultMaxTokens = 256;

  /// Shared load-time cap for every on-device LLM consumer (structuring, RAG, etc.).
  static const sharedProductionMaxTokens = 384;

  /// CPU thread budget for llama.cpp (total cores are often 4–6 on legacy phones).
  static const defaultThreadCount = 4;

  /// Micro-batch size — must stay ≤ [defaultContextSize] to limit scratch RAM.
  static const defaultBatchSize = 256;

  /// Micro-batch chunk size passed to llama.cpp as `n_ubatch`.
  static const defaultMicroBatchSize = 128;

  static bool isGgufPath(String path) =>
      p.basename(path).toLowerCase().endsWith('.gguf');

  /// Returns true when the filename indicates a heavily quantized K/Q variant.
  static bool isHeavilyQuantizedGguf(String path) {
    if (!isGgufPath(path)) {
      return false;
    }
    final name = p.basename(path).toLowerCase();
    return name.contains('q4_k_m') ||
        name.contains('q4_k_s') ||
        name.contains('q4_k') ||
        name.contains('q3_k') ||
        name.contains('q4_0') ||
        name.contains('q5_k_m');
  }

  static bool matchesPreferredQuantization(String path) {
    return p.basename(path).toLowerCase().contains('q4_k_m');
  }

  static void assertLoadableGguf(String path, {bool requirePreferred = true}) {
    if (!isGgufPath(path)) {
      throw LocalLlmModelException(
        'Local LLM model must be a .gguf file: $path',
      );
    }
    if (!isHeavilyQuantizedGguf(path)) {
      throw LocalLlmModelException(
        'Local LLM requires a heavily quantized GGUF (e.g. $preferredQuantization). '
        'Got: ${p.basename(path)}',
      );
    }
    if (requirePreferred && !matchesPreferredQuantization(path)) {
      throw LocalLlmModelException(
        'Local LLM expects $preferredQuantization weights in the filename. '
        'Got: ${p.basename(path)}',
      );
    }
  }
}

/// Raised when a GGUF path does not meet the mobile quantization contract.
final class LocalLlmModelException implements Exception {
  LocalLlmModelException(this.message);

  final String message;

  @override
  String toString() => 'LocalLlmModelException: $message';
}
