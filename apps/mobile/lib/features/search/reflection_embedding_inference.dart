import 'dart:typed_data';

/// Abstraction over ONNX and deterministic reflection encoders.
abstract class ReflectionEmbeddingInference {
  Future<List<double>> embed(Float32List inputTensor);

  /// Whether [embed] output carries meaning rather than only identity.
  ///
  /// False for the deterministic stand-in used when no encoder asset ships:
  /// its output is stable enough for exact-duplicate detection and useless for
  /// similarity. Read it through `SemanticVectorFusion` rather than branching
  /// on the concrete type.
  bool get producesSemanticVectors;
}
