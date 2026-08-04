import 'package:flutter/foundation.dart';

import '../storage/mobile_prefs_store.dart';
import 'app_feature_flags.dart';
import 'screenshot_mode.dart';

/// Clean ArchiveMe demo archive for screenshots and short videos.
///
/// Compile-time (recommended):
/// ```bash
/// flutter run --dart-define=VOICE_MEMORY_SCREENSHOT_MODE=true \
///   --dart-define=VOICE_MEMORY_SCREENSHOT_DEMO=confirmed_repeat
/// ```
///
/// Debug session toggle: enable from Developer diagnostics (debug builds only).
/// Restart the app or tap Reset demo to return to a real local archive.
abstract class ArchiveMeDemoState {
  ArchiveMeDemoState._();

  static const entryIdPrefix = 'archive_me_demo_';
  static const reviewDemoPrefsKey = 'archiveAppReviewDemoUnlocked';

  /// True when screenshot demo define is set.
  static bool get enabledCompileTime => ScreenshotMode.archiveMeDemoPreview;

  @visibleForTesting
  static bool get debugForceEnabledForTest =>
      AppFeatureFlags.testOverrides.archiveMeDemoEnabled;

  @visibleForTesting
  static set debugForceEnabledForTest(bool enabled) {
    AppFeatureFlags.testOverrides.archiveMeDemoEnabled = enabled;
  }

  /// Debug-only in-memory toggle — never persisted, easy to reset.
  static bool _debugSessionEnabled = false;

  /// Persisted when App Review code unlock succeeds.
  static bool _reviewDemoUnlocked = false;

  static bool get debugSessionEnabled => kDebugMode && _debugSessionEnabled;

  static bool get reviewDemoUnlocked => _reviewDemoUnlocked;

  static bool get isActive =>
      enabledCompileTime ||
      debugForceEnabledForTest ||
      debugSessionEnabled ||
      _reviewDemoUnlocked;

  /// Restores review-demo flag from prefs after app restart.
  static Future<void> hydrateFromPrefs(MobilePrefsStore prefs) async {
    _reviewDemoUnlocked = await prefs.readBool(reviewDemoPrefsKey) ?? false;
  }

  /// Enables the in-memory sample archive used by App Review unlock.
  static Future<void> enableReviewDemo(MobilePrefsStore prefs) async {
    _reviewDemoUnlocked = true;
    await prefs.writeBool(reviewDemoPrefsKey, true);
  }

  /// Turn demo on/off in debug builds without recompiling.
  static void setDebugSessionEnabled(bool enabled) {
    if (!kDebugMode || kReleaseMode) return;
    _debugSessionEnabled = enabled;
  }

  /// Clears the debug session flag — compile-time demo requires app restart.
  static void resetDebugSession() {
    _debugSessionEnabled = false;
  }

  static void clearSessionState() {
    debugForceEnabledForTest = false;
    _debugSessionEnabled = false;
    _reviewDemoUnlocked = false;
  }

  @visibleForTesting
  static void resetForTest() => clearSessionState();
}
