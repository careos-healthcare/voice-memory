import 'dart:math' as math;
import 'dart:typed_data';

/// Symmetric Int8 range used for values in `[-1, 1]`.
///
/// `-128` is left unused so positive and negative magnitudes share one scale.
const int symmetricInt8Max = 127;

/// Float32 payload for one 384-d embedding: `384 * 4`.
const int float32EmbeddingBytes = 1536;

/// Int8 payload for one 384-d embedding, before the separate scale factor.
const int int8EmbeddingBytes = 384;

/// One symmetric-quantized embedding plus the scale that restores it.
///
/// [codes] is the vector payload ([int8EmbeddingBytes] for 384 dimensions).
/// [alpha] is `max(|x_i|)` after clipping into `[-1, 1]`, so
/// `x_i ≈ codes[i] * alpha / 127`.
final class Int8Embedding {
  Int8Embedding({required Int8List codes, required this.alpha})
    : codes = Int8List.fromList(codes) {
    if (alpha.isNaN || alpha.isInfinite || alpha <= 0) {
      throw ArgumentError.value(
        alpha,
        'alpha',
        'must be a positive finite scale',
      );
    }
  }

  final Int8List codes;
  final double alpha;

  /// Quantized vector bytes. The scale is stored beside this payload.
  int get payloadBytes => codes.lengthInBytes;

  /// Restores an approximate Float32 vector with `codes[i] * alpha / 127`.
  Float32List dequantize() {
    final restored = Float32List(codes.length);
    final scale = alpha / symmetricInt8Max;
    for (var i = 0; i < codes.length; i++) {
      restored[i] = codes[i] * scale;
    }
    return restored;
  }
}

/// Maps Float32 embeddings in `[-1, 1]` onto Int8 codes in `[-127, 127]`.
Int8Embedding quantizeSymmetric(Float32List values) {
  if (values.isEmpty) {
    throw ArgumentError.value(
      values,
      'values',
      'must contain at least one lane',
    );
  }
  var peak = 0.0;
  for (var i = 0; i < values.length; i++) {
    final value = values[i];
    if (value.isNaN || value.isInfinite) {
      throw ArgumentError.value(value, 'values', 'must be finite');
    }
    final clipped = _clipUnit(value).abs();
    if (clipped > peak) {
      peak = clipped;
    }
  }
  final alpha = peak == 0 ? 1.0 : peak;
  final codes = Int8List(values.length);
  final invScale = symmetricInt8Max / alpha;
  for (var i = 0; i < values.length; i++) {
    var quantized = (_clipUnit(values[i]) * invScale).round();
    if (quantized > symmetricInt8Max) {
      quantized = symmetricInt8Max;
    } else if (quantized < -symmetricInt8Max) {
      quantized = -symmetricInt8Max;
    }
    codes[i] = quantized;
  }
  return Int8Embedding(codes: codes, alpha: alpha);
}

/// Unrolled Int8 dot product.
///
/// Dart has no Int8 SIMD multiply, so the loop accumulates eight lanes per
/// step. Products stay inside a 64-bit int for 384-d codes (`127² * 384`).
int int8Dot(Int8List left, Int8List right) {
  if (left.length != right.length) {
    throw ArgumentError('Int8 vectors must share a length');
  }
  var sum = 0;
  final length = left.length;
  var i = 0;
  for (; i + 8 <= length; i += 8) {
    sum += left[i] * right[i];
    sum += left[i + 1] * right[i + 1];
    sum += left[i + 2] * right[i + 2];
    sum += left[i + 3] * right[i + 3];
    sum += left[i + 4] * right[i + 4];
    sum += left[i + 5] * right[i + 5];
    sum += left[i + 6] * right[i + 6];
    sum += left[i + 7] * right[i + 7];
  }
  for (; i < length; i++) {
    sum += left[i] * right[i];
  }
  return sum;
}

/// Dot product of a Float32 query and a stored Int8 vector.
///
/// Applies [Int8Embedding.alpha] so the result is in the original space:
/// `alpha / 127 * Σ query[i] * codes[i]`.
double asymmetricDot(Float32List query, Int8Embedding document) {
  if (query.length != document.codes.length) {
    throw ArgumentError('Query and document must share a length');
  }
  final codes = document.codes;
  var acc = 0.0;
  final length = codes.length;
  var i = 0;
  for (; i + 4 <= length; i += 4) {
    acc += query[i] * codes[i];
    acc += query[i + 1] * codes[i + 1];
    acc += query[i + 2] * codes[i + 2];
    acc += query[i + 3] * codes[i + 3];
  }
  for (; i < length; i++) {
    acc += query[i] * codes[i];
  }
  return acc * (document.alpha / symmetricInt8Max);
}

/// Cosine between a Float32 query and a stored Int8 document.
///
/// The stored [Int8Embedding.alpha] scales both the dot product and the
/// document norm, which is the asymmetric score used at query time.
double asymmetricCosine(Float32List query, Int8Embedding document) {
  final queryNorm = _floatNorm(query);
  final documentNorm =
      (document.alpha / symmetricInt8Max) * _int8CodeNorm(document.codes);
  if (queryNorm == 0 || documentNorm == 0) {
    return 0;
  }
  final score = asymmetricDot(query, document) / (queryNorm * documentNorm);
  return score.clamp(-1.0, 1.0);
}

/// Cosine between two dequantized Int8 vectors, scored with their scales.
double int8Cosine(Int8Embedding left, Int8Embedding right) {
  if (left.codes.length != right.codes.length) {
    throw ArgumentError('Int8 vectors must share a length');
  }
  final leftNorm = (left.alpha / symmetricInt8Max) * _int8CodeNorm(left.codes);
  final rightNorm =
      (right.alpha / symmetricInt8Max) * _int8CodeNorm(right.codes);
  if (leftNorm == 0 || rightNorm == 0) {
    return 0;
  }
  final dot =
      int8Dot(left.codes, right.codes) *
      (left.alpha / symmetricInt8Max) *
      (right.alpha / symmetricInt8Max);
  final score = dot / (leftNorm * rightNorm);
  return score.clamp(-1.0, 1.0);
}

/// One nearest document from [Int8Corpus.search].
final class Int8SearchHit {
  const Int8SearchHit({required this.index, required this.similarity});

  final int index;
  final double similarity;
}

/// Int8 embeddings with precomputed code norms for repeated queries.
final class Int8Corpus {
  Int8Corpus(List<Int8Embedding> documents)
    : documents = List<Int8Embedding>.unmodifiable(documents),
      _codeNorms = Float64List(documents.length) {
    for (var i = 0; i < documents.length; i++) {
      _codeNorms[i] = _int8CodeNorm(documents[i].codes);
    }
  }

  final List<Int8Embedding> documents;
  final Float64List _codeNorms;

  /// Asymmetric top-[limit] search: Float32 [query] against stored Int8 rows.
  List<Int8SearchHit> search(Float32List query, {int limit = 10}) {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be positive');
    }
    final queryNorm = _floatNorm(query);
    final bestIndexes = <int>[];
    final bestScores = <double>[];
    for (var index = 0; index < documents.length; index++) {
      final document = documents[index];
      if (document.codes.length != query.length) {
        throw ArgumentError('Query and document must share a length');
      }
      final score = queryNorm == 0 || _codeNorms[index] == 0
          ? 0.0
          : _rawCodeDot(query, document.codes) /
                (queryNorm * _codeNorms[index]);
      _keepTop(bestIndexes, bestScores, index, score, limit);
    }
    return [
      for (var i = 0; i < bestIndexes.length; i++)
        Int8SearchHit(index: bestIndexes[i], similarity: bestScores[i]),
    ]..sort((a, b) => b.similarity.compareTo(a.similarity));
  }
}

double _clipUnit(double value) {
  if (value > 1) {
    return 1;
  }
  if (value < -1) {
    return -1;
  }
  return value;
}

double _floatNorm(Float32List values) {
  var sumSquares = 0.0;
  for (final value in values) {
    sumSquares += value * value;
  }
  return math.sqrt(sumSquares);
}

double _int8CodeNorm(Int8List codes) {
  var sumSquares = 0;
  for (final code in codes) {
    sumSquares += code * code;
  }
  return math.sqrt(sumSquares);
}

double _rawCodeDot(Float32List query, Int8List codes) {
  var acc = 0.0;
  final length = codes.length;
  var i = 0;
  for (; i + 4 <= length; i += 4) {
    acc += query[i] * codes[i];
    acc += query[i + 1] * codes[i + 1];
    acc += query[i + 2] * codes[i + 2];
    acc += query[i + 3] * codes[i + 3];
  }
  for (; i < length; i++) {
    acc += query[i] * codes[i];
  }
  return acc;
}

void _keepTop(
  List<int> indexes,
  List<double> scores,
  int index,
  double score,
  int limit,
) {
  if (indexes.length < limit) {
    indexes.add(index);
    scores.add(score);
    return;
  }
  var worst = 0;
  for (var i = 1; i < scores.length; i++) {
    if (scores[i] < scores[worst]) {
      worst = i;
    }
  }
  if (score > scores[worst]) {
    indexes[worst] = index;
    scores[worst] = score;
  }
}
