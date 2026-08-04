import 'dart:convert';

import '../../../models/journal_entry.dart';

enum SyncConflictWinner { local, remote }

class SyncConflictResolution {
  const SyncConflictResolution._();

  static SyncConflictWinner winner({
    required JournalEntry local,
    required JournalEntry remote,
  }) {
    if (local.id != remote.id) {
      throw ArgumentError('LWW comparison requires matching entry ids.');
    }
    final localUpdatedAt = updatedAt(local);
    final remoteUpdatedAt = updatedAt(remote);
    final timestampOrder = localUpdatedAt.compareTo(remoteUpdatedAt);
    if (timestampOrder != 0) {
      return timestampOrder > 0
          ? SyncConflictWinner.local
          : SyncConflictWinner.remote;
    }

    // Stable tie-breakers ensure both peers converge when timestamps match.
    final deviceOrder = _sourceDeviceId(
      local,
    ).compareTo(_sourceDeviceId(remote));
    if (deviceOrder != 0) {
      return deviceOrder > 0
          ? SyncConflictWinner.local
          : SyncConflictWinner.remote;
    }
    final localJson = jsonEncode(local.toJson(includeLocalContext: false));
    final remoteJson = jsonEncode(remote.toJson(includeLocalContext: false));
    return localJson.compareTo(remoteJson) >= 0
        ? SyncConflictWinner.local
        : SyncConflictWinner.remote;
  }

  static JournalEntry resolve({
    required JournalEntry local,
    required JournalEntry remote,
  }) {
    if (winner(local: local, remote: remote) == SyncConflictWinner.local) {
      return local;
    }
    return preserveLocalOnlyData(remote: remote, local: local);
  }

  static DateTime updatedAt(JournalEntry entry) =>
      (entry.syncMetadata?.updatedAt ?? entry.createdAt).toUtc();

  static JournalEntry preserveLocalOnlyData({
    required JournalEntry remote,
    required JournalEntry local,
  }) {
    return JournalEntry(
      id: remote.id,
      createdAt: remote.createdAt,
      transcript: remote.transcript,
      durationSeconds: remote.durationSeconds,
      reflection: remote.reflection,
      syncStatus: remote.syncStatus,
      localAudioPath: local.localAudioPath ?? remote.localAudioPath,
      localAudioVaultRef: local.localAudioVaultRef ?? remote.localAudioVaultRef,
      treatAsNew: remote.treatAsNew,
      connectionApproved: remote.connectionApproved,
      keepExactDetails: remote.keepExactDetails,
      keepSeparate: remote.keepSeparate,
      archiveThreadId: remote.archiveThreadId,
      archivePackId: remote.archivePackId,
      isPinned: remote.isPinned,
      pinnedAt: remote.pinnedAt,
      isArchived: remote.isArchived,
      archivedAt: remote.archivedAt,
      entryAboutness: remote.entryAboutness,
      memorySurfacing: remote.memorySurfacing,
      preserveOriginal: remote.preserveOriginal,
      captureContextTag: local.captureContextTag ?? remote.captureContextTag,
      localCaptureContext:
          local.localCaptureContext ?? remote.localCaptureContext,
      biomarkers: remote.biomarkers,
      parentHookId: remote.parentHookId,
      wasGrounded: remote.wasGrounded,
      syncMetadata: remote.syncMetadata,
      mediaAttachments: local.mediaAttachments.isNotEmpty
          ? local.mediaAttachments
          : remote.mediaAttachments,
    );
  }

  static String _sourceDeviceId(JournalEntry entry) =>
      entry.syncMetadata?.sourceDeviceId.trim() ?? '';
}
