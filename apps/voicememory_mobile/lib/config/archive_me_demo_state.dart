import 'package:flutter/foundation.dart';

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

  /// True when screenshot demo define is set.
  static bool get enabledCompileTime => ScreenshotMode.archiveMeDemoPreview;

  @visibleForTesting
  static bool debugForceEnabledForTest = false;

  /// Debug-only in-memory toggle — never persisted, easy to reset.
  static bool _debugSessionEnabled = false;

  static bool get debugSessionEnabled => kDebugMode && _debugSessionEnabled;

  static bool get isActive =>
      enabledCompileTime || debugForceEnabledForTest || debugSessionEnabled;

  /// Turn demo on/off in debug builds without recompiling.
  static void setDebugSessionEnabled(bool enabled) {
    if (!kDebugMode || kReleaseMode) return;
    _debugSessionEnabled = enabled;
  }

  /// Clears the debug session flag — compile-time demo requires app restart.
  static void resetDebugSession() {
    _debugSessionEnabled = false;
  }

  @visibleForTesting
  static void resetForTest() {
    debugForceEnabledForTest = false;
    _debugSessionEnabled = false;
  }
}
