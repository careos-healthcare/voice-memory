import 'dart:typed_data';

import 'package:archiveme_mobile/services/offline_tts/offline_tts_config.dart';

/// A partial or final PCM chunk emitted while synthesizing speech.
final class OfflineTtsPcmChunk {
  const OfflineTtsPcmChunk({
    required this.pcmBytes,
    required this.sampleRateHz,
    required this.progress,
    this.isFinal = false,
  });

  final List<int> pcmBytes;
  final int sampleRateHz;

  /// Normalized synthesis progress in `[0, 1]` when reported by the backend.
  final double progress;
  final bool isFinal;
}

/// Request passed to an offline TTS backend.
final class OfflineTtsSpeakRequest {
  const OfflineTtsSpeakRequest({
    required this.text,
    this.speakerId,
    this.speed,
  });

  final String text;
  final int? speakerId;
  final double? speed;
}

/// Result of a completed offline synthesis pass.
final class OfflineTtsSpeakResult {
  const OfflineTtsSpeakResult({
    required this.sampleRateHz,
    required this.totalPcmBytes,
    required this.chunkCount,
    required this.duration,
  });

  final int sampleRateHz;
  final int totalPcmBytes;
  final int chunkCount;
  final Duration duration;
}

/// Thrown when synthesis fails or the backend is used before [load].
final class OfflineTtsException implements Exception {
  OfflineTtsException(this.message);

  final String message;

  @override
  String toString() => 'OfflineTtsException: $message';
}

typedef OfflineTtsProgressCallback = void Function(OfflineTtsPcmChunk chunk);

/// Pluggable synthesis backend for [OfflineTtsService].
abstract interface class OfflineTtsBackend {
  Future<void> load(OfflineTtsConfig config);

  Stream<OfflineTtsPcmChunk> synthesize(OfflineTtsSpeakRequest request);

  Future<void> dispose();

  bool get isLoaded;

  int get sampleRateHz;

  int get numSpeakers;
}

/// Optional hook for unit tests to observe raw float samples before PCM conversion.
typedef OfflineTtsFloatChunkCallback = void Function(Float32List samples);
