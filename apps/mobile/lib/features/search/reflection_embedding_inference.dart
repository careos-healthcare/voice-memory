import 'dart:typed_data';

/// Abstraction over ONNX and deterministic reflection encoders.
abstract class ReflectionEmbeddingInference {
  Future<List<double>> embed(Float32List inputTensor);
}
