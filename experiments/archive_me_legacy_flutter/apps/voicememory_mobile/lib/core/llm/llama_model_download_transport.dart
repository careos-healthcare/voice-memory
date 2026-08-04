enum LlamaModelDownloadStatus {
  enqueued,
  running,
  paused,
  complete,
  failed,
  canceled,
  waitingToRetry,
}

final class LlamaModelDownloadTask {
  const LlamaModelDownloadTask({
    required this.taskId,
    required this.group,
    required this.url,
    required this.relativeDirectory,
    required this.filename,
    required this.metadata,
    this.status,
  });

  final String taskId;
  final String group;
  final Uri url;
  final String relativeDirectory;
  final String filename;
  final Map<String, String> metadata;
  final LlamaModelDownloadStatus? status;
}

sealed class LlamaModelDownloadEvent {
  const LlamaModelDownloadEvent(this.task);

  final LlamaModelDownloadTask task;
}

final class LlamaModelDownloadStatusEvent extends LlamaModelDownloadEvent {
  const LlamaModelDownloadStatusEvent(super.task, this.status);

  final LlamaModelDownloadStatus status;
}

final class LlamaModelDownloadProgressEvent extends LlamaModelDownloadEvent {
  const LlamaModelDownloadProgressEvent(
    super.task, {
    required this.progress,
    required this.expectedBytes,
  });

  final double progress;
  final int? expectedBytes;
}

abstract interface class LlamaModelDownloadTransport {
  Stream<LlamaModelDownloadEvent> get events;

  Future<void> initialize();

  Future<LlamaModelDownloadTask?> taskForId(String taskId);

  Future<bool> enqueue(LlamaModelDownloadTask task);

  Future<bool> pause(LlamaModelDownloadTask task);

  Future<bool> resume(LlamaModelDownloadTask task);

  Future<bool> cancel(String taskId);

  Future<void> dispose();
}
