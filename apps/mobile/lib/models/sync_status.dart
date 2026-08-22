enum SyncStatus { localOnly, pendingUpload, synced, conflict, error }

extension SyncStatusLabel on SyncStatus {
  String get label {
    switch (this) {
      case SyncStatus.localOnly:
        return 'On device only';
      case SyncStatus.pendingUpload:
        return 'Waiting to sync';
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.conflict:
        return 'Needs review';
      case SyncStatus.error:
        return 'Sync error';
    }
  }
}