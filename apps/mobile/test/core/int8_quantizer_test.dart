import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/core/database/benchmark_seeder_isolate.dart';
import 'package:archiveme_mobile/core/vectors/int8_quantizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('int8 payload is 384 bytes and float32 payload is 1536', () {
    expect(benchmarkEmbeddingDimensions, 384);
    final values = Float32List(benchmarkEmbeddingDimensions);
    fillBenchmarkVector(values, 4);
    expect(values.lengthInBytes, float32EmbeddingBytes);
    expect(values.lengthInBytes, 1536);

    final quantized = quantizeSymmetric(values);
    expect(quantized.codes.length, benchmarkEmbeddingDimensions);
    expect(quantized.payloadBytes, int8EmbeddingBytes);
    expect(quantized.payloadBytes, 384);
    expect(quantized.alpha, inInclusiveRange(0, 1));
    expect(quantized.alpha, greaterThan(0));
  });

  test('symmetric codes stay inside -127..127 and round-trip the scale', () {
    final values = Float32List(benchmarkEmbeddingDimensions);
    fillBenchmarkVector(values, 12);
    values[0] = 2;
    values[1] = -2;
    final quantized = quantizeSymmetric(values);
    expect(quantized.alpha, lessThanOrEqualTo(1));
    for (final code in quantized.codes) {
      expect(code, inInclusiveRange(-symmetricInt8Max, symmetricInt8Max));
    }

    final restored = quantized.dequantize();
    final clipped = Float32List(values.length);
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      clipped[i] = value > 1 ? 1 : (value < -1 ? -1 : value);
    }
    expect(_cosine(clipped, restored), greaterThan(0.98));

    var expectedSelfDot = 0;
    for (final code in quantized.codes) {
      expectedSelfDot += code * code;
    }
    expect(int8Dot(quantized.codes, quantized.codes), expectedSelfDot);
    expect(
      asymmetricDot(clipped, quantized),
      closeTo(_dot(clipped, restored), 1e-5),
    );
  });

  test(
    'int8 search keeps at least 98% of the float32 top-10 on 10000 entries',
    () {
      const groups = 1000;
      const perGroup = 10;
      const entryCount = groups * perGroup;
      expect(entryCount, 10000);

      final documents = <Float32List>[];
      final quantized = <Int8Embedding>[];
      for (var group = 0; group < groups; group++) {
        final center = Float32List(benchmarkEmbeddingDimensions);
        fillBenchmarkVector(center, group + 1);
        for (var slot = 0; slot < perGroup; slot++) {
          final member = _member(center, group, slot);
          documents.add(member);
          final embedding = quantizeSymmetric(member);
          expect(embedding.payloadBytes, 384);
          quantized.add(embedding);
        }
      }

      final corpus = Int8Corpus(quantized);
      const queryGroups = 20;
      var recallSum = 0.0;
      for (var sample = 0; sample < queryGroups; sample++) {
        final group = sample * (groups ~/ queryGroups);
        final query = Float32List(benchmarkEmbeddingDimensions);
        fillBenchmarkVector(query, group + 1);
        final truth = _floatTop(query, documents, 10);
        final expected = <int>{
          for (var slot = 0; slot < perGroup; slot++) group * perGroup + slot,
        };
        expect(truth.toSet(), expected);

        final hits = corpus.search(query);
        expect(hits, hasLength(10));
        var overlap = 0;
        for (final hit in hits) {
          if (truth.contains(hit.index)) {
            overlap += 1;
          }
        }
        recallSum += overlap / 10;
        expect(
          hits.first.similarity,
          closeTo(asymmetricCosine(query, quantized[hits.first.index]), 1e-9),
        );
      }

      final recallAt10 = recallSum / queryGroups;
      expect(recallAt10, greaterThanOrEqualTo(0.98));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Float32List _member(Float32List center, int group, int slot) {
  final values = Float32List.fromList(center);
  var state = (group + 1) * 0x85EBCA6B + (slot + 1) * 0xC2B2AE35;
  for (var i = 0; i < values.length; i++) {
    state = (1664525 * state + 1013904223) & 0x7fffffff;
    values[i] += ((state / 0x7fffffff) * 2 - 1) * 0.02;
  }
  var sumSquares = 0.0;
  for (final value in values) {
    sumSquares += value * value;
  }
  final inverse = 1 / math.sqrt(sumSquares);
  for (var i = 0; i < values.length; i++) {
    values[i] = values[i] * inverse;
  }
  return values;
}

List<int> _floatTop(Float32List query, List<Float32List> documents, int limit) {
  final indexes = <int>[];
  final scores = <double>[];
  for (var index = 0; index < documents.length; index++) {
    final score = _dot(query, documents[index]);
    if (indexes.length < limit) {
      indexes.add(index);
      scores.add(score);
      continue;
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
  return indexes;
}

double _cosine(Float32List left, Float32List right) {
  final dot = _dot(left, right);
  final leftNorm = math.sqrt(_dot(left, left));
  final rightNorm = math.sqrt(_dot(right, right));
  if (leftNorm == 0 || rightNorm == 0) {
    return 0;
  }
  return dot / (leftNorm * rightNorm);
}

double _dot(Float32List left, Float32List right) {
  var sum = 0.0;
  for (var i = 0; i < left.length; i++) {
    sum += left[i] * right[i];
  }
  return sum;
}
