import 'package:archiveme_mobile/features/sync/application/background_sync_notifier.dart';
import 'package:archiveme_mobile/features/sync/application/background_sync_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BackgroundSyncNotifier mirrors controller transitions', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(backgroundSyncProvider.notifier);
    notifier.bindController();

    notifier.controller.beginPhase(BackgroundSyncPhase.outboxDrain);
    expect(
      container.read(backgroundSyncProvider).phase,
      BackgroundSyncPhase.outboxDrain,
    );

    notifier.setConnectivity(isOnline: false);
    expect(container.read(backgroundSyncProvider).isOnline, isFalse);

    notifier.setQueueCounts(
      queuedEntryCount: 4,
      pendingOutboxCount: 2,
    );
    final state = container.read(backgroundSyncProvider);
    expect(state.queuedEntryCount, 4);
    expect(state.pendingOutboxCount, 2);
  });
}
