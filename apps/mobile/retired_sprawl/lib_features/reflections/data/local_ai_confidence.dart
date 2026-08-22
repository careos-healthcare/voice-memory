import 'dart:math';

import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcript_quality.dart';

/// Confidence scoring for the on-device transcription + extraction pipeline.
abstract final class LocalAiConfidence {
  LocalAiConfidence._();

  /// Remote Retrofit fallback triggers when overall confidence is below this.
  static const remoteFallbackThreshold = 0.80;

  /// When [OnDeviceProcessingStore] is enabled, local results are always kept
  /// on-device — threshold drops to 0 so remote fallback never triggers.
  static Future<double> effectiveRemoteFallbackThreshold() async {
    await OnDeviceProcessingStore.ensureLoaded();
    if (OnDeviceProcessingStore.enabled) {
      return 0.0;
    }
    return remoteFallbackThreshold;
  }

  static double transcriptionConfidence({
    required String transcript,
    double? modelScore,
  }) {
    if (modelScore != null) {
      return modelScore.clamp(0.0, 1.0);
    }

    final verdict = TranscriptQuality.evaluate(transcript);
    if (!verdict.isValid) return 0.0;

    final words = verdict.normalized.split(RegExp(r'\s+')).length;
    final letters = RegExp('[A-Za-z]').allMatches(verdict.normalized).length;
    final lengthScore = (letters / 80).clamp(0.0, 1.0);
    final wordScore = (words / 12).clamp(0.0, 1.0);
    return (0.55 + 0.25 * lengthScore + 0.20 * wordScore).clamp(0.0, 0.92);
  }

  static double reflectionConfidence({
    required ReflectionDto reflection,
    double? modelScore,
    required bool usedOnnx,
  }) {
    var score = modelScore ?? (usedOnnx ? 0.86 : 0.74);

    if (reflection.emotionalIntensity >= 1 && reflection.emotionalIntensity <= 10) {
      score += 0.02;
    }
    if ((reflection.tensionOrContradiction ?? '').trim().length >= 8) {
      score += 0.04;
    }
    if ((reflection.nextSmallAction ?? '').trim().length >= 6) {
      score += 0.04;
    }
    if (reflection.recurringThemes.isNotEmpty) score += 0.02;

    return score.clamp(0.0, 1.0);
  }

  static double overall({
    required double transcription,
    required double reflection,
  }) {
    return sqrt(transcription.clamp(0.0, 1.0) * reflection.clamp(0.0, 1.0));
  }
}
