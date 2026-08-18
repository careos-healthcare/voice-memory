import 'dart:async';

import 'package:archiveme_mobile/services/mesh/compute_offload_service.dart';
import 'package:archiveme_mobile/services/mesh/llama_inference.dart';
import 'package:archiveme_mobile/services/mesh/local_llama_inference.dart';
import 'package:archiveme_mobile/services/mesh/mesh_types.dart';

/// Routes llama.cpp inference to mesh desktop peers with on-device fallback.
class MeshLlamaRouter implements LlamaInference {
  MeshLlamaRouter({
    ComputeOffloadService? offloadService,
    LlamaInference? localInference,
  })  : _offloadService = offloadService ?? ComputeOffloadService(),
        _localInference = localInference ?? const LocalLlamaInference();

  final ComputeOffloadService _offloadService;
  final LlamaInference _localInference;

  @override
  Future<LlamaInferenceResponse> complete(LlamaInferenceRequest request) {
    return _offloadService.infer(
      request,
      localInference: _localInference,
    );
  }
}
