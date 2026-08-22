/// ONNX + sqlite-vec contract for on-device reflection embeddings.
abstract final class ReflectionEmbeddingContract {
  ReflectionEmbeddingContract._();

  static const defaultAssetPath = 'assets/models/reflection_encoder.onnx';
  static const inputName = 'input_ids';
  static const outputName = 'embedding';

  static const maxSeqLen = 128;
  static const dimensions = 384;
}
