import 'package:meta/meta.dart';

/// Compile-time gate for the Apple Watch quick-record companion.
///
/// **Status: deliberate scaffolding — not V1-shipped (default off).**
///
/// What exists:
/// - watchOS record UI: `ios/WatchApp/QuickRecordView.swift`
/// - WCSession send: `ios/WatchApp/WatchConnectivityManager.swift`
/// - iPhone inbox + method channel: `ios/Runner/WatchSessionBridge.swift`,
///   `archive_me/watch_session` in `AppDelegate.swift`
/// - Dart bridge: `lib/features/watch_companion/watch_connectivity_service.dart`
///
/// To resume local development:
/// 1. Complete the Xcode Watch target steps in `docs/WATCHOS_SETUP.md`
/// 2. Run with `--dart-define=VOICEMEMORY_ENABLE_WATCH_COMPANION=true`
/// 3. Confirm `WatchConnectivityService.connect()` receives `watchAudioReceived`
///
/// Dart code intentionally uses `WatchSession*` / `WatchConnectivityService`
/// naming — not `WatchConnectivity` (that API is Swift-only on watchOS).
abstract final class WatchCompanionFeatureFlags {
  WatchCompanionFeatureFlags._();

  static const bool _compileTimeDefault = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_WATCH_COMPANION',
  );

  /// Test-only override — never set in production code.
  @visibleForTesting
  static bool? debugOverride;

  static bool get enableWatchCompanion =>
      debugOverride ?? _compileTimeDefault;
}