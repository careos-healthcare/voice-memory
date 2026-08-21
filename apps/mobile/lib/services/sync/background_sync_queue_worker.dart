import 'dart:async';

import 'package:archiveme_mobile/core/execution/execution.dart';
import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/features/sync/application/background_sync_state.dart';
import 'package:archiveme_mobile/features/sync/application/background_sync_state_machine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/models/transcript_status.dart';
import 'package:archiveme_mobile/services/capture_attest_service.dart';
import 'package:archiveme_mobile/services/sync/deferred_proof_admission_reconciler.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_index_worker.dart';
import 'package:archiveme_mobile/services/sync/sync_pipeline_log.dart';
import 'package:archiveme_mobile/services/sync_service.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/sync/sync_outbox_background_service.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/provisional_transcript_reconciler.dart';

/// Result summary for a single background sync queue flush cycle.
class BackgroundSyncFlushResult {
  const BackgroundSyncFlushResult({
    required this.transcriptsReconciled,
    required this.proofsAdmitted,
    required this.cloudSyncAttempted,
    required this.cloudSyncSucceeded,
    required this.vaultUploadAttempted,
    required this.vaultUploadSucceeded,
    this.nextOutboxRetryAt,
  });

  final int transcriptsReconciled;
  final int proofsAdmitted;
  final bool cloudSyncAttempted;
  final bool cloudSyncSucceeded;
  final bool vaultUploadAttempted;
  final bool vaultUploadSucceeded;
  final DateTime? nextOutboxRetryAt;
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
    SyncOutboxBackgroundService? outboxBackgroundService,
    ReflectionEmbeddingIndexWorker? reflectionEmbeddingWorker,
    BackgroundSyncController? syncController,
    Future<int> Function()? pendingOutboxCount,
    Future<DateTime?> Function()? nextOutboxRetryAt,
    Future<bool> Function()? uploadSqliteVault,
    void Function()? onBackgroundFlushCompleted,
    SyncExecutionStrategy? syncStrategy,
    Duration debounce = const Duration(milliseconds: 400),
  }) : _journalStore = journalStore,
       _syncService = syncService,
       _attest = attest,
       _transcriptReconciler = transcriptReconciler,
       _proofReconciler = proofReconciler,
       _outboxBackgroundService = outboxBackgroundService,
       _reflectionEmbeddingWorker = reflectionEmbeddingWorker,
       _syncController = syncController,
       _pendingOutboxCount = pendingOutboxCount,
       _nextOutboxRetryAt = nextOutboxRetryAt,
       _uploadSqliteVault = uploadSqliteVault,
       _onBackgroundFlushCompleted = onBackgroundFlushCompleted,
       _syncStrategy = syncStrategy ?? SyncExecutionStrategy.shared,
       _debounce = debounce;

  final JournalStore _journalStore;
  final SyncService _syncService;
  final CaptureAttestService _attest;
  final ProvisionalTranscriptReconciler _transcriptReconciler;
  final DeferredProofAdmissionReconciler _proofReconciler;
  final SyncOutboxBackgroundService? _outboxBackgroundService;
  final ReflectionEmbeddingIndexWorker? _reflectionEmbeddingWorker;
  final BackgroundSyncController? _syncController;
  final Future<int> Function()? _pendingOutboxCount;
  final Future<DateTime?> Function()? _nextOutboxRetryAt;
  final Future<bool> Function()? _uploadSqliteVault;
  final void Function()? _onBackgroundFlushCompleted;
  final SyncExecutionStrategy _syncStrategy;
  final Duration _debounce;

  final Set<String> _queuedEntryIds = <String>{};
  var _vaultUploadPending = false;
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

  /// Schedules an encrypted SQLite vault upload after the next journal save.
  ///
  /// Called from [JournalSaveSyncEnqueueInterceptor] so every durable write
  /// eventually backs up the sealed database to iCloud, even when no other
  /// sync work is pending.
  void requestSqliteVaultUpload() {
    if (_uploadSqliteVault == null) return;
    _vaultUploadPending = true;
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

  Future<void> _refreshQueueCounts() async {
    final controller = _syncController;
    if (controller == null) return;
    final outboxCountFn = _pendingOutboxCount;
    final pendingOutboxCount = outboxCountFn == null ? 0 : await outboxCountFn();
    controller.setQueueCounts(
      queuedEntryCount: _queuedEntryIds.length,
      pendingOutboxCount: pendingOutboxCount,
    );
  }

  Future<T?> _runPhase<T>(
    BackgroundSyncPhase phase,
    Future<T> Function() action,
  ) async {
    _syncController?.beginPhase(phase);
    final result = await _syncStrategy.runPhase(
      phaseLabel: phase.name,
      action: action,
    );
    return result.when(
      success: (value) => value,
      onFailure: (failure) {
        _syncController?.recordPhaseFailure(phase, failure.userMessage);
        return null;
      },
      onDeferred: (reason) {
        _syncController?.recordPhaseFailure(phase, reason.userMessage);
        return null;
      },
      onCancelled: () => null,
    );
  }

  /// Runs attestation refresh, deferred STT, proof admission, and cloud sync.
  Future<BackgroundSyncFlushResult> flush({bool isOnline = true}) async {
    if (!isOnline) {
      _syncController?.setConnectivity(isOnline: false);
      await _refreshQueueCounts();
      return const BackgroundSyncFlushResult(
        transcriptsReconciled: 0,
        proofsAdmitted: 0,
        cloudSyncAttempted: false,
        cloudSyncSucceeded: false,
        vaultUploadAttempted: false,
        vaultUploadSucceeded: false,
      );
    }

    _syncController?.setConnectivity(isOnline: true);

    if (_flushInFlight) {
      _flushRescheduled = true;
      return const BackgroundSyncFlushResult(
        transcriptsReconciled: 0,
        proofsAdmitted: 0,
        cloudSyncAttempted: false,
        cloudSyncSucceeded: false,
        vaultUploadAttempted: false,
        vaultUploadSucceeded: false,
      );
    }

    _flushInFlight = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;

    try {
      do {
        _flushRescheduled = false;
        final pendingCount = _queuedEntryIds.length;
        await _refreshQueueCounts();
        if (pendingCount == 0) {
          final outboxCountFn = _pendingOutboxCount;
          final pendingOutbox =
              outboxCountFn == null ? 0 : await outboxCountFn();
          if (pendingOutbox == 0 && !_vaultUploadPending) {
            SyncPipelineLog.flushSkipped(reason: 'empty_queue');
            _syncController?.resetToIdle();
            return const BackgroundSyncFlushResult(
              transcriptsReconciled: 0,
              proofsAdmitted: 0,
              cloudSyncAttempted: false,
              cloudSyncSucceeded: false,
              vaultUploadAttempted: false,
              vaultUploadSucceeded: false,
            );
          }
        }

        SyncPipelineLog.flushStarted(pendingCount: pendingCount);
        _queuedEntryIds.clear();

        var transcriptsReconciled = 0;
        var proofsAdmitted = 0;
        var cloudSyncAttempted = false;
        var cloudSyncSucceeded = false;
        var vaultUploadAttempted = false;
        var vaultUploadSucceeded = false;

        try {
          await _runPhase(
            BackgroundSyncPhase.attestation,
            _attest.ensureCaptureToken,
          );
        } catch (error, stackTrace) {
          SyncPipelineLog.phaseFailed(phase: 'attestation', error: error, stackTrace: stackTrace);
          assert(() {
            // ignore: avoid_print
            print('BackgroundSyncQueueWorker attestation failed: $error\n$stackTrace');
            return true;
          }());
        }

        try {
          transcriptsReconciled = await _runPhase(
            BackgroundSyncPhase.transcription,
            _transcriptReconciler.reconcileAll,
          ) ?? 0;
        } catch (error, stackTrace) {
          SyncPipelineLog.phaseFailed(phase: 'transcription', error: error, stackTrace: stackTrace);
          assert(() {
            // ignore: avoid_print
            print('BackgroundSyncQueueWorker transcription failed: $error\n$stackTrace');
            return true;
          }());
        }

        try {
          proofsAdmitted = await _runPhase(
            BackgroundSyncPhase.proofAdmission,
            _proofReconciler.reconcileAll,
          ) ?? 0;
        } catch (error, stackTrace) {
          SyncPipelineLog.phaseFailed(phase: 'proof_admission', error: error, stackTrace: stackTrace);
          assert(() {
            // ignore: avoid_print
            print('BackgroundSyncQueueWorker proof admission failed: $error\n$stackTrace');
            return true;
          }());
        }

        final reflectionWorker = _reflectionEmbeddingWorker;
        if (reflectionWorker != null) {
          try {
            await _runPhase(
              BackgroundSyncPhase.reflectionEmbedding,
              reflectionWorker.flush,
            );
          } catch (error, stackTrace) {
            SyncPipelineLog.phaseFailed(
              phase: 'reflection_embedding_index',
              error: error, stackTrace: stackTrace,
            );
            assert(() {
              // ignore: avoid_print
              print(
                'BackgroundSyncQueueWorker reflection embedding failed: '
                '$error\n$stackTrace',
              );
              return true;
            }());
          }
        }

        if (AppConfig.isBackendConfigured) {
          final outboxDrainer = _outboxBackgroundService;
          if (outboxDrainer != null) {
            try {
              await _runPhase(
                BackgroundSyncPhase.outboxDrain,
                outboxDrainer.drainPending,
              );
            } catch (error, stackTrace) {
              SyncPipelineLog.phaseFailed(phase: 'sync_outbox', error: error, stackTrace: stackTrace);
              assert(() {
                // ignore: avoid_print
                print('BackgroundSyncQueueWorker outbox drain failed: $error\n$stackTrace');
                return true;
              }());
            }
          }

          final pendingSync = await _journalStore.pendingSyncQueue();
          if (pendingSync.isNotEmpty) {
            cloudSyncAttempted = true;
            try {
              final result = await _runPhase(
                BackgroundSyncPhase.cloudSync,
                _syncService.syncNow,
              );
              cloudSyncSucceeded = result?.cloudSyncSucceeded ?? false;
            } catch (error, stackTrace) {
              SyncPipelineLog.phaseFailed(phase: 'cloud_sync', error: error, stackTrace: stackTrace);
              assert(() {
                // ignore: avoid_print
                print('BackgroundSyncQueueWorker cloud sync failed: $error\n$stackTrace');
                return true;
              }());
            }
          }
        }

        final uploadVault = _uploadSqliteVault;
        if (_vaultUploadPending && uploadVault != null) {
          vaultUploadAttempted = true;
          try {
            final succeeded = await _runPhase(
              BackgroundSyncPhase.sqliteVaultUpload,
              uploadVault,
            );
            vaultUploadSucceeded = succeeded ?? false;
            if (vaultUploadSucceeded) {
              _vaultUploadPending = false;
            }
          } catch (error, stackTrace) {
            SyncPipelineLog.phaseFailed(
              phase: 'sqlite_vault_upload',
              error: error,
              stackTrace: stackTrace,
            );
            assert(() {
              // ignore: avoid_print
              print(
                'BackgroundSyncQueueWorker sqlite vault upload failed: '
                '$error\n$stackTrace',
              );
              return true;
            }());
          }
        }

        final nextRetryFn = _nextOutboxRetryAt;
        final nextOutboxRetryAt =
            nextRetryFn == null ? null : await nextRetryFn();
        if (nextOutboxRetryAt != null) {
          _syncController?.scheduleRetry(nextOutboxRetryAt);
        } else {
          _syncController?.complete(
            transcriptsReconciled: transcriptsReconciled,
            proofsAdmitted: proofsAdmitted,
            cloudSyncSucceeded: cloudSyncSucceeded,
            vaultUploadSucceeded: vaultUploadSucceeded,
          );
        }

        await _refreshQueueCounts();

        SyncPipelineLog.flushCompleted(
          transcriptsReconciled: transcriptsReconciled,
          proofsAdmitted: proofsAdmitted,
          cloudSyncAttempted: cloudSyncAttempted,
          cloudSyncSucceeded: cloudSyncSucceeded,
          vaultUploadAttempted: vaultUploadAttempted,
          vaultUploadSucceeded: vaultUploadSucceeded,
        );

        final result = BackgroundSyncFlushResult(
          transcriptsReconciled: transcriptsReconciled,
          proofsAdmitted: proofsAdmitted,
          cloudSyncAttempted: cloudSyncAttempted,
          cloudSyncSucceeded: cloudSyncSucceeded,
          vaultUploadAttempted: vaultUploadAttempted,
          vaultUploadSucceeded: vaultUploadSucceeded,
          nextOutboxRetryAt: nextOutboxRetryAt,
        );

        if (_flushRescheduled) {
          continue;
        }
        _onBackgroundFlushCompleted?.call();
        return result;
      } while (_flushRescheduled);

      return const BackgroundSyncFlushResult(
        transcriptsReconciled: 0,
        proofsAdmitted: 0,
        cloudSyncAttempted: false,
        cloudSyncSucceeded: false,
        vaultUploadAttempted: false,
        vaultUploadSucceeded: false,
      );
    } finally {
      _flushInFlight = false;
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _queuedEntryIds.clear();
    _vaultUploadPending = false;
  }
}