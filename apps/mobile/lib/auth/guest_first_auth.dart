import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/services/capture_attest_service.dart';
import 'package:archiveme_mobile/services/sync_service.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Guest-first local mode — record via device attest without email at launch.
class GuestFirstAuth {
  GuestFirstAuth(this._prefs, {this._attest, this._sync});

  final MobilePrefsStore _prefs;
  final CaptureAttestService? _attest;
  final SyncService? _sync;

  static const guestModeStartedKey = 'guest_mode_started';
  static const protectBannerDismissedKey = 'protect_archive_banner_dismissed';

  Future<void> markGuestModeStartedIfNeeded({required bool isSignedIn}) async {
    if (isSignedIn) return;
    if (await _prefs.readBool(guestModeStartedKey) == true) return;
    await _prefs.writeBool(guestModeStartedKey, true);
  }

  Future<bool> shouldShowProtectBanner({
    required bool isSignedIn,
    required bool hasLocalArchive,
  }) async {
    if (isSignedIn || !hasLocalArchive) return false;
    return await _prefs.readBool(protectBannerDismissedKey) != true;
  }

  Future<void> dismissProtectBanner() async {
    await _prefs.writeBool(protectBannerDismissedKey, true);
  }

  Future<void> registerDeviceAfterSignIn() async {
    final attest = _attest;
    final sync = _sync;
    if (attest == null || sync == null) return;
    attest.clearToken();
    await attest.ensureCaptureToken(forceRefresh: true);
    try {
      await sync.syncNow();
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      }
  }
}