import 'dart:typed_data';

import 'package:archiveme_mobile/audio/silence_trim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('review speeds are 1.0x, 1.25x, 1.5x, and 2.0x', () {
    expect(
      PlaybackReviewSpeeds.speeds.map(PlaybackReviewSpeeds.label),
      ['1.0x', '1.25x', '1.5x', '2.0x'],
    );
    expect(PlaybackReviewSpeeds.allows(1.25), isTrue);
    expect(PlaybackReviewSpeeds.allows(3), isFalse);
  });

  test('long silence is cut out of the review copy', () {
    final speech = List<int>.filled(800, 8000);
    final silence = List<int>.filled(SilenceTrimmer.minSilenceSamples + 200, 0);
    final pcm = _pcm([...speech, ...silence, ...speech]);

    final trimmed = SilenceTrimmer.trim(pcm);
    final kept = trimmed.length ~/ 2;

    expect(SilenceTrimmer.spans(pcm), isNotEmpty);
    expect(kept, speech.length * 2);
    expect(kept, lessThan(pcm.length ~/ 2));
  });

  test('playback jumps to the end of a silence span', () {
    final gaps = [
      SilenceSpan(startSample: 100, endSample: 5000),
    ];
    final target = SilenceTrimmer.skipFraction(
      position: 0.02,
      duration: const Duration(seconds: 1),
      gaps: gaps,
    );
    expect(target, closeTo(5000 / SilenceTrimmer.sampleRateHz, 0.001));
  });
}

Uint8List _pcm(List<int> samples) {
  final bytes = Uint8List(samples.length * 2);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  return bytes;
}
