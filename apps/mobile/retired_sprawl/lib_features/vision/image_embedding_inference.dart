import 'dart:typed_data';

/// Computes a fixed-width embedding from a preprocessed NCHW vision tensor.
abstract interface class ImageEmbeddingInference {
  Future<List<double>> embed(Float32List nchwTensor);
}
