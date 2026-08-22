import 'dart:async';

import 'package:archiveme_mobile/core/config/watch_companion_feature_flags.dart';
import 'package:archiveme_mobile/features/watch/watch_audio_capture.dart';
import 'package:archiveme_mobile/features/watch/watch_session_bridge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart-side bridge for the Apple Watch quick-record companion.
///
/// Watch-side recording is initiated in watchOS (`QuickRecordView` →
/// `WatchConnectivityManager.transferFile`). The iPhone Runner receives files
/// via `WatchSessionBridge` and forwards payloads on method channel
/// [channelName] (`watchAudioReceived` events + `consumePendingWatchAudio`).
///
/// Gated by [WatchCompanionFeatureFlags.enableWatchCompanion] (default off).
/// See `docs/WATCHOS_SETUP.md` for the full WCSession chain.
class WatchConnectivityService {
  WatchConnectivityService({WatchSessionBridge? bridge})
    : _bridge =
          bridge ??
          WatchSessionBridge(
            channel: const MethodChannel(channelName),
          );

  /// Must match `watchChannelName` in `ios/Runner/AppDelegate.swift`.
  static const String channelName = 'archive_me/watch_session';

  final WatchSessionBridge _bridge;
  StreamSubscription<WatchAudioCapture>? _captureSubscription;
  var _connected = false;

  /// When true, [connect] runs on non-iOS platforms (unit tests only).
  @visibleForTesting
  bool forceConnectForTests = false;

  bool get isEnabled => WatchCompanionFeatureFlags.enableWatchCompanion;

  /// Emits each watch recording after the native inbox forwards it to Flutter.
  Stream<WatchAudioCapture> get captures => _bridge.captures;

  /// Registers the platform handler and drains any pending inbox captures.
  ///
  /// No-ops when the feature flag is off or the platform is not iOS.
  Future<void> connect({
    void Function(WatchAudioCapture capture)? onCapture,
  }) async {
    if (!isEnabled) return;
    if (!forceConnectForTests &&
        (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    if (_connected) return;

    await _bridge.initialize();
    _connected = true;

    if (onCapture != null) {
      await _captureSubscription?.cancel();
      _captureSubscription = _bridge.captures.listen(onCapture);
    }
  }

  Future<bool> isSupported() async {
    if (!isEnabled) return false;
    return _bridge.isSupported();
  }

  Future<List<WatchAudioCapture>> consumePendingCaptures() async {
    if (!isEnabled) return const [];
    return _bridge.consumePendingWatchAudio();
  }

  @visibleForTesting
  WatchSessionBridge get bridgeForTest => _bridge;

  void dispose() {
    unawaited(_captureSubscription?.cancel());
    _captureSubscription = null;
    _connected = false;
    _bridge.dispose();
  }
}