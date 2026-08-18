import 'dart:async';

import 'package:archiveme_mobile/features/live_audio/infrastructure/network_connectivity_source.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/services/sync/background_sync_queue_worker.dart';

/// Wires the background sync queue to connectivity and consent restoration.
class BackgroundSyncQueueGateway {
  BackgroundSyncQueueGateway({
    required NetworkConnectivitySource connectivity,
    required RemoteProcessingConsentStore consentStore,
    required BackgroundSyncQueueWorker worker,
  }) : _worker = worker {
    _subscriptions.add(
      connectivity.onConnectivityRestored.listen((_) {
        unawaited(_onRestoreTrigger('connectivity'));
      }),
    );
    _subscriptions.add(
      consentStore.onChanged.listen((_) {
        unawaited(_onRestoreTrigger('consent'));
      }),
    );
    unawaited(worker.enqueueAllPending());
  }

  final BackgroundSyncQueueWorker _worker;
  final List<StreamSubscription<void>> _subscriptions = [];

  Future<void> _onRestoreTrigger(String trigger) async {
    await _worker.enqueueAllPending();
    await _worker.flush();
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }
}
