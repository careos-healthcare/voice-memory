import 'dart:math' as math;
import 'dart:typed_data';

/// Converts sherpa-onnx float PCM samples in [-1, 1] to signed 16-bit LE bytes.
Uint8List float32SamplesToPcm16LeBytes(Float32List samples) {
  if (samples.isEmpty) {
    return Uint8List(0);
  }

  final bytes = Uint8List(samples.length * 2);
  final view = ByteData.view(bytes.buffer);
  for (var index = 0; index < samples.length; index++) {
    final clamped = samples[index].clamp(-1.0, 1.0);
    final pcm = (clamped * 32767).round().clamp(-32768, 32767);
    view.setInt16(index * 2, pcm, Endian.little);
  }
  return bytes;
}

/// Deterministic PCM16 sine tone for stub synthesis and tests.
Uint8List synthesizePcm16Sine({
  required int sampleRateHz,
  required double durationSeconds,
  double frequencyHz = 440,
  double amplitude = 0.25,
}) {
  final sampleCount = math.max(1, (sampleRateHz * durationSeconds).round());
  final bytes = Uint8List(sampleCount * 2);
  final view = ByteData.view(bytes.buffer);
  for (var index = 0; index < sampleCount; index++) {
    final t = index / sampleRateHz;
    final value =
        (math.sin(2 * math.pi * frequencyHz * t) * amplitude * 32767).round();
    view.setInt16(index * 2, value.clamp(-32768, 32767), Endian.little);
  }
  return bytes;
}
