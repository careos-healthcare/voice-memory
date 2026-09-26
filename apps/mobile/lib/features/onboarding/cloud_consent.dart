import 'package:archiveme_mobile/core/user/user_preferences.dart';
import 'package:archiveme_mobile/features/sync/services/cloud_sync_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Whether journal text may be stored on Thoughtprint's servers.
class CloudConsent {
  CloudConsent({CloudSyncService? sync}) : _sync = sync ?? CloudSyncService();

  final CloudSyncService _sync;

  Future<bool> isEnabled() async {
    final override = UserPreferences.debugCloudSyncOverride;
    if (override != null) return override;
    if (!AppServices.isInitialized) return false;
    final preferences = await UserPreferences.load(AppServices.instance.prefs);
    return preferences.isCloudSyncEnabled;
  }

  /// Turns cloud memory on.
  ///
  /// [onProgress] reports how many entries have been accepted so far.
  /// A failed chunk stops the job; the next [enable] resumes after it.
  /// The backfill posts to the plain-text ledger when ledger opt-in and the
  /// plain-text AI processing consent are already in place.
  Future<void> enable({
    void Function(int done, int total)? onProgress,
  }) async {
    if (!AppServices.isInitialized) return;
    await UserPreferences.setCloudSyncEnabled(
      AppServices.instance.prefs,
      true,
    );
    await _sync.backfillInChunks(onProgress: onProgress);
  }

  Future<void> disable() async {
    if (!AppServices.isInitialized) return;
    await UserPreferences.setCloudSyncEnabled(
      AppServices.instance.prefs,
      false,
    );
  }
}
