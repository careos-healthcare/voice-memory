import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

typedef PostTranscriptionCompress =
    Future<Map<Object?, Object?>?> Function({
      required String inputPath,
      required String outputPath,
    });

/// Shrinks a raw WAV or PCM capture after on-device transcription.
class PostTranscriptionCompressor {
  PostTranscriptionCompressor({
    MethodChannel? channel,
    this.compressOverride,
  }) : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.archiveme/audio_compression';
  static const method = 'compressAfterTranscription';

  final MethodChannel _channel;
  final PostTranscriptionCompress? compressOverride;

  static const rawExtensions = {'wav', 'wave', 'pcm'};

  static bool isRawAudio(File file) {
    return rawExtensions.contains(
      p.extension(file.path).replaceFirst('.', '').toLowerCase(),
    );
  }

  Future<File> compressAndDiscardRaw(File input) async {
    if (!input.existsSync() || !isRawAudio(input)) return input;
    final outputPath = p.join(
      p.dirname(input.path),
      '${p.basenameWithoutExtension(input.path)}.m4a',
    );
    try {
      final payload = compressOverride != null
          ? await compressOverride!(
              inputPath: input.path,
              outputPath: outputPath,
            )
          : await _channel.invokeMethod<Object?>(method, {
              'inputPath': input.path,
              'outputPath': outputPath,
            });
      if (payload is! Map) return input;
      final stored = payload['path']?.toString();
      if (stored == null || stored.isEmpty) return input;
      final file = File(stored);
      if (!file.existsSync()) return input;
      return file;
    } on PlatformException {
      return input;
    } on MissingPluginException {
      return input;
    }
  }
}
