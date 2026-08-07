import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/network_providers.dart';
import '../../../core/network/api_failure.dart';
import '../../../data/repositories/sync_repository.dart';
import '../../../services/sync_service.dart';
import 'sync_failure_result.dart';
import 'sync_state.dart';

/// Immutable sync boundary — mirrors [AuthSessionNotifier] Riverpod patterns.
class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() => const SyncState();

  SyncRepository get _repository => ref.read(syncRepositoryProvider);

  Future<SyncResult> syncNow() async {
    state = state.copyWith(
      phase: SyncPhase.syncing,
      clearLastFailure: true,
      partialPushed: 0,
    );
    final result = await _repository.syncNow();
    return result.when(
      success: (syncResult) {
        state = SyncState(
          phase: syncResult.cloudSyncSucceeded
              ? SyncPhase.completed
              : SyncPhase.failed,
          lastResult: syncResult,
          partialPushed: syncResult.pushed,
        );
        return syncResult;
      },
      onFailure: (failure) {
        _logFailure('syncNow', failure);
        final syncResult = syncResultForFailure(
          failure,
          partialPushed: state.partialPushed,
        );
        state = SyncState(
          phase: SyncPhase.failed,
          lastResult: syncResult,
          lastFailure: failure,
          partialPushed: state.partialPushed,
        );
        return syncResult;
      },
    );
  }

  Future<String> lastSyncLabel() => _repository.lastSyncLabel();

  void _logFailure(String operation, ApiFailure failure) {
    debugPrint('Sync: $operation failed — ${failure.code}: ${failure.message}');
  }
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(
  SyncNotifier.new,
);

final syncNotifierProvider = Provider<SyncNotifier>(
  (ref) => ref.read(syncProvider.notifier),
);

final syncPhaseProvider = Provider<SyncPhase>(
  (ref) => ref.watch(syncProvider).phase,
);

final lastSyncResultProvider = Provider<SyncResult?>(
  (ref) => ref.watch(syncProvider).lastResult,
);
