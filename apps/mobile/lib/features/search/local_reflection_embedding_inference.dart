import 'dart:math';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/search/reflection_embedding_contract.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_inference.dart';
import 'package:archiveme_mobile/features/search/reflection_text_processor.dart';

/// Deterministic on-device reflection encoder when the ONNX asset is absent.
///
/// A fixed random projection over the tensor `ReflectionTextProcessor` builds,
/// which places the FNV hash of the i-th word at index i. The result is a
/// function of word *position*, not meaning: two wordings of the same thought
/// produce unrelated vectors, and the largest hash dominates. Identical text
/// still produces an identical vector, so exact-duplicate detection holds —
/// which is why [producesSemanticVectors] is the distinction that matters and
/// not "is this a real encoder".
class LocalReflectionEmbeddingInference implements ReflectionEmbeddingInference {
  LocalReflectionEmbeddingInference({Random? random})
    : _random = random ?? Random(_seed);

  static const _seed = 0x52_46_4C_43; // 'RFLC'

  @override
  bool get producesSemanticVectors => false;

  final Random _random;
  late final List<List<double>> _weights = _buildProjectionWeights();

  @override
  Future<List<double>> embed(Float32List inputTensor) async {
    if (inputTensor.length != ReflectionTextProcessor.tensorElementCount) {
      throw ArgumentError.value(
        inputTensor.length,
        'inputTensor.length',
        'expected ${ReflectionTextProcessor.tensorElementCount}',
      );
    }

    final features = inputTensor.map((value) => value.toDouble()).toList();
    final embedding = List<double>.filled(
      ReflectionEmbeddingContract.dimensions,
      0,
    );

    for (var dim = 0; dim < embedding.length; dim++) {
      var sum = 0.0;
      final row = _weights[dim];
      for (var i = 0; i < features.length; i++) {
        sum += row[i] * features[i];
      }
      embedding[dim] = sum;
    }

    return ReflectionTextProcessor.l2Normalize(embedding);
  }

  List<List<double>> _buildProjectionWeights() {
    return List.generate(ReflectionEmbeddingContract.dimensions, (_) {
      return List.generate(
        ReflectionTextProcessor.tensorElementCount,
        (_) => (_random.nextDouble() * 2) - 1,
        growable: false,
      );
    }, growable: false);
  }
}
