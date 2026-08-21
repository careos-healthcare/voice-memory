import 'package:flutter/foundation.dart';

/// Explicit phases for the background journal sync pipeline.
enum BackgroundSyncPhase {
  idle,
  waitingForNetwork,
  waitingForRetry,
  attestation,
  transcription,
  proofAdmission,
  reflectionEmbedding,
  outboxDrain,
  cloudSync,
  sqliteVaultUpload,
  completed,
  failed,
}

@immutable
class BackgroundSyncState {
  const BackgroundSyncState({
    this.phase = BackgroundSyncPhase.idle,
    this.isOnline = true,
    this.queuedEntryCount = 0,
    this.pendingOutboxCount = 0,
    this.nextRetryAt,
    this.lastError,
    this.lastCompletedAt,
    this.transcriptsReconciled = 0,
    this.proofsAdmitted = 0,
    this.cloudSyncSucceeded = false,
    this.vaultUploadSucceeded = false,
  });

  final BackgroundSyncPhase phase;
  final bool isOnline;
  final int queuedEntryCount;
  final int pendingOutboxCount;
  final DateTime? nextRetryAt;
  final String? lastError;
  final DateTime? lastCompletedAt;
  final int transcriptsReconciled;
  final int proofsAdmitted;
  final bool cloudSyncSucceeded;
  final bool vaultUploadSucceeded;

  bool get isActive =>
      phase != BackgroundSyncPhase.idle &&
      phase != BackgroundSyncPhase.completed &&
      phase != BackgroundSyncPhase.failed &&
      phase != BackgroundSyncPhase.waitingForNetwork &&
      phase != BackgroundSyncPhase.waitingForRetry;

  BackgroundSyncState copyWith({
    BackgroundSyncPhase? phase,
    bool? isOnline,
    int? queuedEntryCount,
    int? pendingOutboxCount,
    DateTime? nextRetryAt,
    bool clearNextRetryAt = false,
    String? lastError,
    bool clearLastError = false,
    DateTime? lastCompletedAt,
    int? transcriptsReconciled,
    int? proofsAdmitted,
    bool? cloudSyncSucceeded,
    bool? vaultUploadSucceeded,
  }) {
    return BackgroundSyncState(
      phase: phase ?? this.phase,
      isOnline: isOnline ?? this.isOnline,
      queuedEntryCount: queuedEntryCount ?? this.queuedEntryCount,
      pendingOutboxCount: pendingOutboxCount ?? this.pendingOutboxCount,
      nextRetryAt: clearNextRetryAt ? null : (nextRetryAt ?? this.nextRetryAt),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      transcriptsReconciled:
          transcriptsReconciled ?? this.transcriptsReconciled,
      proofsAdmitted: proofsAdmitted ?? this.proofsAdmitted,
      cloudSyncSucceeded: cloudSyncSucceeded ?? this.cloudSyncSucceeded,
      vaultUploadSucceeded: vaultUploadSucceeded ?? this.vaultUploadSucceeded,
    );
  }
}
