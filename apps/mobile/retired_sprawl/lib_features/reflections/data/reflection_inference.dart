import 'dart:typed_data';

/// Abstraction over ONNX and heuristic reflection extractors.
abstract class ReflectionInference {
  Future<List<double>> runReflectionLogits(Float32List inputTensor);
}
