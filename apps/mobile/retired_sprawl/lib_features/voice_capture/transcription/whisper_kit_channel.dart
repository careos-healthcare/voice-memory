import 'package:flutter/services.dart';

/// iOS platform channel for an on-device Whisper runtime.
///
/// The native side answers hardware and model questions. Transcription returns
/// text when the linked engine can read the file, and a platform error when it
/// cannot, so the Dart router can keep the recording on the device or hand it
/// to the existing cloud transcription call.
class WhisperKitChannel {
  WhisperKitChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.archiveme/whisper_kit';

  final MethodChannel _channel;

  Future<bool> hardwareSupported() async {
    final result = await _channel.invokeMethod<Object?>('hardwareSupported');
    return result == true;
  }

  Future<bool> modelReady() async {
    final result = await _channel.invokeMethod<Object?>('modelReady');
    return result == true;
  }

  /// Trimmed transcript, or null when the engine produced none.
  Future<String?> transcribeFile({
    required String audioPath,
    required String localeIdentifier,
  }) async {
    final result = await _channel.invokeMethod<Object?>(
      'transcribeFile',
      {
        'audioPath': audioPath,
        'localeIdentifier': localeIdentifier,
      },
    );
    if (result is! String) return null;
    final trimmed = result.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }
}
