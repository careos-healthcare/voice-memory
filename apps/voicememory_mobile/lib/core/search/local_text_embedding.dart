import 'dart:math' as math;
import 'dart:typed_data';

abstract interface class LocalEmbeddingDriver {
  int get dimensions;

  Float32List embed(String text);
}

/// Deterministic, on-device text features for private Archive search.
final class HashedLocalEmbeddingDriver implements LocalEmbeddingDriver {
  const HashedLocalEmbeddingDriver({this.dimensions = 384})
    : assert(dimensions > 0);

  @override
  final int dimensions;

  static final RegExp _tokenPattern = RegExp(r"[a-z0-9]+(?:'[a-z0-9]+)?");

  static const Map<String, List<String>> _semanticAliases = {
    'afraid': ['fear', 'worried'],
    'anxious': ['fear', 'worried'],
    'fear': ['afraid', 'worried'],
    'fears': ['fear', 'afraid', 'worried'],
    'worried': ['fear', 'afraid'],
    'worry': ['fear', 'worried'],
    'career': ['job', 'work', 'office', 'deadline'],
    'job': ['career', 'work', 'office'],
    'work': ['career', 'job', 'office', 'deadline'],
    'office': ['career', 'job', 'work'],
    'deadline': ['work', 'overwhelmed', 'burnout'],
    'deadlines': ['work', 'overwhelmed', 'burnout'],
    'burnout': ['burned', 'exhausted', 'drained', 'overwhelmed', 'deadline'],
    'burned': ['burnout', 'exhausted', 'drained'],
    'exhausted': ['burnout', 'drained', 'overwhelmed'],
    'drained': ['burnout', 'exhausted', 'overwhelmed'],
    'overwhelmed': ['burnout', 'exhausted', 'drained'],
    'happy': ['happiness', 'joy', 'joyful', 'content'],
    'happiness': ['happy', 'joy', 'joyful', 'content'],
    'joy': ['happy', 'happiness', 'joyful'],
    'joyful': ['happy', 'happiness', 'joy'],
    'calm': ['peaceful', 'relaxed', 'settled'],
    'calmest': ['calm', 'peaceful', 'relaxed'],
    'peaceful': ['calm', 'relaxed', 'settled'],
    'relaxed': ['calm', 'peaceful', 'settled'],
    'sad': ['sadness', 'unhappy', 'grief', 'down'],
    'saddest': ['sad', 'sadness', 'unhappy', 'grief'],
    'sadness': ['sad', 'unhappy', 'grief'],
    'coworker': ['person', 'work'],
    'friend': ['person'],
    'who': ['person'],
  };

  @override
  Float32List embed(String text) {
    final vector = Float32List(dimensions);
    final tokens = tokenize(text);
    for (final token in tokens) {
      _addFeature(vector, 'w:$token', 2);
      for (final alias in _semanticAliases[token] ?? const <String>[]) {
        _addFeature(vector, 'w:$alias', 0.75);
      }
      final padded = '^$token\$';
      for (var index = 0; index <= padded.length - 3; index++) {
        _addFeature(vector, 't:${padded.substring(index, index + 3)}', 1);
      }
    }
    var squaredNorm = 0.0;
    for (final value in vector) {
      squaredNorm += value * value;
    }
    if (squaredNorm == 0) return vector;
    final inverseNorm = 1 / math.sqrt(squaredNorm);
    for (var index = 0; index < vector.length; index++) {
      vector[index] = vector[index] * inverseNorm;
    }
    return vector;
  }

  static List<String> tokenize(String text) => List.unmodifiable(
    _tokenPattern
        .allMatches(text.toLowerCase())
        .map((match) => match.group(0)!)
        .toList(),
  );

  static Set<String> expandedTerms(String term) => {
    term.toLowerCase(),
    ...?_semanticAliases[term.toLowerCase()],
  };

  void _addFeature(Float32List vector, String feature, double weight) {
    final hash = _fnv1a(feature);
    final index = hash & 0x7fffffff;
    final sign = hash & 0x80000000 == 0 ? 1.0 : -1.0;
    vector[index % dimensions] += sign * weight;
  }

  static int _fnv1a(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }
}

abstract final class LocalVectorMath {
  static double cosineSimilarity(List<num> left, List<num> right) {
    if (left.length != right.length) {
      throw ArgumentError('Cosine vectors must have equal dimensions.');
    }
    var dot = 0.0;
    var leftNorm = 0.0;
    var rightNorm = 0.0;
    for (var index = 0; index < left.length; index++) {
      final leftValue = left[index].toDouble();
      final rightValue = right[index].toDouble();
      dot += leftValue * rightValue;
      leftNorm += leftValue * leftValue;
      rightNorm += rightValue * rightValue;
    }
    if (leftNorm == 0 || rightNorm == 0) return 0;
    return dot / (math.sqrt(leftNorm) * math.sqrt(rightNorm));
  }

  static double reciprocalRankFusion(Iterable<int> ranks, {int k = 60}) {
    if (k < 0) throw ArgumentError.value(k, 'k', 'Must be non-negative.');
    return ranks.fold(0, (score, rank) {
      if (rank < 1) {
        throw ArgumentError.value(rank, 'ranks', 'Ranks are 1-based.');
      }
      return score + 1 / (k + rank);
    });
  }
}
