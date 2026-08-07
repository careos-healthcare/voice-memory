import '../../features/sync/application/sync_notifier.dart';

class SyncResult {
  const SyncResult({
    required this.cloudSyncSucceeded,
    required this.message,
    this.syncNote,
    required this.pushed,
    required this.pulled,
    this.rejected = 0,
  });

  final bool cloudSyncSucceeded;
  final String message;
  final String? syncNote;
  final int pushed;
  final int pulled;

  /// Count of outgoing entries the server refused this cycle (stale
  /// revisions and shape/validation errors alike) — see
  /// [SyncService.syncNow]. Always 0 for legacy short-circuit results
  /// (demo mode, backend not configured, auth required, etc.).
  final int rejected;

  /// Legacy alias — cloud sync only.
  bool get ok => cloudSyncSucceeded;
}

/// Facade over [SyncNotifier] — preserves the legacy [AppServices.sync] surface.
class SyncService {
  SyncService(this._notifier);

  final SyncNotifier _notifier;

  Future<SyncResult> syncNow() => _notifier.syncNow();

  Future<String> lastSyncLabel() => _notifier.lastSyncLabel();
}
