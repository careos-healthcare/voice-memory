import 'dart:async';
import 'dart:math' as math;

import 'package:archiveme_mobile/services/offline_tts/offline_tts_backend.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_config.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_pcm_converter.dart';

/// Deterministic offline TTS backend for tests and development without native libs.
final class StubOfflineTtsBackend implements OfflineTtsBackend {
  StubOfflineTtsBackend({
    this.sampleRateHz = 24000,
    this.chunkDurationSeconds = 0.05,
    this.baseFrequencyHz = 440,
    this.interChunkDelay = Duration.zero,
  });

  final int sampleRateHz;
  final double chunkDurationSeconds;
  final double baseFrequencyHz;
  final Duration interChunkDelay;

  OfflineTtsConfig? _config;
  var _cancelRequested = false;

  @override
  bool get isLoaded => _config != null;

  @override
  int get numSpeakers => 1;

  @override
  Future<void> load(OfflineTtsConfig config) async {
    _config = config;
  }

  @override
  Stream<OfflineTtsPcmChunk> synthesize(OfflineTtsSpeakRequest request) async* {
    _requireLoaded();
    final trimmed = request.text.trim();
    if (trimmed.isEmpty) {
      throw OfflineTtsException('Cannot synthesize empty text.');
    }

    _cancelRequested = false;
    final words = trimmed.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    final wordCount = math.max(1, words.length);
    final totalDurationSeconds = wordCount * chunkDurationSeconds * 4;
    final totalChunks = math.max(1, (totalDurationSeconds / chunkDurationSeconds).ceil());

    for (var chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
      if (_cancelRequested) {
        break;
      }

      final progress = (chunkIndex + 1) / totalChunks;
      final frequency = baseFrequencyHz + (chunkIndex % 5) * 20;
      final pcmBytes = synthesizePcm16Sine(
        sampleRateHz: sampleRateHz,
        durationSeconds: chunkDurationSeconds,
        frequencyHz: frequency,
      );

      yield OfflineTtsPcmChunk(
        pcmBytes: pcmBytes,
        sampleRateHz: sampleRateHz,
        progress: progress,
        isFinal: chunkIndex == totalChunks - 1,
      );
      if (interChunkDelay > Duration.zero) {
        await Future<void>.delayed(interChunkDelay);
      } else {
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (!_cancelRequested) {
      yield OfflineTtsPcmChunk(
        pcmBytes: const [],
        sampleRateHz: sampleRateHz,
        progress: 1,
        isFinal: true,
      );
    }
  }

  void requestCancel() {
    _cancelRequested = true;
  }

  @override
  Future<void> dispose() async {
    _config = null;
    _cancelRequested = false;
  }

  void _requireLoaded() {
    if (_config == null) {
      throw StateError('StubOfflineTtsBackend.load must be called first.');
    }
  }
}
