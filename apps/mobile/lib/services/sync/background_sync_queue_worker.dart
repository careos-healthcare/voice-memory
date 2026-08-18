import 'dart:async';

import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/models/transcript_status.dart';
import 'package:archiveme_mobile/services/capture_attest_service.dart';
import 'package:archiveme_mobile/services/sync/deferred_proof_admission_reconciler.dart';
import 'package:archiveme_mobile/services/sync/sync_pipeline_log.dart';
import 'package:archiveme_mobile/services/sync_service.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/provisional_transcript_reconciler.dart';

/// Result summary for a single background sync queue flush cycle.
class BackgroundSyncFlushResult {
  const BackgroundSyncFlushResult({
    required this.transcriptsReconciled,
    required this.proofsAdmitted,
    required this.cloudSyncAttempted,
    required this.cloudSyncSucceeded,
  });

  final int transcriptsReconciled;
  final int proofsAdmitted;
  final bool cloudSyncAttempted;
  final bool cloudSyncSucceeded;
}

/// Coalesced async worker for offline-first journal sync and deferred capture
/// pipeline steps (attestation, STT, proof admission, encrypted cloud sync).
class BackgroundSyncQueueWorker {
  BackgroundSyncQueueWorker({
    required JournalStore journalStore,
    required SyncService syncService,
    required CaptureAttestService attest,
    required ProvisionalTranscriptReconciler transcriptReconciler,
    required DeferredProofAdmissionReconciler proofReconciler,
    Duration debounce = const Duration(milliseconds: 400),
  }) : _journalStore = journalStore,
       _syncService = syncService,
       _attest = attest,
       _transcriptReconciler = transcriptReconciler,
       _proofReconciler = proofReconciler,
       _debounce = debounce;

  final JournalStore _journalStore;
  final SyncService _syncService;
  final CaptureAttestService _attest;
  final ProvisionalTranscriptReconciler _transcriptReconciler;
  final DeferredProofAdmissionReconciler _proofReconciler;
  final Duration _debounce;

  final Set<String> _queuedEntryIds = <String>{};
  Timer? _debounceTimer;
  var _flushInFlight = false;
  var _flushRescheduled = false;

  /// Whether [entry] should enter the background sync queue.
  static bool needsBackgroundWork(JournalEntry entry) {
    if (entry.isDeleted) return false;
    if (entry.syncStatus == SyncStatus.pendingUpload ||
        entry.syncStatus == SyncStatus.localOnly) {
      return true;
    }
    if (entry.transcriptStatus.isProvisional ||
        entry.transcriptStatus.isPending) {
      return true;
    }
    return DeferredProofAdmissionReconciler.needsDeferredProofAdmission(entry);
  }

  static String enqueueReasonFor(JournalEntry entry) {
    if (entry.transcriptStatus.isProvisional ||
        entry.transcriptStatus.isPending) {
      return 'transcript_deferred';
    }
    if (DeferredProofAdmissionReconciler.needsDeferredProofAdmission(entry)) {
      return 'proof_admission_deferred';
    }
    if (entry.syncStatus == SyncStatus.pendingUpload ||
        entry.syncStatus == SyncStatus.localOnly) {
      return 'sync_pending';
    }
    return 'unknown';
  }

  /// Registers [entry] for the next coalesced flush when it needs background work.
  void enqueue(JournalEntry entry) {
    if (!needsBackgroundWork(entry)) return;
    _queuedEntryIds.add(entry.id);
    SyncPipelineLog.enqueued(
      entryId: entry.id,
      reason: enqueueReasonFor(entry),
    );
    _scheduleFlush();
  }

  /// Scans the journal for all entries needing background work.
  Future<void> enqueueAllPending() async {
    final entries = await _journalStore.loadAllIncludingTombstones();
    var added = false;
    for (final entry in entries) {
      if (!needsBackgroundWork(entry)) continue;
      _queuedEntryIds.add(entry.id);
      added = true;
    }
    if (added) {
      _scheduleFlush();
    }
  }

  void _scheduleFlush() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      unawaited(flush());
    });
  }

  /// Runs attestation refresh, deferred STT, proof admission, and cloud sync.
  Future<BackgroundSyncFlushResult> flush() async {
    if (_flushInFlight) {
      _flushRescheduled = true;
      return const BackgroundSyncFlushResult(
        transcriptsReconciled: 0,
        proofsAdmitted: 0,
        cloudSyncAttempted: false,
        cloudSyncSucceeded: false,
      );
    }

    _flushInFlight = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;

    try {
      do {
        _flushRescheduled = false;
        final pendingCount = _queuedEntryIds.length;
        if (pendingCount == 0) {
          SyncPipelineLog.flushSkipped(reason: 'empty_queue');
          return const BackgroundSyncFlushResult(
            transcriptsReconciled: 0,
            proofsAdmitted: 0,
            cloudSyncAttempted: false,
            cloudSyncSucceeded: false,
          );
        }

        SyncPipelineLog.flushStarted(pendingCount: pendingCount);
        _queuedEntryIds.clear();

        var transcriptsReconciled = 0;
        var proofsAdmitted = 0;
        var cloudSyncAttempted = false;
        var cloudSyncSucceeded = false;

        try {
          await _attest.ensureCaptureToken();
        } catch (error, stackTrace) {
          SyncPipelineLog.phaseFailed(phase: 'attestation', error: error);
          assert(() {
            // ignore: avoid_print
            print('BackgroundSyncQueueWorker attestation failed: $error\n$stackTrace');
            return true;
          }());
        }

        try {
          transcriptsReconciled = await _transcriptReconciler.reconcileAll();
        } catch (error, stackTrace) {
          SyncPipelineLog.phaseFailed(phase: 'transcription', error: error);
          assert(() {
            // ignore: avoid_print
            print('BackgroundSyncQueueWorker transcription failed: $error\n$stackTrace');
            return true;
          }());
        }

        try {
          proofsAdmitted = await _proofReconciler.reconcileAll();
        } catch (error, stackTrace) {
          SyncPipelineLog.phaseFailed(phase: 'proof_admission', error: error);
          assert(() {
            // ignore: avoid_print
            print('BackgroundSyncQueueWorker proof admission failed: $error\n$stackTrace');
            return true;
          }());
        }

        if (AppConfig.isBackendConfigured) {
          final pendingSync = await _journalStore.pendingSyncQueue();
          if (pendingSync.isNotEmpty) {
            cloudSyncAttempted = true;
            try {
              final result = await _syncService.syncNow();
              cloudSyncSucceeded = result.cloudSyncSucceeded;
            } catch (error, stackTrace) {
              SyncPipelineLog.phaseFailed(phase: 'cloud_sync', error: error);
              assert(() {
                // ignore: avoid_print
                print('BackgroundSyncQueueWorker cloud sync failed: $error\n$stackTrace');
                return true;
              }());
            }
          }
        }

        SyncPipelineLog.flushCompleted(
          transcriptsReconciled: transcriptsReconciled,
          proofsAdmitted: proofsAdmitted,
          cloudSyncAttempted: cloudSyncAttempted,
          cloudSyncSucceeded: cloudSyncSucceeded,
        );

        final result = BackgroundSyncFlushResult(
          transcriptsReconciled: transcriptsReconciled,
          proofsAdmitted: proofsAdmitted,
          cloudSyncAttempted: cloudSyncAttempted,
          cloudSyncSucceeded: cloudSyncSucceeded,
        );

        if (_flushRescheduled) {
          continue;
        }
        return result;
      } while (_flushRescheduled);

      return const BackgroundSyncFlushResult(
        transcriptsReconciled: 0,
        proofsAdmitted: 0,
        cloudSyncAttempted: false,
        cloudSyncSucceeded: false,
      );
    } finally {
      _flushInFlight = false;
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _queuedEntryIds.clear();
  }
}
