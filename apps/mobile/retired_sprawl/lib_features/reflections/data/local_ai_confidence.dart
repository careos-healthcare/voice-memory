import 'dart:math';

import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcript_quality.dart';

/// Confidence scoring for the on-device transcription + extraction pipeline.
abstract final class LocalAiConfidence {
  LocalAiConfidence._();

  /// Remote Retrofit fallback triggers when overall confidence is below this.
  static const remoteFallbackThreshold = 0.80;

  /// The bar a local reflection must clear when no remote re-scoring can ever
  /// happen for it.
  ///
  /// Deliberately lower than [remoteFallbackThreshold], and deliberately not
  /// unified with it. 0.80 is not a statement about reflection quality — it is
  /// the point at which shipping the audio to the server is worth it, and it
  /// presupposes that a better remote result is available to switch to. Under
  /// "Never send to server" there is no such alternative, and on-device
  /// extraction legitimately scores below 0.80 on material a remote model
  /// handles well, so reusing 0.80 here would reject work that is the best
  /// obtainable on the device.
  ///
  /// It is not 0.0 either, which is what this used to be. These reflections are
  /// claims about the customer's own patterns and beliefs; one that cleared no
  /// bar at all must not reach a surface with the same standing as a scored
  /// one.
  static const onDeviceOnlyQualityFloor = 0.55;

  /// "Was this local result good enough to report as scored?"
  ///
  /// Kept separate from [effectiveRemoteFallbackThreshold] on purpose. This is
  /// a question about the reflection; that one is a question about the network.
  /// They looked like the same question only while on-device-only answered 0.0
  /// to both, which made every local reflection appear to have passed a bar
  /// that was never applied.
  static Future<double> effectiveQualityFloor() async {
    await OnDeviceProcessingStore.ensureLoaded();
    if (OnDeviceProcessingStore.enabled) {
      return onDeviceOnlyQualityFloor;
    }
    return remoteFallbackThreshold;
  }

  /// "May this leave the device?" — 0 when it may not.
  ///
  /// The 0 is redundant to the privacy guarantee rather than the source of it:
  /// `_maybeRemoteFallback` checks [OnDeviceProcessingStore] itself before
  /// touching the network. Do not raise it to [onDeviceOnlyQualityFloor]
  /// without reading every caller first — `voice_capture_handler` also uses
  /// this value to decide whether a locally-analyzed entry is saved at all, and
  /// a higher number there changes which save path a journal entry takes.
  /// [effectiveQualityFloor] exists so the quality signal can move without
  /// dragging that decision along with it.
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
