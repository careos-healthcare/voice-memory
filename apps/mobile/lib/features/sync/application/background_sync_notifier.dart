import 'package:archiveme_mobile/features/sync/application/background_sync_state.dart';
import 'package:archiveme_mobile/features/sync/application/background_sync_state_machine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod surface for background sync queue progress and retry scheduling.
class BackgroundSyncNotifier extends Notifier<BackgroundSyncState> {
  BackgroundSyncController? _controller;

  @override
  BackgroundSyncState build() => const BackgroundSyncState();

  BackgroundSyncController bindController() {
    _controller ??= BackgroundSyncController(
      onStateChanged: (next) => state = next,
    );
    state = _controller!.state;
    return _controller!;
  }

  BackgroundSyncController get controller {
    return _controller ?? bindController();
  }

  void setConnectivity({required bool isOnline}) {
    controller.setConnectivity(isOnline: isOnline);
  }

  void setQueueCounts({
    required int queuedEntryCount,
    required int pendingOutboxCount,
  }) {
    controller.setQueueCounts(
      queuedEntryCount: queuedEntryCount,
      pendingOutboxCount: pendingOutboxCount,
    );
  }
}

final backgroundSyncProvider =
    NotifierProvider<BackgroundSyncNotifier, BackgroundSyncState>(
      BackgroundSyncNotifier.new,
    );

final backgroundSyncPhaseProvider = Provider<BackgroundSyncPhase>(
  (ref) => ref.watch(backgroundSyncProvider).phase,
);

final backgroundSyncNotifierProvider = Provider<BackgroundSyncNotifier>(
  (ref) => ref.read(backgroundSyncProvider.notifier),
);
