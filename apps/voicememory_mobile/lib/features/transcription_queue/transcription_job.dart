/// Durable lifecycle states for a queued transcription.
enum TranscriptionJobStatus {
  queued('queued'),
  processing('processing'),
  retryWaiting('retry_waiting'),
  completed('completed'),
  failed('failed'),
  cancelled('cancelled');

  const TranscriptionJobStatus(this.storageValue);

  @Deprecated('Use processing.')
  static const TranscriptionJobStatus leased = processing;

  final String storageValue;

  bool get isTerminal =>
      this == completed || this == failed || this == cancelled;

  static TranscriptionJobStatus fromStorage(String value) {
    return values.firstWhere(
      (status) => status.storageValue == value,
      orElse: () =>
          throw FormatException('Unknown transcription job status: $value'),
    );
  }
}

/// Immutable representation of one durable transcription job.
class TranscriptionJob {
  const TranscriptionJob({
    required this.id,
    required this.entryId,
    required this.audioPath,
    required this.sourceFileName,
    required this.durationSeconds,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.attemptCount,
    this.nextAttemptAt,
    this.lastError,
    this.transcript,
    this.leaseToken,
    this.leaseExpiresAt,
    this.completedAt,
  });

  final String id;
  final String entryId;
  final String audioPath;
  final String sourceFileName;
  final int durationSeconds;
  final TranscriptionJobStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final String? transcript;
  final String? leaseToken;
  final DateTime? leaseExpiresAt;
  final DateTime? completedAt;

  bool get isTerminal => status.isTerminal;

  @override
  bool operator ==(Object other) {
    return other is TranscriptionJob &&
        other.id == id &&
        other.entryId == entryId &&
        other.audioPath == audioPath &&
        other.sourceFileName == sourceFileName &&
        other.durationSeconds == durationSeconds &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.attemptCount == attemptCount &&
        other.nextAttemptAt == nextAttemptAt &&
        other.lastError == lastError &&
        other.transcript == transcript &&
        other.leaseToken == leaseToken &&
        other.leaseExpiresAt == leaseExpiresAt &&
        other.completedAt == completedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    entryId,
    audioPath,
    sourceFileName,
    durationSeconds,
    status,
    createdAt,
    updatedAt,
    attemptCount,
    nextAttemptAt,
    lastError,
    transcript,
    leaseToken,
    leaseExpiresAt,
    completedAt,
  );
}

/// Result of repairing durable jobs when the ledger opens.
class TranscriptionReconciliationResult {
  const TranscriptionReconciliationResult({
    required this.expiredLeasesRecovered,
    required this.missingAudioFailed,
  });

  final int expiredLeasesRecovered;
  final int missingAudioFailed;
}

/// Result of SQLite's integrity check.
class TranscriptionDatabaseIntegrity {
  const TranscriptionDatabaseIntegrity(this.messages);

  final List<String> messages;

  bool get isHealthy => messages.length == 1 && messages.single == 'ok';
}
