// Named parameters cannot expose private field names.
// ignore_for_file: prefer_initializing_formals

import '../../features/offline_sync/offline_sync_journey_store.dart';
import '../../features/journal/sync/saved_moment_sync_key_store.dart';
import '../../features/archive_ownership/local_archive_identity.dart';
import '../sync_service.dart';
import 'account_services.dart';
import 'archive_services.dart';
import 'core_services.dart';
import 'v1_composition_config.dart';

/// Journal sync, built lazily.
///
/// Capture is local-first: nothing on the path to a saved moment reads sync, so
/// the service is constructed on first use or on post-first-frame activation,
/// whichever comes first.
final class SyncServices {
  SyncServices._({
    required SyncService Function() buildSync,
    required OfflineSyncJourneyStore Function() buildOfflineSyncJourney,
  }) : _buildSync = buildSync,
       _buildOfflineSyncJourney = buildOfflineSyncJourney;

  final SyncService Function() _buildSync;
  final OfflineSyncJourneyStore Function() _buildOfflineSyncJourney;

  SyncService? _sync;
  OfflineSyncJourneyStore? _offlineSyncJourney;
  bool _pausedBeforeConstruction = false;
  int _accountGeneration = 0;

  int get accountGeneration => _accountGeneration;

  /// True once the sync service object exists.
  bool get isInitialized => _sync != null;

  SyncService get sync {
    final existing = _sync;
    if (existing != null) return existing;
    final created = _buildSync();
    if (_pausedBeforeConstruction) created.pauseForAccountTransition();
    _sync = created;
    return created;
  }

  OfflineSyncJourneyStore get offlineSyncJourney =>
      _offlineSyncJourney ??= _buildOfflineSyncJourney();

  static SyncServices create(
    CoreServices core,
    AccountServices account,
    ArchiveServices archive,
    V1CompositionConfig config,
  ) => SyncServices._(
    buildSync: () => SyncService(
      core.journalSyncApi,
      archive.journalStore,
      core.prefs,
      deviceIdProvider: config.testMode
          ? () async => 'test-device'
          : core.deviceIds.getOrCreate,
      archiveIdentityProvider: () => account.activeArchiveIdentity,
      journalProvider: () => archive.journalStore,
      keyProvider: SavedMomentSyncKeyStore(core.secureStorage).requireKey,
    ),
    buildOfflineSyncJourney: () => OfflineSyncJourneyStore(core.prefs),
  );

  /// Builds the sync objects. Called after the first frame.
  Future<void> activate() async {
    sync;
    offlineSyncJourney;
  }

  void pauseForAccountTransition() {
    final existing = _sync;
    if (existing == null) {
      // Remembered so a later first use cannot start unpaused mid-transition.
      _pausedBeforeConstruction = true;
      return;
    }
    existing.pauseForAccountTransition();
  }

  Future<void> activateAccountScope(LocalArchiveIdentity identity) async {
    _accountGeneration += 1;
    _pausedBeforeConstruction = false;
    _sync?.resumeAfterAccountTransition();
  }
}
