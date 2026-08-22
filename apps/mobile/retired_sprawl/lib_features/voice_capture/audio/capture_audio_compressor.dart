import 'dart:io';

import 'package:archiveme_mobile/features/voice_capture/audio/audio_diag_log.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/capture_audio_compressor_config.dart';
import 'package:archiveme_mobile/services/record_pipeline_log.dart';
import 'package:archiveme_mobile/storage/app_storage_paths.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class CaptureAudioCompressResult {
  const CaptureAudioCompressResult({
    required this.file,
    required this.wasCompressed,
    required this.outputBytes,
  });

  final File file;
  final bool wasCompressed;
  final int outputBytes;
}

abstract class CaptureAudioCompressorPlatform {
  Future<Map<Object?, Object?>?> compress({
    required String inputPath,
    required String outputPath,
  });
}

class MethodChannelCaptureAudioCompressorPlatform
    implements CaptureAudioCompressorPlatform {
  MethodChannelCaptureAudioCompressorPlatform({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(CaptureAudioCompressor.channelName);

  final MethodChannel _channel;

  @override
  Future<Map<Object?, Object?>?> compress({
    required String inputPath,
    required String outputPath,
  }) async {
    final result = await _channel.invokeMethod<Object?>(
      'compressForUpload',
      {
        'inputPath': inputPath,
        'outputPath': outputPath,
        'sampleRateHz': CaptureAudioCompressorConfig.sampleRateHz,
        'bitRateBps': CaptureAudioCompressorConfig.bitRateBps,
        'channelCount': CaptureAudioCompressorConfig.channelCount,
      },
    );
    if (result is Map) return result;
    return null;
  }
}

/// Re-encodes capture audio to AAC 32 kbps / 16 kHz mono before cloud upload.
abstract final class CaptureAudioCompressor {
  CaptureAudioCompressor._();

  static const channelName = 'archive_me/capture_audio_compressor';

  @visibleForTesting
  static CaptureAudioCompressorPlatform? testPlatform;

  static CaptureAudioCompressorPlatform get _platform =>
      testPlatform ?? MethodChannelCaptureAudioCompressorPlatform();

  static bool get isSupported =>
      testPlatform != null ||
      (!kIsWeb && (Platform.isIOS || Platform.isAndroid));

  /// Returns a file suitable for upload — compressed when native support exists.
  static Future<CaptureAudioCompressResult> compressForUpload(File input) async {
    if (!input.existsSync()) {
      throw StateError('capture_audio_missing');
    }
    final inputBytes = input.lengthSync();
    if (!isSupported) {
      return CaptureAudioCompressResult(
        file: input,
        wasCompressed: false,
        outputBytes: inputBytes,
      );
    }

    final tempDir = await AppStoragePaths.temporaryDirectory();
    final outputPath = p.join(
      tempDir.path,
      'upload_${DateTime.now().microsecondsSinceEpoch}.${CaptureAudioCompressorConfig.containerExtension}',
    );

    try {
      final payload = await _platform.compress(
        inputPath: input.path,
        outputPath: outputPath,
      );
      final path = payload?['path']?.toString() ?? outputPath;
      final file = File(path);
      if (!file.existsSync()) {
        RecordPipelineLog.transcriptionFallback(
          reason: 'compress_output_missing',
          audioPath: input.path,
        );
        return CaptureAudioCompressResult(
          file: input,
          wasCompressed: false,
          outputBytes: inputBytes,
        );
      }
      final outputBytes = file.lengthSync();
      AudioDiagLog.upload(
        fileName: p.basename(file.path),
        contentType: 'audio/mp4',
        bytes: outputBytes,
      );
      RecordPipelineLog.audioFile(
        path: file.path,
        exists: true,
        byteLength: outputBytes,
      );
      return CaptureAudioCompressResult(
        file: file,
        wasCompressed: payload?['compressed'] == true,
        outputBytes: outputBytes,
      );
    } on PlatformException catch (error, stackTrace) {
      RecordPipelineLog.transcriptionFallback(
        reason: 'compress_failed:${error.code}',
        audioPath: input.path,
      );
      return CaptureAudioCompressResult(
        file: input,
        wasCompressed: false,
        outputBytes: inputBytes,
      );
    }
  }
}