import 'dart:async';

import 'package:archiveme_mobile/features/watch/watch_audio_capture.dart';
import 'package:flutter/services.dart';

/// Listens for watch recordings that iOS copied into the shared app group.
class WatchSyncService {
  WatchSyncService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.archiveme/watch_sync';
  static const readyMethod = 'watchRecordingReady';
  static const consumePendingMethod = 'consumePendingWatchRecording';

  final MethodChannel _channel;
  var _bound = false;

  Future<void> bind({
    required void Function(WatchAudioCapture capture) onReady,
  }) async {
    if (_bound) return;
    _bound = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != readyMethod) return;
      final capture = WatchAudioCapture.fromPlatform(call.arguments);
      if (capture != null) onReady(capture);
    });
    try {
      final pending = await _channel.invokeMethod<List<dynamic>>(
        consumePendingMethod,
      );
      for (final raw in pending ?? const <dynamic>[]) {
        final capture = WatchAudioCapture.fromPlatform(raw);
        if (capture != null) onReady(capture);
      }
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _bound = false;
  }
}
