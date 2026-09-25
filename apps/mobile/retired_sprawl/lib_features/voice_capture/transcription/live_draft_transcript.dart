import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Partial on-device recognition while a recording is in progress.
///
/// Partials are for the recording screen only. Callers must not store them
/// or stamp them as speech-to-text provenance. Android has no
/// on-device streaming recogniser here, so [supportsOnDeviceStreaming] is
/// false and the draft area stays hidden.
abstract final class LiveDraftTranscript {
  static const channelName = 'archive_me/native_speech_transcription';
  static const eventChannelName =
      'archive_me/native_speech_transcription_draft';

  static const MethodChannel _channel = MethodChannel(channelName);
  static const EventChannel _events = EventChannel(eventChannelName);

  static bool get supportsOnDeviceStreaming {
    if (kIsWeb) return false;
    return Platform.isIOS;
  }

  static Stream<String> partials() {
    if (!supportsOnDeviceStreaming) return const Stream.empty();
    return _events.receiveBroadcastStream().map((event) {
      if (event is String) return event;
      if (event is Map && event['transcript'] is String) {
        return event['transcript'] as String;
      }
      return '';
    });
  }

  static Future<void> start({ConfirmedSpeechLocale? locale}) async {
    if (!supportsOnDeviceStreaming) return;
    await _channel.invokeMethod<void>('startLiveDraft', {
      if (locale != null) 'localeIdentifier': locale.identifier,
    });
  }

  static Future<void> stop() async {
    if (!supportsOnDeviceStreaming) return;
    try {
      await _channel.invokeMethod<void>('stopLiveDraft');
    } on PlatformException {
      // Stopping a draft that never started is not a capture failure.
    }
  }
}
