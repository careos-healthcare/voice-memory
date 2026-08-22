import 'dart:async';

import 'package:archiveme_mobile/features/watch/watch_audio_capture.dart';
import 'package:flutter/services.dart';

/// Receives watch-recorded audio payloads forwarded by iOS WCSession
/// (watchOS [WatchConnectivityManager] → Runner [WatchSessionBridge]).
class WatchSessionBridge {
  WatchSessionBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('archive_me/watch_session');

  final MethodChannel _channel;
  final StreamController<WatchAudioCapture> _capturesController =
      StreamController<WatchAudioCapture>.broadcast();

  Stream<WatchAudioCapture> get captures => _capturesController.stream;

  Future<void> initialize() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'watchAudioReceived') return;
      final capture = WatchAudioCapture.fromPlatform(call.arguments);
      if (capture != null) {
        _capturesController.add(capture);
      }
    });
    final pending = await consumePendingWatchAudio();
    for (final capture in pending) {
      _capturesController.add(capture);
    }
  }

  Future<bool> isSupported() async {
    try {
      final supported = await _channel.invokeMethod<bool>(
        'isWatchSessionSupported',
      );
      return supported ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<List<WatchAudioCapture>> consumePendingWatchAudio() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'consumePendingWatchAudio',
      );
      if (result == null) return const [];
      return result
          .map(WatchAudioCapture.fromPlatform)
          .whereType<WatchAudioCapture>()
          .toList(growable: false);
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  @Deprecated('Use consumePendingWatchAudio')
  Future<List<String>> consumePendingWatchAudioPaths() async {
    final captures = await consumePendingWatchAudio();
    return captures.map((capture) => capture.path).toList(growable: false);
  }

  void dispose() {
    unawaited(_capturesController.close());
  }
}