import 'package:archiveme_mobile/features/sync/application/background_sync_state.dart';
import 'package:archiveme_mobile/features/sync/presentation/sync_status_copy.dart';
import 'package:flutter/foundation.dart';

/// Combined sync + connectivity snapshot for reactive status UI.
@immutable
class SyncStatusSnapshot {
  const SyncStatusSnapshot({
    required this.sync,
    required this.isOnline,
  });

  final BackgroundSyncState sync;
  final bool isOnline;

  int get pendingUploadCount =>
      sync.queuedEntryCount + sync.pendingOutboxCount;

  bool get showBanner =>
      !isOnline ||
      sync.phase == BackgroundSyncPhase.failed ||
      sync.phase == BackgroundSyncPhase.waitingForRetry ||
      sync.phase == BackgroundSyncPhase.waitingForNetwork ||
      sync.isActive ||
      pendingUploadCount > 0;

  bool get showHeaderIndicator =>
      !isOnline ||
      sync.phase == BackgroundSyncPhase.failed ||
      sync.phase == BackgroundSyncPhase.waitingForRetry ||
      sync.phase == BackgroundSyncPhase.waitingForNetwork ||
      sync.isActive ||
      pendingUploadCount > 0;

  bool get showProgress => sync.isActive;

  double? get progressFraction => SyncStatusCopy.progressFraction(sync.phase);

  String get bannerMessage => SyncStatusCopy.bannerMessage(
    sync: sync,
    isOnline: isOnline,
    pendingUploadCount: pendingUploadCount,
  );

  String get headerSemanticsLabel => SyncStatusCopy.headerSemanticsLabel(
    sync: sync,
    isOnline: isOnline,
    pendingUploadCount: pendingUploadCount,
  );

  String? get headerBadgeLabel =>
      pendingUploadCount > 0 ? pendingUploadCount.toString() : null;

  SyncStatusVisualKind get visualKind {
    if (!isOnline ||
        sync.phase == BackgroundSyncPhase.waitingForNetwork) {
      return SyncStatusVisualKind.offline;
    }
    if (sync.phase == BackgroundSyncPhase.failed) {
      return SyncStatusVisualKind.error;
    }
    if (sync.isActive) {
      return SyncStatusVisualKind.syncing;
    }
    if (sync.phase == BackgroundSyncPhase.waitingForRetry) {
      return SyncStatusVisualKind.waiting;
    }
    if (pendingUploadCount > 0) {
      return SyncStatusVisualKind.pending;
    }
    return SyncStatusVisualKind.idle;
  }
}

enum SyncStatusVisualKind {
  idle,
  syncing,
  pending,
  waiting,
  offline,
  error,
}
