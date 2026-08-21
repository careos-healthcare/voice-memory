import 'package:archiveme_mobile/features/sync/application/background_sync_state.dart';

/// User-facing copy for sync status widgets.
abstract final class SyncStatusCopy {
  SyncStatusCopy._();

  static String bannerMessage({
    required BackgroundSyncState sync,
    required bool isOnline,
    required int pendingUploadCount,
  }) {
    if (!isOnline || sync.phase == BackgroundSyncPhase.waitingForNetwork) {
      if (pendingUploadCount > 0) {
        return 'Offline — $pendingUploadCount '
            '${_itemLabel(pendingUploadCount)} will upload when connected.';
      }
      return 'Offline — changes will sync when you reconnect.';
    }

    if (sync.phase == BackgroundSyncPhase.failed) {
      final detail = sync.lastError;
      if (detail != null && detail.isNotEmpty) {
        return 'Sync failed: $detail';
      }
      return 'Sync failed. Will retry automatically.';
    }

    if (sync.phase == BackgroundSyncPhase.waitingForRetry) {
      final retryAt = sync.nextRetryAt;
      if (retryAt != null) {
        return 'Sync paused — retry ${_retryLabel(retryAt)}.';
      }
      return 'Sync paused — waiting to retry.';
    }

    if (sync.isActive) {
      return _phaseLabel(sync.phase);
    }

    if (pendingUploadCount > 0) {
      return '$pendingUploadCount ${_itemLabel(pendingUploadCount)} waiting to upload.';
    }

    return 'Sync up to date.';
  }

  static String headerSemanticsLabel({
    required BackgroundSyncState sync,
    required bool isOnline,
    required int pendingUploadCount,
  }) {
    if (!isOnline) {
      return pendingUploadCount > 0
          ? 'Offline, $pendingUploadCount pending uploads'
          : 'Offline';
    }
    if (sync.phase == BackgroundSyncPhase.failed) {
      return 'Sync failed';
    }
    if (sync.isActive) {
      return 'Syncing, ${_phaseLabel(sync.phase)}';
    }
    if (sync.phase == BackgroundSyncPhase.waitingForRetry) {
      return 'Sync waiting to retry';
    }
    if (pendingUploadCount > 0) {
      return '$pendingUploadCount pending uploads';
    }
    return 'Sync up to date';
  }

  static double? progressFraction(BackgroundSyncPhase phase) {
    return switch (phase) {
      BackgroundSyncPhase.attestation => 0.15,
      BackgroundSyncPhase.transcription => 0.30,
      BackgroundSyncPhase.proofAdmission => 0.45,
      BackgroundSyncPhase.reflectionEmbedding => 0.60,
      BackgroundSyncPhase.outboxDrain => 0.75,
      BackgroundSyncPhase.cloudSync => 0.90,
      BackgroundSyncPhase.sqliteVaultUpload => 0.95,
      BackgroundSyncPhase.completed => 1,
      _ => null,
    };
  }

  static String _phaseLabel(BackgroundSyncPhase phase) {
    return switch (phase) {
      BackgroundSyncPhase.attestation => 'Verifying captures…',
      BackgroundSyncPhase.transcription => 'Syncing transcripts…',
      BackgroundSyncPhase.proofAdmission => 'Processing proofs…',
      BackgroundSyncPhase.reflectionEmbedding => 'Indexing reflections…',
      BackgroundSyncPhase.outboxDrain => 'Uploading encrypted changes…',
      BackgroundSyncPhase.cloudSync => 'Syncing with cloud…',
      BackgroundSyncPhase.sqliteVaultUpload => 'Backing up encrypted vault…',
      BackgroundSyncPhase.completed => 'Sync complete.',
      _ => 'Syncing…',
    };
  }

  static String _itemLabel(int count) => count == 1 ? 'item' : 'items';

  static String _retryLabel(DateTime retryAt) {
    final remaining = retryAt.difference(DateTime.now().toUtc());
    if (remaining.isNegative) {
      return 'now';
    }
    if (remaining.inMinutes >= 1) {
      return 'in ${remaining.inMinutes} min';
    }
    if (remaining.inSeconds >= 1) {
      return 'in ${remaining.inSeconds} sec';
    }
    return 'soon';
  }
}
