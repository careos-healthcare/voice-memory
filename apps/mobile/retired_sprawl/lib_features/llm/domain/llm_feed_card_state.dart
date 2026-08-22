/// Incremental token emitted from the background LLM isolate worker.
class LlmStreamToken {
  const LlmStreamToken({
    required this.captureId,
    required this.token,
    this.isFinal = false,
    this.accumulatedText = '',
  });

  final String captureId;
  final String token;
  final bool isFinal;
  final String accumulatedText;
}

/// Lifecycle for on-device capture analysis surfaced in timeline cards.
enum LlmAnalysisStatus {
  pendingAnalysis,
  processing,
  streaming,
  completed,
  error,
}

/// UI-facing state for an optimistic timeline feed card.
class LlmFeedCardState {
  const LlmFeedCardState({
    required this.captureId,
    required this.createdAt,
    required this.status,
    this.rawTranscript = '',
    this.streamingText = '',
    this.summary = '',
    this.nodes = const [],
    this.errorMessage,
  });

  final String captureId;
  final DateTime createdAt;
  final LlmAnalysisStatus status;
  final String rawTranscript;
  final String streamingText;
  final String summary;
  final List<LlmFeedGraphNode> nodes;
  final String? errorMessage;

  bool get isPendingAnalysis => status == LlmAnalysisStatus.pendingAnalysis;
  bool get isStreaming => status == LlmAnalysisStatus.streaming;
  bool get isCompleted => status == LlmAnalysisStatus.completed;

  LlmFeedCardState copyWith({
    LlmAnalysisStatus? status,
    String? rawTranscript,
    String? streamingText,
    String? summary,
    List<LlmFeedGraphNode>? nodes,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LlmFeedCardState(
      captureId: captureId,
      createdAt: createdAt,
      status: status ?? this.status,
      rawTranscript: rawTranscript ?? this.rawTranscript,
      streamingText: streamingText ?? this.streamingText,
      summary: summary ?? this.summary,
      nodes: nodes ?? this.nodes,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Lightweight extracted node chip for feed cards.
class LlmFeedGraphNode {
  const LlmFeedGraphNode({
    required this.id,
    required this.kind,
    required this.label,
  });

  final String id;
  final String kind;
  final String label;
}
