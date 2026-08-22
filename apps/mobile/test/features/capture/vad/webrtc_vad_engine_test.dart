import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/features/capture/vad/vad_models.dart';
import 'package:archiveme_mobile/features/capture/vad/webrtc_vad_engine.dart';
import 'package:flutter_test/flutter_test.dart';

Int16List _sineFrame({
  required int sampleRateHz,
  required int frameDurationMs,
  double amplitude = 12000,
}) {
  final sampleCount = (sampleRateHz * frameDurationMs / 1000).round();
  final frame = Int16List(sampleCount);
  for (var i = 0; i < sampleCount; i++) {
    frame[i] = (amplitude * math.sin(2 * math.pi * 440 * i / sampleRateHz))
        .round();
  }
  return frame;
}

Uint8List _frameToBytes(Int16List frame) {
  final bytes = Uint8List(frame.length * 2);
  for (var i = 0; i < frame.length; i++) {
    bytes[i * 2] = frame[i] & 0xff;
    bytes[i * 2 + 1] = (frame[i] >> 8) & 0xff;
  }
  return bytes;
}

void main() {
  group('WebRtcVadEngine', () {
    test('detects energetic speech-like frames', () {
      final frame = _sineFrame(sampleRateHz: 16000, frameDurationMs: 20);
      expect(
        WebRtcVadEngine.isSpeechPcm16(
          frame,
          sampleRateHz: 16000,
          aggressiveness: VadAggressiveness.quality,
        ),
        isTrue,
      );
    });

    test('rejects near-silence frames', () {
      final frame = Int16List(320);
      expect(
        WebRtcVadEngine.isSpeechPcm16(
          frame,
          sampleRateHz: 16000,
        ),
        isFalse,
      );
    });

    test('classifies PCM byte frames consistently', () {
      final frame = _sineFrame(sampleRateHz: 16000, frameDurationMs: 20);
      final bytes = _frameToBytes(frame);
      expect(
        WebRtcVadEngine.isSpeechBytes(bytes, sampleRateHz: 16000),
        isTrue,
      );
    });

    test('maps dB thresholds by aggressiveness', () {
      expect(
        WebRtcVadEngine.isSpeechFromDb(-41, aggressiveness: VadAggressiveness.quality),
        isTrue,
      );
      expect(
        WebRtcVadEngine.isSpeechFromDb(-43, aggressiveness: VadAggressiveness.quality),
        isFalse,
      );
    });
  });
}
