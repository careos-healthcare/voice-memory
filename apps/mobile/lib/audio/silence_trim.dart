import 'dart:typed_data';

/// Playback rates for reviewing a saved recording.
abstract final class PlaybackReviewSpeeds {
  static const speeds = <double>[1, 1.25, 1.5, 2];

  static String label(double speed) {
    if (speed == 1.25 || speed == 1.5) return '${speed}x';
    return '${speed.toStringAsFixed(1)}x';
  }

  static bool allows(double speed) => speeds.contains(speed);
}

/// A stretch of quiet samples that review playback can skip.
class SilenceSpan {
  const SilenceSpan({required this.startSample, required this.endSample});

  final int startSample;
  final int endSample;

  bool contains(int sample) => sample >= startSample && sample < endSample;
}

/// Finds long quiet stretches in 16-bit PCM and drops them from a review copy.
abstract final class SilenceTrimmer {
  static const sampleRateHz = 16000;
  static const amplitudeThreshold = 400;
  static const minSilenceMs = 400;

  static int get minSilenceSamples =>
      (sampleRateHz * minSilenceMs / 1000).round();

  static List<SilenceSpan> spans(
    Uint8List pcm, {
    int threshold = amplitudeThreshold,
    int minSamples = 0,
  }) {
    final samples = _samples(pcm);
    final quietFor = minSamples == 0 ? minSilenceSamples : minSamples;
    final gaps = <SilenceSpan>[];
    var quietStart = -1;
    for (var i = 0; i < samples.length; i++) {
      final quiet = samples[i].abs() < threshold;
      if (quiet && quietStart < 0) quietStart = i;
      final ended = !quiet || i == samples.length - 1;
      if (quietStart >= 0 && ended) {
        final end = quiet ? i + 1 : i;
        if (end - quietStart >= quietFor) {
          gaps.add(SilenceSpan(startSample: quietStart, endSample: end));
        }
        quietStart = -1;
      }
    }
    return gaps;
  }

  /// PCM with long silences removed, so review plays the speech back to back.
  static Uint8List trim(Uint8List pcm) {
    final samples = _samples(pcm);
    if (samples.isEmpty) return pcm;
    final gaps = spans(pcm);
    if (gaps.isEmpty) return pcm;
    final kept = <int>[];
    var cursor = 0;
    for (final gap in gaps) {
      kept.addAll(samples.sublist(cursor, gap.startSample));
      cursor = gap.endSample;
    }
    if (cursor < samples.length) {
      kept.addAll(samples.sublist(cursor));
    }
    return _bytes(kept);
  }

  /// Fraction of [duration] where playback should resume, if [position] is inside a gap.
  static double? skipFraction({
    required double position,
    required Duration duration,
    required List<SilenceSpan> gaps,
    int sampleRate = sampleRateHz,
  }) {
    if (duration <= Duration.zero || gaps.isEmpty) return null;
    final total = duration.inMicroseconds / 1000000 * sampleRate;
    if (total <= 0) return null;
    final sample = (position.clamp(0, 1) * total).floor();
    for (final gap in gaps) {
      if (gap.contains(sample) && gap.endSample > sample) {
        return (gap.endSample / total).clamp(0, 1).toDouble();
      }
    }
    return null;
  }

  static List<int> _samples(Uint8List pcm) {
    final data = ByteData.sublistView(pcm);
    final count = pcm.length ~/ 2;
    return [
      for (var i = 0; i < count; i++) data.getInt16(i * 2, Endian.little),
    ];
  }

  static Uint8List _bytes(List<int> samples) {
    final bytes = Uint8List(samples.length * 2);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < samples.length; i++) {
      data.setInt16(i * 2, samples[i], Endian.little);
    }
    return bytes;
  }
}
