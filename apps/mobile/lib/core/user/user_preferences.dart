import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Device setting for optional cloud features.
///
/// Off is the default. Import and pattern exploration stay on this device
/// until the person turns cloud sync on.
class UserPreferences {
  const UserPreferences({this.isCloudSyncEnabled = false});

  static const cloudSyncPreferenceKey = 'cloud_sync_enabled';

  /// Test stand-in for the saved preference. Production reads [load].
  static bool? debugCloudSyncOverride;

  final bool isCloudSyncEnabled;

  static Future<UserPreferences> load(MobilePrefsStore prefs) async {
    final override = debugCloudSyncOverride;
    if (override != null) {
      return UserPreferences(isCloudSyncEnabled: override);
    }
    final enabled = await prefs.readBool(cloudSyncPreferenceKey) ?? false;
    return UserPreferences(isCloudSyncEnabled: enabled);
  }

  static Future<void> setCloudSyncEnabled(
    MobilePrefsStore prefs,
    bool enabled,
  ) async {
    await prefs.writeBool(cloudSyncPreferenceKey, enabled);
  }
}
