import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Device setting for optional cloud features.
///
/// Off is the default. Import and pattern exploration stay on this device
/// until the person turns cloud sync on.
class UserPreferences {
  const UserPreferences({
    this.isCloudSyncEnabled = false,
    this.isHealthMoodSyncEnabled = false,
    this.isHealthMoodWriteEnabled = false,
  });

  static const cloudSyncPreferenceKey = 'cloud_sync_enabled';
  static const healthMoodSyncPreferenceKey = 'health_mood_sync_enabled';
  static const healthMoodWritePreferenceKey = 'health_mood_write_enabled';

  /// Test stand-in for the saved preference. Production reads [load].
  static bool? debugCloudSyncOverride;

  final bool isCloudSyncEnabled;
  final bool isHealthMoodSyncEnabled;
  final bool isHealthMoodWriteEnabled;

  static Future<UserPreferences> load(MobilePrefsStore prefs) async {
    final override = debugCloudSyncOverride;
    final storedCloud = await prefs.readBool(cloudSyncPreferenceKey);
    final cloud = override ?? storedCloud ?? false;
    final health = await prefs.readBool(healthMoodSyncPreferenceKey) ?? false;
    final write = await prefs.readBool(healthMoodWritePreferenceKey) ?? false;
    return UserPreferences(
      isCloudSyncEnabled: cloud,
      isHealthMoodSyncEnabled: health,
      isHealthMoodWriteEnabled: write,
    );
  }

  static Future<void> setCloudSyncEnabled(
    MobilePrefsStore prefs,
    bool enabled,
  ) async {
    await prefs.writeBool(cloudSyncPreferenceKey, enabled);
  }

  static Future<void> setHealthMoodSyncEnabled(
    MobilePrefsStore prefs,
    bool enabled,
  ) async {
    await prefs.writeBool(healthMoodSyncPreferenceKey, enabled);
  }

  static Future<void> setHealthMoodWriteEnabled(
    MobilePrefsStore prefs,
    bool enabled,
  ) async {
    await prefs.writeBool(healthMoodWritePreferenceKey, enabled);
  }
}
