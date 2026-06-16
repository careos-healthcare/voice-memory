import '../services/capture_attest_service.dart';
import '../services/sync_service.dart';
import '../storage/mobile_prefs_store.dart';

/// Guest-first local mode — record via device attest without email at launch.
class GuestFirstAuth {
  GuestFirstAuth(this._prefs, {CaptureAttestService? attest, SyncService? sync})
    : _attest = attest,
      _sync = sync;

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
    } catch (_) {}
  }
}
