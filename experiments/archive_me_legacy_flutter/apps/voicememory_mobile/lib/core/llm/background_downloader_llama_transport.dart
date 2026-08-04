import 'dart:async';
import 'dart:convert';

import 'package:background_downloader/background_downloader.dart';

import 'llama_model_download_transport.dart';

final class BackgroundDownloaderLlamaTransport
    implements LlamaModelDownloadTransport {
  BackgroundDownloaderLlamaTransport({
    FileDownloader? downloader,
    this.group = modelGroup,
  }) : _downloader = downloader ?? FileDownloader();

  static const modelGroup = 'archive_me_llama_models';
  static const maxRetries = 3;

  final FileDownloader _downloader;
  final String group;
  final StreamController<LlamaModelDownloadEvent> _events =
      StreamController<LlamaModelDownloadEvent>.broadcast();
  Timer? _rescheduleTimer;
  bool _initialized = false;
  bool _disposed = false;

  @override
  Stream<LlamaModelDownloadEvent> get events => _events.stream;

  @override
  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    _downloader.registerCallbacks(
      group: group,
      taskStatusCallback: _onStatus,
      taskProgressCallback: _onProgress,
    );
    await _downloader.trackTasksInGroup(group);
    await _downloader.resumeFromBackground();
    _rescheduleTimer = Timer(const Duration(seconds: 5), () {
      if (!_disposed) {
        unawaited(_rescheduleKilledTasks());
      }
    });
  }

  Future<void> _rescheduleKilledTasks() async {
    try {
      await _downloader.rescheduleKilledTasks();
    } on Object {
      // A later task/status callback reconciles any native scheduling failure.
    }
  }

  @override
  Future<LlamaModelDownloadTask?> taskForId(String taskId) async {
    final record = await _downloader.database.recordForId(taskId);
    final recordedTask = record?.task;
    if (recordedTask is DownloadTask && _isOwned(recordedTask)) {
      try {
        return _fromPlugin(
          recordedTask,
          status: _fromPluginStatus(record!.status),
        );
      } on FormatException {
        return null;
      }
    }
    final task = await _downloader.taskForId(taskId);
    if (task is! DownloadTask || !_isOwned(task)) return null;
    try {
      return _fromPlugin(task);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<bool> enqueue(LlamaModelDownloadTask task) async {
    _checkOwned(task);
    await initialize();
    return _downloader.enqueue(_toPlugin(task));
  }

  @override
  Future<bool> pause(LlamaModelDownloadTask task) async {
    _checkOwned(task);
    return _downloader.pause(_toPlugin(task));
  }

  @override
  Future<bool> resume(LlamaModelDownloadTask task) async {
    _checkOwned(task);
    return _downloader.resume(_toPlugin(task));
  }

  @override
  Future<bool> cancel(String taskId) => _downloader.cancelTaskWithId(taskId);

  DownloadTask _toPlugin(LlamaModelDownloadTask task) => DownloadTask(
    taskId: task.taskId,
    url: task.url.toString(),
    filename: task.filename,
    directory: task.relativeDirectory,
    baseDirectory: BaseDirectory.applicationSupport,
    group: group,
    updates: Updates.statusAndProgress,
    requiresWiFi: true,
    allowPause: true,
    retries: maxRetries,
    metaData: jsonEncode(task.metadata),
    displayName: 'ArchiveMe on-device model',
  );

  LlamaModelDownloadTask _fromPlugin(
    DownloadTask task, {
    LlamaModelDownloadStatus? status,
  }) {
    final raw = jsonDecode(task.metaData);
    if (raw is! Map) throw const FormatException('Invalid model metadata.');
    return LlamaModelDownloadTask(
      taskId: task.taskId,
      group: task.group,
      url: Uri.parse(task.url),
      relativeDirectory: task.directory,
      filename: task.filename,
      metadata: raw.map((key, value) => MapEntry('$key', '$value')),
      status: status,
    );
  }

  LlamaModelDownloadStatus _fromPluginStatus(TaskStatus status) =>
      switch (status) {
        TaskStatus.enqueued => LlamaModelDownloadStatus.enqueued,
        TaskStatus.running => LlamaModelDownloadStatus.running,
        TaskStatus.paused => LlamaModelDownloadStatus.paused,
        TaskStatus.complete => LlamaModelDownloadStatus.complete,
        TaskStatus.canceled => LlamaModelDownloadStatus.canceled,
        TaskStatus.waitingToRetry => LlamaModelDownloadStatus.waitingToRetry,
        TaskStatus.failed ||
        TaskStatus.notFound => LlamaModelDownloadStatus.failed,
      };

  bool _isOwned(Task task) =>
      task.group == group &&
      task.taskId.startsWith('llama_model_') &&
      task.metaData.isNotEmpty;

  void _checkOwned(LlamaModelDownloadTask task) {
    if (task.group != group || !task.taskId.startsWith('llama_model_')) {
      throw ArgumentError('Refusing non-model download task.');
    }
  }

  void _onStatus(TaskStatusUpdate update) {
    if (_disposed || update.task is! DownloadTask || !_isOwned(update.task)) {
      return;
    }
    try {
      final task = _fromPlugin(update.task as DownloadTask);
      final status = _fromPluginStatus(update.status);
      _events.add(LlamaModelDownloadStatusEvent(task, status));
    } on Object {
      // Malformed callback metadata is ignored and never exposed to the UI.
    }
  }

  void _onProgress(TaskProgressUpdate update) {
    if (_disposed || update.task is! DownloadTask || !_isOwned(update.task)) {
      return;
    }
    try {
      _events.add(
        LlamaModelDownloadProgressEvent(
          _fromPlugin(update.task as DownloadTask),
          progress: update.progress.clamp(0, 1),
          expectedBytes: update.hasExpectedFileSize
              ? update.expectedFileSize
              : null,
        ),
      );
    } on Object {
      // Malformed callback metadata is ignored and never exposed to the UI.
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _rescheduleTimer?.cancel();
    _downloader.unregisterCallbacks(group: group);
    await _events.close();
  }
}
