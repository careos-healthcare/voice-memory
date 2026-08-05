import '../api/api_client.dart';
import '../api/api_exceptions.dart';
import '../config/app_config.dart';
import '../config/archive_me_demo_state.dart';
import '../config/creator_demo_mode.dart';
import '../models/journal_entry.dart';
import '../product/consumer_ui_copy.dart';
import '../storage/journal_store.dart';
import '../storage/mobile_prefs_store.dart';
import 'capture_save_messages.dart';
import 'journal_ownership_guard.dart';

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
  SyncService(
    this._api,
    this._journal,
    this._prefs, {
    JournalOwnershipGuard ownershipGuard = const JournalOwnershipGuard(),
  }) : _ownershipGuard = ownershipGuard;

  final ApiClient _api;
  final JournalStore _journal;
  final MobilePrefsStore _prefs;
  final JournalOwnershipGuard _ownershipGuard;

  /// Splits [pending] into entries safe to upload under the currently
  /// signed-in account and entries that must stay on-device because they
  /// belong to a different (or not-yet-reconciled) account. See
  /// [JournalOwnershipGuard] — P0 fix for cross-account archive leakage.
  Future<({List<JournalEntry> eligible, int blocked})> _partitionByOwnership(
    List<JournalEntry> pending,
  ) async {
    final currentOwnerKey =
        await _prefs.readString(JournalOwnershipGuard.ownerKeyPrefsKey) ?? '';
    final migrationPending =
        await _prefs.readBool(JournalOwnershipGuard.migrationPendingPrefsKey) ??
        false;
    final eligible = <JournalEntry>[];
    var blocked = 0;
    for (final entry in pending) {
      final ok = _ownershipGuard.isEligibleForSync(
        entryOwnerKey: entry.ownerKey,
        currentUserId: currentOwnerKey,
        migrationPending: migrationPending,
      );
      if (ok) {
        eligible.add(entry);
      } else {
        blocked++;
      }
    }
    return (eligible: eligible, blocked: blocked);
  }

  Future<SyncResult> syncNow() async {
    // Creator demo mode: nothing syncs — no backend call is ever made and
    // no demo content can reach an account.
    if (ArchiveMeDemoState.isActive || CreatorDemoMode.isActive) {
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
      final partitioned = await _partitionByOwnership(pending);
      final eligible = partitioned.eligible;
      final blocked = partitioned.blocked;
      if (eligible.isNotEmpty) {
        await _api.createJournalEntry(eligible);
        for (final e in eligible) {
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
        syncNote: blocked > 0
            ? '$blocked entr${blocked == 1 ? 'y' : 'ies'} from a different '
                  'account stayed private on this device and were not '
                  'uploaded.'
            : null,
        pushed: eligible.length,
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
