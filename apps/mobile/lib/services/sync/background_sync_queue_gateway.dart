import 'dart:async';

import 'package:archiveme_mobile/features/auth/application/server_consent_revocation_coordinator.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/network_connectivity_source.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/services/sync/background_sync_queue_worker.dart';

/// Wires the background sync queue to connectivity, consent, and retry backoff.
class BackgroundSyncQueueGateway {
  BackgroundSyncQueueGateway({
    required NetworkConnectivitySource connectivity,
    required RemoteProcessingConsentStore consentStore,
    required BackgroundSyncQueueWorker worker,
    this._consentRevocations,
  }) : _connectivity = connectivity,
       _worker = worker {
    _subscriptions.add(
      _connectivity.onConnectivityRestored.listen((_) {
        unawaited(_onRestoreTrigger('connectivity'));
      }),
    );
    _subscriptions.add(
      _connectivity.onOnlineChanged.listen((online) {
        if (online) {
          unawaited(_onRestoreTrigger('online'));
        }
      }),
    );
    _subscriptions.add(
      consentStore.onChanged.listen((_) {
        unawaited(_onRestoreTrigger('consent'));
      }),
    );
    unawaited(worker.enqueueAllPending());
  }

  final NetworkConnectivitySource _connectivity;
  final BackgroundSyncQueueWorker _worker;
  final ServerConsentRevocationCoordinator? _consentRevocations;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Timer? _retryTimer;

  Future<void> _onRestoreTrigger(String trigger) async {
    // Consent revocations the device owes the server ride the same
    // connectivity-restored signal rather than a parallel listener. Ordered
    // first: withdrawing someone's access outranks uploading a reflection.
    await (_consentRevocations ?? ServerConsentRevocationCoordinator.instance)
        .flushPending();
    await _worker.enqueueAllPending();
    await _attemptFlush(trigger: trigger);
  }

  Future<void> _attemptFlush({required String trigger}) async {
    _retryTimer?.cancel();
    _retryTimer = null;

    final result = await _worker.flush(isOnline: _connectivity.isOnline);
    final retryAt = result.nextOutboxRetryAt;
    if (retryAt == null) {
      return;
    }

    final delay = retryAt.difference(DateTime.now().toUtc());
    _retryTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => unawaited(_attemptFlush(trigger: 'outbox_backoff')),
    );
  }

  void dispose() {
    _retryTimer?.cancel();
    _retryTimer = null;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }
}
