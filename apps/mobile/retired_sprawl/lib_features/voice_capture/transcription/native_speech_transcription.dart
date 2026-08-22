import 'dart:io';

import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract class NativeSpeechTranscriptionPlatform {
  Future<Map<Object?, Object?>?> transcribeFile({
    required String audioPath,
    required bool preferOnDevice,
  });
}

class MethodChannelNativeSpeechTranscriptionPlatform
    implements NativeSpeechTranscriptionPlatform {
  MethodChannelNativeSpeechTranscriptionPlatform({MethodChannel? channel})
    : _channel = channel ??
          const MethodChannel(NativeSpeechTranscription.channelName);

  final MethodChannel _channel;

  @override
  Future<Map<Object?, Object?>?> transcribeFile({
    required String audioPath,
    required bool preferOnDevice,
  }) async {
    final result = await _channel.invokeMethod<Object?>(
      'transcribeFile',
      {
        'audioPath': audioPath,
        'preferOnDevice': preferOnDevice,
      },
    );
    if (result is Map) return result;
    return null;
  }
}

/// On-device platform speech recognition for offline capture fallback.
abstract final class NativeSpeechTranscription {
  NativeSpeechTranscription._();

  static const channelName = 'archive_me/native_speech_transcription';

  @visibleForTesting
  static NativeSpeechTranscriptionPlatform? testPlatform;

  static NativeSpeechTranscriptionPlatform get _platform =>
      testPlatform ?? MethodChannelNativeSpeechTranscriptionPlatform();

  static bool get isSupported =>
      testPlatform != null ||
      (!kIsWeb && (Platform.isIOS || Platform.isAndroid));

  /// Returns trimmed transcript text, or null when native STT is unavailable.
  static Future<String?> transcribeFile(
    File audioFile, {
    bool preferOnDevice = true,
  }) async {
    if (!isSupported || !audioFile.existsSync()) return null;
    TranscriptionLog.mode('native_file_stt_start');
    try {
      final payload = await _platform.transcribeFile(
        audioPath: audioFile.path,
        preferOnDevice: preferOnDevice,
      );
      final transcript = payload?['transcript']?.toString().trim() ?? '';
      if (transcript.isEmpty) {
        final reason = payload?['reason']?.toString() ?? 'empty_native_transcript';
        TranscriptionLog.failed(reason: reason);
        return null;
      }
      TranscriptionLog.success(transcriptLength: transcript.length);
      return transcript;
    } on PlatformException catch (error, stackTrace) {
      TranscriptionLog.failed(reason: 'native_stt:${error.code}');
      return null;
    } catch (error, stackTrace) {
      TranscriptionLog.failed(reason: 'native_stt:$error');
      return null;
    }
  }
}