import '../api/api_client.dart';
import '../api/api_exceptions.dart';
import '../config/app_config.dart';
import '../models/sync_status.dart';

class SyncSnapshot {
  const SyncSnapshot({
    required this.status,
    required this.message,
    required this.lastCheckedAt,
  });

  final SyncStatus status;
  final String message;
  final DateTime lastCheckedAt;
}

/// Sync status — read-only probe; push/pull APIs not wired in Flutter yet.
class SyncService {
  SyncService(this._api);

  final ApiClient _api;

  Future<SyncSnapshot> checkStatus() async {
    try {
      await _api.health();
      try {
        await _api.listJournal();
        return SyncSnapshot(
          status: SyncStatus.synced,
          message: 'Server reachable; journal API responded (auth may be required).',
          lastCheckedAt: DateTime.now(),
        );
      } on AuthRequiredException {
        return SyncSnapshot(
          status: SyncStatus.pendingUpload,
          message: 'Server reachable — sign in on web to sync journal.',
          lastCheckedAt: DateTime.now(),
        );
      }
    } catch (e) {
      return SyncSnapshot(
        status: SyncStatus.error,
        message: 'Cannot reach API at ${AppConfig.apiBaseUrl}: $e',
        lastCheckedAt: DateTime.now(),
      );
    }
  }
}
