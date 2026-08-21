/// Prompt payload for a local GGUF completion request.
final class LocalLlmCompletionRequest {
  const LocalLlmCompletionRequest({
    required this.prompt,
    this.maxTokens,
    this.temperature,
    this.systemPrompt,
  });

  final String prompt;
  final int? maxTokens;
  final double? temperature;
  final String? systemPrompt;

  String get effectivePrompt {
    final system = systemPrompt?.trim();
    if (system == null || system.isEmpty) {
      return prompt;
    }
    return '$system\n\n$prompt';
  }
}

/// Incremental token event emitted while a completion is streaming.
final class LocalLlmTokenEvent {
  const LocalLlmTokenEvent({
    required this.token,
    required this.promptId,
    this.isFinal = false,
  });

  final String token;
  final String promptId;
  final bool isFinal;
}

/// Result of a completed local inference call.
final class LocalLlmCompletionResult {
  const LocalLlmCompletionResult({
    required this.text,
    required this.promptId,
    required this.tokensUsed,
  });

  final String text;
  final String promptId;
  final int tokensUsed;
}
