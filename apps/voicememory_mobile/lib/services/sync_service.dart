import '../api/api_client.dart';
import '../api/api_exceptions.dart';
import '../config/app_config.dart';
import '../config/archive_me_demo_state.dart';
import '../config/creator_demo_mode.dart';
import '../features/encrypted_sync/encrypted_journal_sync_coordinator.dart';
import '../features/encrypted_sync/sync_master_key_store.dart';
import '../models/journal_entry.dart';
import '../product/consumer_ui_copy.dart';
import '../storage/device_id.dart';
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

class SyncService {
  SyncService(
    this._api,
    this._journal,
    this._prefs, {
    this._ownershipGuard = const JournalOwnershipGuard(),
    EncryptedJournalSyncCoordinator? encryptedCoordinator,
    DeviceIdStore? deviceIds,
    SyncMasterKeyStore? keyStore,
  }) : _encryptedCoordinator =
           encryptedCoordinator ??
           EncryptedJournalSyncCoordinator(
             api: _api,
             journal: _journal,
             prefs: _prefs,
             deviceIds: deviceIds ?? DeviceIdStore(),
             keyStore:
                 keyStore ??
                 SecureSyncMasterKeyStore(accountNamespace: 'guest'),
           );

  final ApiClient _api;
  final JournalStore _journal;
  final MobilePrefsStore _prefs;
  final JournalOwnershipGuard _ownershipGuard;
  final EncryptedJournalSyncCoordinator _encryptedCoordinator;

  /// Mirrors the server's `JOURNAL_SYNC_BATCH_LIMIT` (`POST /api/journal`
  /// rejects a larger `entries` array with `400 BATCH_TOO_LARGE`) — defined
  /// once here so a backlog built up over a long offline period is always
  /// chunked before upload instead of failing outright.
  static const int _batchLimit = 200;

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

  List<List<JournalEntry>> _chunk(List<JournalEntry> entries, int size) {
    final batches = <List<JournalEntry>>[];
    for (var i = 0; i < entries.length; i += size) {
      final end = (i + size < entries.length) ? i + size : entries.length;
      batches.add(entries.sublist(i, end));
    }
    return batches;
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
    // Tracked outside the try block so a mid-batch failure still reports
    // exactly how much of the outgoing set actually made it to the server
    // before the failure — those entries were already marked synced as
    // each batch's response came back, so a retry never re-sends them.
    var pushed = 0;
    var rejected = 0;
    try {
      final encrypted = await _encryptedCoordinator.syncNow();
      pushed = encrypted.pushed;
      return SyncResult(
        cloudSyncSucceeded: true,
        message:
            'Sync complete. If anything looks duplicated, newer copies were kept.',
        syncNote: encrypted.blocked > 0
            ? '${encrypted.blocked} entr${encrypted.blocked == 1 ? 'y' : 'ies'} from a different '
                  'account stayed private on this device and were not '
                  'uploaded.'
            : encrypted.migratedLegacy
            ? 'Legacy plaintext archive was encrypted on this device. Server plaintext rows remain until audited deletion.'
            : null,
        pushed: pushed,
        pulled: encrypted.pulled,
        rejected: rejected,
      );
    } on AuthRequiredException {
      return SyncResult(
        cloudSyncSucceeded: false,
        message: 'Sign in to sync your archive to the server.',
        pushed: pushed,
        pulled: 0,
        rejected: rejected,
      );
    } on BackendNotConfiguredException {
      return SyncResult(
        cloudSyncSucceeded: false,
        message: 'Your moments stay on this device.',
        syncNote: CaptureSaveMessages.syncNotAvailableTestFlight,
        pushed: pushed,
        pulled: 0,
        rejected: rejected,
      );
    } catch (e) {
      return SyncResult(
        cloudSyncSucceeded: false,
        message: 'Sync did not complete.',
        syncNote: CaptureSaveMessages.syncNoteFor(e),
        pushed: pushed,
        pulled: 0,
        rejected: rejected,
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
