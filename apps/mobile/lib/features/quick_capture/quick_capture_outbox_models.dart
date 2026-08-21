/// Kind of widget / shortcut capture queued for background processing.
enum QuickCaptureKind {
  text('text'),
  voice('voice');

  const QuickCaptureKind(this.storageValue);
  final String storageValue;

  static QuickCaptureKind parse(String? raw) {
    return QuickCaptureKind.values.firstWhere(
      (value) => value.storageValue == raw,
      orElse: () => QuickCaptureKind.text,
    );
  }
}

enum QuickCaptureOutboxStatus {
  pending('pending'),
  processing('processing'),
  done('done'),
  failed('failed');

  const QuickCaptureOutboxStatus(this.storageValue);
  final String storageValue;

  static QuickCaptureOutboxStatus parse(String? raw) {
    return QuickCaptureOutboxStatus.values.firstWhere(
      (value) => value.storageValue == raw,
      orElse: () => QuickCaptureOutboxStatus.pending,
    );
  }
}

/// Payload written by widgets / quick actions into shared storage or drift.
class QuickCaptureOutboxPayload {
  QuickCaptureOutboxPayload({
    required this.captureId,
    required this.kind,
    this.text,
    this.audioPath,
    this.durationSeconds = 0,
    this.source = 'widget',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  factory QuickCaptureOutboxPayload.fromJson(Map<String, dynamic> json) {
    return QuickCaptureOutboxPayload(
      captureId: (json['captureId'] ?? json['id'] ?? '').toString(),
      kind: QuickCaptureKind.parse(json['kind'] as String?),
      text: json['text'] as String?,
      audioPath: (json['audioPath'] ?? json['audioRelativePath']) as String?,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      source: (json['source'] as String?) ?? 'widget',
      createdAt: _parseDate(json['createdAt']),
    );
  }

  final String captureId;
  final QuickCaptureKind kind;
  final String? text;
  final String? audioPath;
  final int durationSeconds;
  final String source;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'captureId': captureId,
    'kind': kind.storageValue,
    if (text != null) 'text': text,
    if (audioPath != null) 'audioPath': audioPath,
    'durationSeconds': durationSeconds,
    'source': source,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  bool get isValid {
    return switch (kind) {
      QuickCaptureKind.text => (text?.trim().isNotEmpty ?? false),
      QuickCaptureKind.voice =>
        (audioPath?.trim().isNotEmpty ?? false) && durationSeconds > 0,
    };
  }

  static DateTime _parseDate(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw)?.toUtc() ??
          DateTime.now().toUtc();
    }
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
    }
    return DateTime.now().toUtc();
  }
}

class QuickCaptureOutboxEntry {
  const QuickCaptureOutboxEntry({
    required this.outboxId,
    required this.payload,
    required this.status,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    this.lastError,
  });

  final String outboxId;
  final QuickCaptureOutboxPayload payload;
  final QuickCaptureOutboxStatus status;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastError;
}
