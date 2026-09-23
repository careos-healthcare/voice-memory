import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Tone for one stretch of a moment, stored beside the recording.
enum WaveformTone { positive, neutral, tension, highTension }

/// A slice of the recording painted in one tone.
class WaveformToneSpan {
  const WaveformToneSpan({
    required this.start,
    required this.end,
    required this.tone,
  });

  /// Start as a fraction of the recording, from 0 to 1.
  final double start;

  /// End as a fraction of the recording, from 0 to 1.
  final double end;
  final WaveformTone tone;
}

/// A pause marked by voice activity detection.
class WaveformSilence {
  const WaveformSilence({required this.start, required this.end});

  final double start;
  final double end;

  bool contains(double position) => position >= start && position < end;
}

/// Bars, tone slices, and VAD pauses for one recording.
class WaveformPicture {
  const WaveformPicture({
    required this.amplitudes,
    this.tones = const [],
    this.silences = const [],
  });

  /// Normalized peaks, each from 0 to 1.
  final List<double> amplitudes;
  final List<WaveformToneSpan> tones;
  final List<WaveformSilence> silences;
}

/// Turns 16-bit little-endian PCM into normalized bar peaks.
List<double> amplitudesFromPcm(
  Uint8List pcm, {
  int barCount = 48,
}) {
  if (barCount <= 0 || pcm.length < 2) return const [];
  final sampleCount = pcm.length ~/ 2;
  final data = ByteData.sublistView(pcm);
  final bars = List<double>.filled(barCount, 0);
  final chunk = math.max(1, sampleCount ~/ barCount);
  for (var bar = 0; bar < barCount; bar++) {
    final start = bar * chunk;
    if (start >= sampleCount) break;
    final end = math.min(sampleCount, start + chunk);
    var peak = 0;
    for (var sample = start; sample < end; sample++) {
      final value = data.getInt16(sample * 2, Endian.little).abs();
      if (value > peak) peak = value;
    }
    bars[bar] = peak / 32768;
  }
  final loudest = bars.fold<double>(0, math.max);
  if (loudest <= 0) return bars;
  return [for (final bar in bars) (bar / loudest).clamp(0, 1).toDouble()];
}

/// Speech windows from a VAD pass, inverted into the pauses between them.
///
/// [speech] fractions are the talking stretches a sherpa_onnx voice-activity
/// detector reports. Everything between them is treated as silence.
List<WaveformSilence> silencesFromSpeech(List<WaveformSilence> speech) {
  final ordered = [...speech]..sort((a, b) => a.start.compareTo(b.start));
  final gaps = <WaveformSilence>[];
  var cursor = 0.0;
  for (final window in ordered) {
    final start = window.start.clamp(0, 1).toDouble();
    final end = window.end.clamp(0, 1).toDouble();
    if (start > cursor) {
      gaps.add(WaveformSilence(start: cursor, end: start));
    }
    if (end > cursor) cursor = end;
  }
  if (cursor < 1) {
    gaps.add(WaveformSilence(start: cursor, end: 1));
  }
  return gaps;
}

/// Where playback should jump when [position] sits inside a pause.
double? skipSilenceTarget({
  required double position,
  required List<WaveformSilence> silences,
  required bool enabled,
}) {
  if (!enabled) return null;
  for (final gap in silences) {
    if (gap.contains(position) && gap.end > position) return gap.end;
  }
  return null;
}

WaveformTone toneAt(double fraction, List<WaveformToneSpan> tones) {
  for (final span in tones) {
    if (fraction >= span.start && fraction < span.end) return span.tone;
  }
  return WaveformTone.neutral;
}

/// Bar color for a tone. Pauses use a dim neutral so the gap stays visible.
Color waveformBarColor(WaveformTone tone, {required bool silent}) {
  if (silent) return AppTokens.neutral300;
  return switch (tone) {
    WaveformTone.positive => const Color(0xFF15803D),
    WaveformTone.neutral => AppTokens.primary600,
    WaveformTone.tension => const Color(0xFFD97706),
    WaveformTone.highTension => const Color(0xFFDC2626),
  };
}

/// Layout math shared by the painter and the scrub hit tests.
class WaveformGeometry {
  const WaveformGeometry({required this.size, required this.barCount});

  final Size size;
  final int barCount;

  static const handleSlop = 18.0;

  double fractionAt(double dx) {
    if (size.width <= 0) return 0;
    return (dx / size.width).clamp(0, 1).toDouble();
  }

  Rect barRect(int index, double amplitude, {required bool silent}) {
    final slot = size.width / math.max(1, barCount);
    final left = index * slot;
    final heightFactor = silent ? 0.12 : amplitude.clamp(0, 1).toDouble();
    final scaled = size.height * heightFactor;
    final barHeight = scaled < 2 ? 2.toDouble() : scaled;
    return Rect.fromLTWH(
      left + 1,
      size.height - barHeight,
      math.max(1, slot - 2),
      barHeight,
    );
  }

  Offset handleCenter(WaveformSilence silence) {
    return Offset(silence.start * size.width, size.height / 2);
  }

  int? handleAt(Offset point, List<WaveformSilence> silences) {
    for (var index = 0; index < silences.length; index++) {
      final center = handleCenter(silences[index]);
      if ((point - center).distance <= handleSlop) return index;
    }
    return null;
  }
}
