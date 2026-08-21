import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:archiveme_mobile/security/release_log_sanitizer.dart';

/// Release-safe logging for the offline-first background sync queue.
abstract class SyncPipelineLog {
  SyncPipelineLog._();

  static void enqueued({required String entryId, required String reason}) {
    ReleaseLogger.emit(
      event: 'sync_queue_enqueued',
      category: ReleaseLogCategory.sync,
      fields: {
        'reason': ReleaseLogSanitizer.sanitizeReasonCode(reason),
      },
    );
    ReleaseLogger.debugDetail(
      event: 'sync_queue_enqueued_detail',
      category: ReleaseLogCategory.sync,
      fields: {'entry_id': entryId},
    );
  }

  static void flushStarted({required int pendingCount}) {
    ReleaseLogger.emit(
      event: 'sync_queue_flush_started',
      category: ReleaseLogCategory.sync,
      fields: {'pending_count': pendingCount},
    );
  }

  static void flushCompleted({
    required int transcriptsReconciled,
    required int proofsAdmitted,
    required bool cloudSyncAttempted,
    required bool cloudSyncSucceeded,
    required bool vaultUploadAttempted,
    required bool vaultUploadSucceeded,
  }) {
    ReleaseLogger.emit(
      event: 'sync_queue_flush_completed',
      category: ReleaseLogCategory.sync,
      fields: {
        'transcripts_reconciled': transcriptsReconciled,
        'proofs_admitted': proofsAdmitted,
        'cloud_sync_attempted': cloudSyncAttempted,
        'cloud_sync_succeeded': cloudSyncSucceeded,
        'vault_upload_attempted': vaultUploadAttempted,
        'vault_upload_succeeded': vaultUploadSucceeded,
      },
    );
  }

  static void flushSkipped({required String reason}) {
    ReleaseLogger.emit(
      event: 'sync_queue_flush_skipped',
      category: ReleaseLogCategory.sync,
      fields: {
        'reason': ReleaseLogSanitizer.sanitizeReasonCode(reason),
      },
    );
  }

  static void phaseFailed({
    required String phase,
    required Object error,
    StackTrace? stackTrace,
  }) {
    ReleaseLogger.emit(
      event: 'sync_queue_phase_failed',
      category: ReleaseLogCategory.sync,
      severity: ReleaseLogSeverity.warn,
      fields: {
        'success': false,
        'phase': ReleaseLogSanitizer.sanitizeReasonCode(phase),
        'error_code': ReleaseLogSanitizer.errorCodeFromObject(error),
      },
    );
    if (stackTrace != null) {
      ReleaseLogger.debugDetail(
        event: 'sync_queue_phase_failed_detail',
        category: ReleaseLogCategory.sync,
        fields: {'stack_trace': stackTrace.toString()},
      );
    }
  }
}
