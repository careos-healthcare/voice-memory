import 'dart:typed_data';

import 'package:archiveme_mobile/features/capture/vad/vad_models.dart';

/// Lightweight on-device VAD inspired by WebRTC frame classifiers.
///
/// Operates on mono PCM16 frames (10/20/30 ms @ 8/16/32/48 kHz).
abstract final class WebRtcVadEngine {
  WebRtcVadEngine._();

  static bool isSpeechPcm16(
    Int16List frame, {
    required int sampleRateHz,
    VadAggressiveness aggressiveness = VadAggressiveness.quality,
  }) {
    if (frame.isEmpty) return false;
    final energy = _normalizedEnergy(frame);
    final zcr = _zeroCrossingRate(frame);
    final thresholds = _thresholdsFor(aggressiveness);
    if (energy < thresholds.minEnergy) return false;
    if (energy > thresholds.maxEnergy) return true;
    return zcr >= thresholds.minZcr && zcr <= thresholds.maxZcr;
  }

  static bool isSpeechBytes(
    Uint8List pcmLeBytes, {
    required int sampleRateHz,
    VadAggressiveness aggressiveness = VadAggressiveness.quality,
  }) {
    if (pcmLeBytes.length < 2) return false;
    final sampleCount = pcmLeBytes.length ~/ 2;
    final frame = Int16List(sampleCount);
    for (var i = 0; i < sampleCount; i++) {
      final lo = pcmLeBytes[i * 2];
      final hi = pcmLeBytes[i * 2 + 1];
      frame[i] = (hi << 8) | lo;
      if (frame[i] > 32767) frame[i] -= 65536;
    }
    return isSpeechPcm16(
      frame,
      sampleRateHz: sampleRateHz,
      aggressiveness: aggressiveness,
    );
  }

  static bool isSpeechFromDb(
    double db, {
    VadAggressiveness aggressiveness = VadAggressiveness.quality,
  }) {
    final threshold = switch (aggressiveness) {
      VadAggressiveness.quality => -42.0,
      VadAggressiveness.lowBitrate => -38.0,
      VadAggressiveness.aggressive => -34.0,
      VadAggressiveness.veryAggressive => -30.0,
    };
    return db.isFinite && db > threshold;
  }

  static double _normalizedEnergy(Int16List frame) {
    var sum = 0.0;
    for (final sample in frame) {
      sum += sample * sample;
    }
    return sum / frame.length;
  }

  static double _zeroCrossingRate(Int16List frame) {
    if (frame.length < 2) return 0;
    var crossings = 0;
    for (var i = 1; i < frame.length; i++) {
      final prev = frame[i - 1];
      final cur = frame[i];
      if ((prev >= 0 && cur < 0) || (prev < 0 && cur >= 0)) {
        crossings++;
      }
    }
    return crossings / frame.length;
  }

  static _VadThresholds _thresholdsFor(VadAggressiveness mode) {
    return switch (mode) {
      VadAggressiveness.quality => const _VadThresholds(
        minEnergy: 1_200_000,
        maxEnergy: 12_000_000,
        minZcr: 0.02,
        maxZcr: 0.35,
      ),
      VadAggressiveness.lowBitrate => const _VadThresholds(
        minEnergy: 900_000,
        maxEnergy: 10_000_000,
        minZcr: 0.025,
        maxZcr: 0.32,
      ),
      VadAggressiveness.aggressive => const _VadThresholds(
        minEnergy: 650_000,
        maxEnergy: 8_000_000,
        minZcr: 0.03,
        maxZcr: 0.30,
      ),
      VadAggressiveness.veryAggressive => const _VadThresholds(
        minEnergy: 450_000,
        maxEnergy: 6_000_000,
        minZcr: 0.035,
        maxZcr: 0.28,
      ),
    };
  }
}

class _VadThresholds {
  const _VadThresholds({
    required this.minEnergy,
    required this.maxEnergy,
    required this.minZcr,
    required this.maxZcr,
  });

  final double minEnergy;
  final double maxEnergy;
  final double minZcr;
  final double maxZcr;
}
