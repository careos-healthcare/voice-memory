import 'dart:io';

import 'package:archiveme_mobile/models/audio_processing_queue_item.dart';
import 'package:archiveme_mobile/storage/audio/local_audio_storage_service.dart';
import 'package:archiveme_mobile/storage/sqlite/audio_processing_queue_repository.dart';
import 'package:uuid/uuid.dart';

/// Hybrid queue: durable audio files on disk + SQLite processing metadata.
class AudioProcessingQueueService {
  AudioProcessingQueueService({
    required LocalAudioStorageService storage,
    required AudioProcessingQueueRepository repository,
    Uuid? uuid,
    String Function()? createId,
  }) : _storage = storage,
       _repository = repository,
       _uuid = uuid ?? const Uuid(),
       _createId = createId;

  final LocalAudioStorageService _storage;
  final AudioProcessingQueueRepository _repository;
  final Uuid _uuid;
  final String Function()? _createId;

  Future<AudioProcessingQueueItem> enqueueRecording({
    required File sourceFile,
    required int durationMs,
    DateTime? timestamp,
  }) async {
    final id = _createId?.call() ?? _uuid.v4();
    final storedPath = await _storage.saveRecordingFile(
      sourceFile: sourceFile,
      recordingId: id,
    );
    final createdAt = timestamp ?? DateTime.now();
    await _repository.insertPending(
      id: id,
      filePath: storedPath,
      timestamp: createdAt,
      durationMs: durationMs,
    );
    return AudioProcessingQueueItem(
      id: id,
      filePath: storedPath,
      timestamp: createdAt,
      durationMs: durationMs,
      status: AudioProcessingQueueStatus.pending,
    );
  }

  Future<void> markProcessing(String id) {
    return _repository.updateStatus(
      id: id,
      status: AudioProcessingQueueStatus.processing,
    );
  }

  Future<void> markError(String id) {
    return _repository.updateStatus(
      id: id,
      status: AudioProcessingQueueStatus.error,
    );
  }

  /// Deletes the on-disk audio file and marks the queue row completed.
  Future<void> completeProcessing(String id) async {
    final item = await _repository.findById(id);
    if (item == null) return;

    await _storage.deleteRecordingFile(item.filePath);
    await _repository.updateStatus(
      id: id,
      status: AudioProcessingQueueStatus.completed,
    );
  }
}
