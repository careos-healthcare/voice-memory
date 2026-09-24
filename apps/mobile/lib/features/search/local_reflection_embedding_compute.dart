import 'dart:math';

import 'package:archiveme_mobile/features/search/reflection_embedding_contract.dart';
import 'package:archiveme_mobile/features/search/reflection_text_processor.dart';

/// Deterministic seed matching [LocalReflectionEmbeddingInference].
const localReflectionEmbeddingSeed = 0x52_46_4C_43; // 'RFLC'

/// Random-projection embed used when the ONNX encoder is absent.
///
/// Top-level so [Isolate.run] / [compute] can serialize the tear-off. Weights
/// are rebuilt from [localReflectionEmbeddingSeed] inside the isolate.
List<double> computeLocalReflectionEmbedding(List<double> features) {
  if (features.length != ReflectionTextProcessor.tensorElementCount) {
    throw ArgumentError.value(
      features.length,
      'features.length',
      'expected ${ReflectionTextProcessor.tensorElementCount}',
    );
  }

  final random = Random(localReflectionEmbeddingSeed);
  final embedding = List<double>.filled(
    ReflectionEmbeddingContract.dimensions,
    0,
  );

  for (var dim = 0; dim < embedding.length; dim++) {
    var sum = 0.0;
    for (var i = 0; i < features.length; i++) {
      final weight = (random.nextDouble() * 2) - 1;
      sum += weight * features[i];
    }
    embedding[dim] = sum;
  }

  return ReflectionTextProcessor.l2Normalize(embedding);
}
