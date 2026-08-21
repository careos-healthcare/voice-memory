import 'package:archiveme_mobile/core/execution/execution_failure.dart';
import 'package:archiveme_mobile/features/sync/application/background_sync_state.dart';

/// Pure transition logic for background sync phases.
class BackgroundSyncStateMachine {
  BackgroundSyncStateMachine({BackgroundSyncState? initial})
      : _state = initial ?? const BackgroundSyncState();

  BackgroundSyncState _state;

  BackgroundSyncState get state => _state;

  void setConnectivity({required bool isOnline}) {
    _state = _state.copyWith(isOnline: isOnline);
    if (!isOnline &&
        _state.phase != BackgroundSyncPhase.completed &&
        _state.phase != BackgroundSyncPhase.failed) {
      _state = _state.copyWith(phase: BackgroundSyncPhase.waitingForNetwork);
    }
  }

  void setQueueCounts({
    required int queuedEntryCount,
    required int pendingOutboxCount,
  }) {
    _state = _state.copyWith(
      queuedEntryCount: queuedEntryCount,
      pendingOutboxCount: pendingOutboxCount,
    );
  }

  void scheduleRetry(DateTime retryAt) {
    _state = _state.copyWith(
      phase: BackgroundSyncPhase.waitingForRetry,
      nextRetryAt: retryAt,
    );
  }

  void beginPhase(BackgroundSyncPhase phase) {
    _state = _state.copyWith(
      phase: phase,
      clearLastError: true,
      clearNextRetryAt: true,
    );
  }

  void recordPhaseFailure(BackgroundSyncPhase phase, Object error) {
    final message = error is ExecutionFailureState
        ? error.userMessage
        : mapErrorToSyncFailure(error).userMessage;
    _state = _state.copyWith(lastError: '$phase: $message');
    if (error is SyncExecutionFailure) {
      _state = _state.copyWith(phase: error.suggestedPhase);
    }
  }

  void failFlush(Object error) {
    _state = _state.copyWith(
      phase: BackgroundSyncPhase.failed,
      lastError: '$error',
    );
  }

  void complete({
    required int transcriptsReconciled,
    required int proofsAdmitted,
    required bool cloudSyncSucceeded,
    bool vaultUploadSucceeded = false,
  }) {
    _state = _state.copyWith(
      phase: BackgroundSyncPhase.completed,
      lastCompletedAt: DateTime.now().toUtc(),
      transcriptsReconciled: transcriptsReconciled,
      proofsAdmitted: proofsAdmitted,
      cloudSyncSucceeded: cloudSyncSucceeded,
      vaultUploadSucceeded: vaultUploadSucceeded,
      clearLastError: true,
      clearNextRetryAt: true,
    );
  }

  void resetToIdle() {
    _state = _state.copyWith(
      phase: BackgroundSyncPhase.idle,
      clearLastError: true,
    );
  }
}

/// Bridges imperative worker callbacks into [BackgroundSyncStateMachine].
class BackgroundSyncController {
  BackgroundSyncController({
    BackgroundSyncStateMachine? machine,
    void Function(BackgroundSyncState state)? onStateChanged,
  }) : _machine = machine ?? BackgroundSyncStateMachine(),
       _onStateChanged = onStateChanged;

  final BackgroundSyncStateMachine _machine;
  final void Function(BackgroundSyncState state)? _onStateChanged;

  BackgroundSyncState get state => _machine.state;

  void _emit() => _onStateChanged?.call(_machine.state);

  void setConnectivity({required bool isOnline}) {
    _machine.setConnectivity(isOnline: isOnline);
    _emit();
  }

  void setQueueCounts({
    required int queuedEntryCount,
    required int pendingOutboxCount,
  }) {
    _machine.setQueueCounts(
      queuedEntryCount: queuedEntryCount,
      pendingOutboxCount: pendingOutboxCount,
    );
    _emit();
  }

  void scheduleRetry(DateTime retryAt) {
    _machine.scheduleRetry(retryAt);
    _emit();
  }

  void beginPhase(BackgroundSyncPhase phase) {
    _machine.beginPhase(phase);
    _emit();
  }

  void recordPhaseFailure(BackgroundSyncPhase phase, Object error) {
    _machine.recordPhaseFailure(phase, error);
    _emit();
  }

  void failFlush(Object error) {
    _machine.failFlush(error);
    _emit();
  }

  void complete({
    required int transcriptsReconciled,
    required int proofsAdmitted,
    required bool cloudSyncSucceeded,
    bool vaultUploadSucceeded = false,
  }) {
    _machine.complete(
      transcriptsReconciled: transcriptsReconciled,
      proofsAdmitted: proofsAdmitted,
      cloudSyncSucceeded: cloudSyncSucceeded,
      vaultUploadSucceeded: vaultUploadSucceeded,
    );
    _emit();
  }

  void resetToIdle() {
    _machine.resetToIdle();
    _emit();
  }
}
