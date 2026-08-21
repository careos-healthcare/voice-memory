/// Lifecycle phase for a remote GGUF download.
enum ModelDownloadPhase {
  idle,
  downloading,
  completed,
  failed,
  deleted,
}

/// Progress snapshot for UI binding on the main isolate.
final class ModelDownloadProgress {
  const ModelDownloadProgress({
    required this.phase,
    this.receivedBytes = 0,
    this.totalBytes,
    this.modelPath,
    this.errorMessage,
  });

  const ModelDownloadProgress.idle()
      : this(phase: ModelDownloadPhase.idle);

  const ModelDownloadProgress.deleted()
      : this(phase: ModelDownloadPhase.deleted);

  final ModelDownloadPhase phase;
  final int receivedBytes;
  final int? totalBytes;
  final String? modelPath;
  final String? errorMessage;

  /// Normalized 0–1 progress when [totalBytes] is known.
  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (receivedBytes / total).clamp(0.0, 1.0);
  }

  bool get isTerminal =>
      phase == ModelDownloadPhase.completed ||
      phase == ModelDownloadPhase.failed ||
      phase == ModelDownloadPhase.deleted;

  ModelDownloadProgress copyWith({
    ModelDownloadPhase? phase,
    int? receivedBytes,
    int? totalBytes,
    String? modelPath,
    String? errorMessage,
  }) {
    return ModelDownloadProgress(
      phase: phase ?? this.phase,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      modelPath: modelPath ?? this.modelPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
