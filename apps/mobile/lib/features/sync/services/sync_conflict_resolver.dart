/// Last-write-wins on `updated_at`. A tie keeps the copy already on the device.
enum SyncConflictAction { keepLocal, keepRemote }

abstract final class SyncConflictResolver {
  SyncConflictResolver._();

  static SyncConflictAction resolve({
    required DateTime? localUpdatedAt,
    required DateTime? remoteUpdatedAt,
  }) {
    if (remoteUpdatedAt != null &&
        (localUpdatedAt == null || remoteUpdatedAt.isAfter(localUpdatedAt))) {
      return SyncConflictAction.keepRemote;
    }
    return SyncConflictAction.keepLocal;
  }
}
