import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/data/repositories/sync_repository.dart';
import 'package:archiveme_mobile/features/auth/application/auth_session_notifier.dart' show AuthSessionNotifier;
import 'package:archiveme_mobile/features/sync/application/sync_failure_result.dart';
import 'package:archiveme_mobile/features/sync/application/sync_state.dart';
import 'package:archiveme_mobile/services/sync_service.dart';
import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    ReleaseLogger.apiFailure(
      event: 'sync_${operation}_failed',
      category: ReleaseLogCategory.sync,
      failure: failure,
    );
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