import 'package:archiveme_mobile/services/mesh/mesh_types.dart';

/// On-device or mesh-routed llama.cpp completion contract.
abstract interface class LlamaInference {
  Future<LlamaInferenceResponse> complete(LlamaInferenceRequest request);
}
