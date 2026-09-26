import 'package:archiveme_mobile/core/user/user_preferences.dart';
import 'package:archiveme_mobile/features/settings/e2ee_sync_settings.dart';
import 'package:archiveme_mobile/features/sync/services/cloud_sync_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Turns encrypted sync off after the server confirms the copy is gone.
class SyncManagementService {
  const SyncManagementService();

  static const purgePath = '/api/sync/purge';

  /// Sends `DELETE /api/sync/purge` with the session token.
  ///
  /// Local sync stays on until the response is exactly 200.
  Future<bool> turnOffSyncAndDeleteServerCopy({
    Future<int?> Function()? sendPurge,
    Future<void> Function()? onPurged,
  }) async {
    final status = sendPurge != null ? await sendPurge() : await _authorizedDelete();
    if (status != 200) return false;
    if (onPurged != null) {
      await onPurged();
      return true;
    }
    await _clearLocalSyncState();
    return true;
  }

  Future<int?> _authorizedDelete() async {
    if (!AppServices.isInitialized) return null;
    final cookie = AppServices.instance.sessionCookieSource.current;
    final token = bearerFromSessionCookie(cookie);
    final result = await AppServices.instance.httpTransport.delete(
      purgePath,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    return result.valueOrNull?.statusCode;
  }

  Future<void> _clearLocalSyncState() async {
    if (!AppServices.isInitialized) return;
    final prefs = AppServices.instance.prefs;
    await UserPreferences.setCloudSyncEnabled(prefs, false);
    await prefs.writeBool(E2eeSyncSettings.preferenceKey, false);
    await prefs.setLastSyncSequence(null);
    await prefs.remove('lastSyncAt');
    await prefs.remove(E2eeSyncLifecycle.lastSyncKey);
  }
}

/// Reads the session token from a `vm_session` cookie value.
String? bearerFromSessionCookie(String? cookie) {
  if (cookie == null) return null;
  final first = cookie.split(';').first.trim();
  if (first.isEmpty) return null;
  final eq = first.indexOf('=');
  if (eq <= 0) return first;
  final value = first.substring(eq + 1).trim();
  if (value.isEmpty) return null;
  return value;
}
