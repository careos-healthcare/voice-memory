import 'dart:typed_data';

import 'package:archiveme_mobile/services/offline_tts/offline_tts_pcm_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('float32SamplesToPcm16LeBytes', () {
    test('converts known float samples to little-endian PCM16', () {
      final samples = Float32List.fromList([0, 0.5, -0.5, 1.0, -1.0]);
      final bytes = float32SamplesToPcm16LeBytes(samples);

      expect(bytes.length, samples.length * 2);
      expect(bytes[0], 0);
      expect(bytes[1], 0);

      final half = ByteData.view(bytes.buffer).getInt16(2, Endian.little);
      expect(half, closeTo(16383, 1));

      final negativeHalf = ByteData.view(bytes.buffer).getInt16(4, Endian.little);
      expect(negativeHalf, closeTo(-16383, 1));

      final max = ByteData.view(bytes.buffer).getInt16(6, Endian.little);
      expect(max, 32767);

      final min = ByteData.view(bytes.buffer).getInt16(8, Endian.little);
      expect(min, -32767);
    });

    test('returns empty bytes for empty input', () {
      expect(float32SamplesToPcm16LeBytes(Float32List(0)), isEmpty);
    });
  });

  group('synthesizePcm16Sine', () {
    test('generates expected number of samples for duration', () {
      const sampleRateHz = 24000;
      const durationSeconds = 0.1;
      final bytes = synthesizePcm16Sine(
        sampleRateHz: sampleRateHz,
        durationSeconds: durationSeconds,
      );

      expect(bytes.length, sampleRateHz * durationSeconds * 2);
    });
  });
}
