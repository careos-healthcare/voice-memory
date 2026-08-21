import 'dart:math';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/search/reflection_embedding_contract.dart';

/// Tokenizes reflection text into the ONNX `[1, maxSeqLen]` input tensor.
abstract final class ReflectionTextProcessor {
  ReflectionTextProcessor._();

  static const minTextChars = 4;

  static int get tensorElementCount => ReflectionEmbeddingContract.maxSeqLen;

  static Float32List buildInputTensor(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    final tokens = _tokenize(normalized);
    final out = Float32List(tensorElementCount);
    for (var i = 0; i < min(tokens.length, tensorElementCount); i++) {
      out[i] = tokens[i].toDouble();
    }
    return out;
  }

  static List<int> _tokenize(String normalized) {
    if (normalized.isEmpty) return const [];
    final words = normalized.split(' ');
    final buckets = <int>[];
    for (final word in words) {
      if (word.isEmpty) continue;
      buckets.add(_hashToken(word));
      if (buckets.length >= ReflectionEmbeddingContract.maxSeqLen) break;
    }
    return buckets;
  }

  static int _hashToken(String token) {
    var hash = 2166136261;
    for (final unit in token.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return hash % 32000 + 1;
  }

  static List<double> l2Normalize(List<double> vector) {
    var norm = 0.0;
    for (final value in vector) {
      norm += value * value;
    }
    norm = sqrt(norm);
    if (norm == 0) return vector;
    return vector.map((value) => value / norm).toList(growable: false);
  }
}
