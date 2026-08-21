/// Local capture metadata persisted before LLM analysis.
class CaptureAudioMetadata {
  const CaptureAudioMetadata({
    required this.id,
    required this.filePath,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String filePath;
  final DateTime createdAt;
  final String status;

  factory CaptureAudioMetadata.fromMap(Map<String, Object?> map) {
    return CaptureAudioMetadata(
      id: map['id']! as String,
      filePath: map['file_path']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
      status: map['status']! as String,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'file_path': filePath,
      'created_at': createdAt.millisecondsSinceEpoch,
      'status': status,
    };
  }
}

/// Target insert latency for optimistic queue writes.
const captureMetadataInsertBudgetMs = 100;
