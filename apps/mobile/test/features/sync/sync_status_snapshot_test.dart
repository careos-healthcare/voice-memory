import 'package:archiveme_mobile/features/sync/application/background_sync_state.dart';
import 'package:archiveme_mobile/features/sync/presentation/sync_status_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncStatusSnapshot', () {
    test('shows banner when offline with pending uploads', () {
      const status = SyncStatusSnapshot(
        sync: BackgroundSyncState(
          queuedEntryCount: 2,
          pendingOutboxCount: 3,
        ),
        isOnline: false,
      );

      expect(status.showBanner, isTrue);
      expect(status.pendingUploadCount, 5);
      expect(status.visualKind, SyncStatusVisualKind.offline);
      expect(
        status.bannerMessage,
        contains('5 items will upload when connected'),
      );
    });

    test('shows progress while active sync phase runs', () {
      const status = SyncStatusSnapshot(
        sync: BackgroundSyncState(
          phase: BackgroundSyncPhase.cloudSync,
          pendingOutboxCount: 1,
        ),
        isOnline: true,
      );

      expect(status.showBanner, isTrue);
      expect(status.showProgress, isTrue);
      expect(status.progressFraction, 0.90);
      expect(status.visualKind, SyncStatusVisualKind.syncing);
      expect(status.bannerMessage, contains('Syncing with cloud'));
    });

    test('hides banner when idle, online, and no pending uploads', () {
      const status = SyncStatusSnapshot(
        sync: BackgroundSyncState(
          phase: BackgroundSyncPhase.idle,
        ),
        isOnline: true,
      );

      expect(status.showBanner, isFalse);
      expect(status.showHeaderIndicator, isFalse);
    });
  });
}
