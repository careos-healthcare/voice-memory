import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/features/reflections/data/offline_reflection_knowledge_graph.dart';
import 'package:archiveme_mobile/services/local_llm/llama_cpp_dart_backend.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_backend.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_config.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_knowledge_graph_extractor.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_types.dart';
import 'package:archiveme_mobile/services/local_llm/stub_local_llm_backend.dart';

/// Loads GGUF models in a background llama.cpp isolate and exposes streaming
/// completions plus structured knowledge-graph extraction helpers.
final class LocalLlmService {
  LocalLlmService({
    LocalLlmBackend? backend,
  }) : _backend = backend ?? _defaultBackend();

  final LocalLlmBackend _backend;
  LocalLlmConfig? _config;

  bool get isLoaded => _backend.isLoaded;

  static LocalLlmBackend _defaultBackend() {
    return createLocalLlmBackend();
  }

  /// Creates a service when [modelPath] exists; otherwise returns null.
  static Future<LocalLlmService?> tryCreate({
    required String modelPath,
    String? libraryPath,
    LocalLlmBackend? backend,
  }) async {
    final file = File(modelPath);
    if (!await file.exists()) {
      return null;
    }

    final service = LocalLlmService(backend: backend);
    await service.loadModel(
      LocalLlmConfig.mobile(
        modelPath: modelPath,
        libraryPath: libraryPath,
        requirePreferredQuantization: false,
      ),
    );
    return service;
  }

  Future<void> loadModel(LocalLlmConfig config) async {
    _config = config;
    await _backend.load(config);
  }

  Stream<String> streamCompletion(LocalLlmCompletionRequest request) async* {
    final buffer = StringBuffer();
    await for (final event in _backend.streamCompletion(request)) {
      if (event.isFinal) {
        break;
      }
      if (event.token.isEmpty) {
        continue;
      }
      buffer.write(event.token);
      yield event.token;
    }
  }

  Future<LocalLlmCompletionResult> complete(
    LocalLlmCompletionRequest request,
  ) async {
    final buffer = StringBuffer();
    var promptId = '';
    var tokenCount = 0;

    await for (final event in _backend.streamCompletion(request)) {
      promptId = event.promptId;
      if (event.isFinal) {
        break;
      }
      if (event.token.isEmpty) {
        continue;
      }
      buffer.write(event.token);
      tokenCount++;
    }

    return LocalLlmCompletionResult(
      text: buffer.toString(),
      promptId: promptId,
      tokensUsed: tokenCount,
    );
  }

  Future<OfflineReflectionKnowledgeGraph> extractKnowledgeGraphUpdate({
    required String entryId,
    required String transcript,
    List<String> existingThemes = const [],
    LocalLlmCompletionRequest? requestOverride,
  }) async {
    final prompt = LocalLlmKnowledgeGraphExtractor.buildPrompt(
      entryId: entryId,
      transcript: transcript,
      existingThemes: existingThemes,
    );

    final completion = await complete(
      requestOverride ??
          LocalLlmCompletionRequest(
            prompt: prompt,
            maxTokens: _config?.maxTokens,
            temperature: _config?.temperature ?? 0.2,
            systemPrompt:
                'You are a structured extraction engine. Output valid JSON only.',
          ),
    );

    final update = LocalLlmKnowledgeGraphExtractor.parseGraphJson(
      entryId: entryId,
      rawCompletion: completion.text,
    );
    return update.toKnowledgeGraph();
  }

  Future<void> dispose() async {
    _config = null;
    await _backend.dispose();
  }
}
