import 'dart:async';
import 'dart:io';

import '../api/api_exceptions.dart';
import '../services/capture_attest_service.dart';
import '../services/sync_service.dart';
import '../services/sync_diagnostic_log.dart';
import '../storage/mobile_prefs_store.dart';

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
    } on NetworkOfflineException catch (error, stackTrace) {
      _logSyncFailure('transient_network', error, stackTrace);
    } on AuthRequiredException catch (error, stackTrace) {
      _logSyncFailure('authentication', error, stackTrace);
    } on ApiException catch (error, stackTrace) {
      _logSyncFailure(_apiFailureType(error), error, stackTrace);
    } on SocketException catch (error, stackTrace) {
      _logSyncFailure('transient_network', error, stackTrace);
    } on TimeoutException catch (error, stackTrace) {
      _logSyncFailure('transient_network', error, stackTrace);
    } on Object catch (error, stackTrace) {
      _logSyncFailure('unexpected', error, stackTrace);
    }
  }

  static String _apiFailureType(ApiException error) {
    if (error.statusCode == 401 || error.code == 'AUTH_REQUIRED') {
      return 'authentication';
    }
    final status = error.statusCode ?? 0;
    if (status == 408 || status == 429 || status >= 500) {
      return 'transient_api';
    }
    return 'permanent_api';
  }

  static void _logSyncFailure(
    String failureType,
    Object error,
    StackTrace stackTrace,
  ) {
    SyncDiagnosticLog.failed(
      operation: 'register_device_after_sign_in',
      failureType: failureType,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
