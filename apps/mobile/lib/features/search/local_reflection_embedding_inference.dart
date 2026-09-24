import 'dart:typed_data';

import 'package:archiveme_mobile/core/execution/cancel_token.dart';
import 'package:archiveme_mobile/core/execution/isolate_compute_job.dart';
import 'package:archiveme_mobile/features/search/local_reflection_embedding_compute.dart';
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
class LocalReflectionEmbeddingInference
    implements ReflectionEmbeddingInference {
  LocalReflectionEmbeddingInference();

  @override
  bool get producesSemanticVectors => false;

  @override
  Future<List<double>> embed(
    Float32List inputTensor, {
    ExecutionCancelToken? cancelToken,
  }) {
    if (inputTensor.length != ReflectionTextProcessor.tensorElementCount) {
      throw ArgumentError.value(
        inputTensor.length,
        'inputTensor.length',
        'expected ${ReflectionTextProcessor.tensorElementCount}',
      );
    }

    return IsolateComputeJob.run<List<double>, List<double>>(
      label: 'embedding.local_projection',
      payload: inputTensor.toList(growable: false),
      computeFn: computeLocalReflectionEmbedding,
      cancelToken: cancelToken,
      throttle: IsolateJobThrottle.embedding,
    );
  }
}
