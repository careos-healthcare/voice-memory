/// Lifecycle status for locally queued audio awaiting LLM processing.
enum AudioProcessingQueueStatus {
  pending('pending'),
  processing('processing'),
  completed('completed'),
  error('error');

  const AudioProcessingQueueStatus(this.storageValue);

  final String storageValue;

  static AudioProcessingQueueStatus parse(String raw) {
    return AudioProcessingQueueStatus.values.firstWhere(
      (value) => value.storageValue == raw,
      orElse: () => AudioProcessingQueueStatus.pending,
    );
  }
}

/// Row in [Migration016AudioProcessingQueue.tableName].
class AudioProcessingQueueItem {
  const AudioProcessingQueueItem({
    required this.id,
    required this.filePath,
    required this.timestamp,
    required this.durationMs,
    required this.status,
  });

  final String id;
  final String filePath;
  final DateTime timestamp;
  final int durationMs;
  final AudioProcessingQueueStatus status;

  factory AudioProcessingQueueItem.fromMap(Map<String, Object?> map) {
    return AudioProcessingQueueItem(
      id: map['id']! as String,
      filePath: map['file_path']! as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']! as int),
      durationMs: map['duration_ms']! as int,
      status: AudioProcessingQueueStatus.parse(map['status']! as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'file_path': filePath,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'duration_ms': durationMs,
      'status': status.storageValue,
    };
  }
}
