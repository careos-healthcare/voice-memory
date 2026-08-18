import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:archiveme_mobile/services/mesh/llama_inference.dart';
import 'package:archiveme_mobile/services/mesh/mesh_types.dart';

/// Deterministic on-device llama.cpp stand-in until native FFI is wired.
///
/// Produces stable pseudo-completions from the prompt hash so tests and the
/// existing capture pipeline can exercise the inference contract offline.
class LocalLlamaInference implements LlamaInference {
  const LocalLlamaInference();

  @override
  Future<LlamaInferenceResponse> complete(LlamaInferenceRequest request) async {
    final prompt = request.prompt.trim();
    if (prompt.isEmpty) {
      return const LlamaInferenceResponse(
        text: '',
        route: LlamaInferenceRoute.onDevice,
        tokensUsed: 0,
      );
    }

    final digest = sha256.convert(utf8.encode(prompt)).toString();
    final tokenBudget = request.maxTokens.clamp(1, 512);
    final snippet = digest.substring(0, 16);
    final text = '[local-llama:$snippet] ${prompt.length > 64 ? '${prompt.substring(0, 64)}…' : prompt}';

    return LlamaInferenceResponse(
      text: text,
      route: LlamaInferenceRoute.onDevice,
      tokensUsed: tokenBudget ~/ 4,
    );
  }
}
