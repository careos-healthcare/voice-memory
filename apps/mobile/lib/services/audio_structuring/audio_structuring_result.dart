/// Result of offline local-LLM journal structuring.
final class AudioStructuringResult {
  const AudioStructuringResult({
    required this.rawTranscript,
    required this.structuredEntry,
    required this.usedLocalLlm,
  });

  final String rawTranscript;
  final String structuredEntry;
  final bool usedLocalLlm;
}

/// Raised when structuring cannot run or the transcript is unusable.
final class AudioStructuringException implements Exception {
  AudioStructuringException(this.message);

  final String message;

  @override
  String toString() => 'AudioStructuringException: $message';
}
