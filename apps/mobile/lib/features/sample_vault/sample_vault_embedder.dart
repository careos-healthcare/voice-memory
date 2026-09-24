import 'dart:math' as math;
import 'dart:typed_data';

/// Hashes words into a normalized vector so sample search stays on device.
abstract final class SampleVaultEmbedder {
  static const dimensions = 384;

  static Float32List embed(String text) {
    final vector = Float32List(dimensions);
    final tokens = text
        .toLowerCase()
        .split(RegExp('[^a-z0-9]+'))
        .where((token) => token.length > 2);
    for (final token in tokens) {
      var hash = 0;
      for (final code in token.codeUnits) {
        hash = (hash * 33 + code) & 0x7fffffff;
      }
      vector[hash % dimensions] += 1;
      vector[(hash ~/ 7) % dimensions] += 0.5;
    }
    var norm = 0.0;
    for (final value in vector) {
      norm += value * value;
    }
    if (norm == 0) return vector;
    final scale = 1 / math.sqrt(norm);
    for (var index = 0; index < vector.length; index++) {
      vector[index] *= scale;
    }
    return vector;
  }

  static Uint8List toBlob(Float32List embedding) {
    final bytes = ByteData(embedding.length * 4);
    for (var index = 0; index < embedding.length; index++) {
      bytes.setFloat32(index * 4, embedding[index], Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  static Float32List fromBlob(Uint8List blob) {
    final copy = Uint8List.fromList(blob);
    final data = ByteData.sublistView(copy);
    final vector = Float32List(copy.length ~/ 4);
    for (var index = 0; index < vector.length; index++) {
      vector[index] = data.getFloat32(index * 4, Endian.little);
    }
    return vector;
  }

  static double cosine(Float32List left, Float32List right) {
    final width = math.min(left.length, right.length);
    var dot = 0.0;
    for (var index = 0; index < width; index++) {
      dot += left[index] * right[index];
    }
    return dot;
  }
}
