import '../api/api_client.dart';
import '../api/api_exceptions.dart';
import '../config/app_config.dart';
import '../config/creator_demo_mode.dart';
import '../product/consumer_ui_copy.dart';
import '../storage/journal_store.dart';
import '../storage/mobile_prefs_store.dart';
import 'capture_save_messages.dart';

class SyncResult {
  const SyncResult({
    required this.cloudSyncSucceeded,
    required this.message,
    this.syncNote,
    required this.pushed,
    required this.pulled,
  });

  final bool cloudSyncSucceeded;
  final String message;
  final String? syncNote;
  final int pushed;
  final int pulled;

  /// Legacy alias — cloud sync only.
  bool get ok => cloudSyncSucceeded;
}

class SyncService {
  SyncService(this._api, this._journal, this._prefs);

  final ApiClient _api;
  final JournalStore _journal;
  final MobilePrefsStore _prefs;

  Future<SyncResult> syncNow() async {
    // Creator demo mode: nothing syncs — no backend call is ever made and
    // no demo content can reach an account.
    if (CreatorDemoMode.isActive) {
      return const SyncResult(
        cloudSyncSucceeded: false,
        message: 'Your moments stay on this device.',
        pushed: 0,
        pulled: 0,
      );
    }
    if (!AppConfig.isBackendConfigured) {
      return const SyncResult(
        cloudSyncSucceeded: false,
        message: 'Your moments stay on this device.',
        syncNote: CaptureSaveMessages.syncNotAvailableTestFlight,
        pushed: 0,
        pulled: 0,
      );
    }
    try {
      final pending = await _journal.pendingSyncQueue();
      if (pending.isNotEmpty) {
        await _api.createJournalEntry(pending);
        for (final e in pending) {
          await _journal.markSynced(e.id);
        }
      }

      final remote = await _api.listJournal();
      await _journal.mergeRemote(remote);

      await _prefs.setLastSyncAt(DateTime.now());
      return SyncResult(
        cloudSyncSucceeded: true,
        message:
            'Sync complete. If anything looks duplicated, newer copies were kept.',
        pushed: pending.length,
        pulled: remote.length,
      );
    } on AuthRequiredException {
      return const SyncResult(
        cloudSyncSucceeded: false,
        message: 'Sign in to sync your archive to the server.',
        pushed: 0,
        pulled: 0,
      );
    } on BackendNotConfiguredException {
      return const SyncResult(
        cloudSyncSucceeded: false,
        message: 'Your moments stay on this device.',
        syncNote: CaptureSaveMessages.syncNotAvailableTestFlight,
        pushed: 0,
        pulled: 0,
      );
    } catch (e) {
      return SyncResult(
        cloudSyncSucceeded: false,
        message: 'Sync did not complete.',
        syncNote: CaptureSaveMessages.syncNoteFor(e),
        pushed: 0,
        pulled: 0,
      );
    }
  }

  Future<String> lastSyncLabel() async {
    if (!AppConfig.isBackendConfigured) {
      return ConsumerUiCopy.syncNotAvailableTestFlight;
    }
    final raw = await _prefs.lastSyncAt;
    if (raw == null) return ConsumerUiCopy.syncOnDeviceOnly;
    final at = DateTime.tryParse(raw);
    if (at == null) return ConsumerUiCopy.syncOnDeviceOnly;
    return 'Last sync ${at.toLocal()}';
  }
}
