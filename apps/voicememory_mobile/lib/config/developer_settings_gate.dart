import 'package:flutter/foundation.dart';

import 'app_config.dart';

/// Gates developer settings and internal verification routes.
///
/// Visible when [AppConfig.isDebugBuild] is true, or after the user performs
/// seven taps on the app version in Settings → About.
class DeveloperSettingsGate {
  DeveloperSettingsGate._();

  static const int versionTapUnlockCount = 7;
  static const String prefsUnlockKey = 'developerSettingsUnlocked';

  static bool _unlockedViaGesture = false;
  static int _versionTapCount = 0;

  /// When true, hides debug-build developer UI in widget/golden tests.
  @visibleForTesting
  static bool suppressDebugBuildForTests = false;

  /// Loaded from prefs at startup — safe to read synchronously after [load].
  static bool get unlockedViaGesture => _unlockedViaGesture;

  /// When true, debug builds show developer settings without the version-tap unlock.
  static const bool exposeDeveloperSettingsInDebug = false;

  /// True when developer diagnostics and verification routes may open.
  static bool get isUnlocked => canShowDeveloperSettings;

  /// QA unlock via version taps only — hidden on consumer builds by default.
  static bool get canShowDeveloperSettings {
    if (suppressDebugBuildForTests) return _unlockedViaGesture;
    if (_unlockedViaGesture) return true;
    return AppConfig.isDebugBuild && exposeDeveloperSettingsInDebug;
  }

  /// Verification JSON, tokens, dart-defines — same gate as developer settings.
  static bool get canShowInternalVerificationDetails => canShowDeveloperSettings;

  static void applyLoadedUnlock(bool unlocked) {
    _unlockedViaGesture = unlocked;
  }

  /// Call after reading [MobilePrefsStore.readBool](prefsUnlockKey).
  static void loadFromPrefs(bool? unlocked) {
    _unlockedViaGesture = unlocked == true;
  }

  /// Registers one tap on the app version label. Returns true when unlock fires.
  static Future<bool> registerVersionTap({
    required Future<void> Function() persistUnlock,
  }) async {
    if (canShowDeveloperSettings) return false;
    _versionTapCount += 1;
    if (_versionTapCount < versionTapUnlockCount) return false;
    _versionTapCount = 0;
    _unlockedViaGesture = true;
    await persistUnlock();
    return true;
  }

  @visibleForTesting
  static void resetForTest() {
    _unlockedViaGesture = false;
    _versionTapCount = 0;
  }
}
