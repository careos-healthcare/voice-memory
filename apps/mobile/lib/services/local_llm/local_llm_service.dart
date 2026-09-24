import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:archiveme_mobile/core/execution/cancel_token.dart';
import 'package:archiveme_mobile/core/execution/isolate_compute_job.dart';
import 'package:archiveme_mobile/core/execution/llm_execution_strategy.dart';
import 'package:archiveme_mobile/core/hardware/resource_guard.dart';
import 'package:archiveme_mobile/features/reflections/data/offline_reflection_knowledge_graph.dart';
import 'package:archiveme_mobile/services/local_llm/llama_cpp_dart_backend.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_backend.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_config.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_knowledge_graph_extractor.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_types.dart';

/// Loads GGUF models in a background llama.cpp isolate and exposes streaming
/// completions plus structured knowledge-graph extraction helpers.
final class LocalLlmService {
  LocalLlmService({
    LocalLlmBackend? backend,
    LlmExecutionStrategy? executionStrategy,
    ResourceGuard? resourceGuard,
  }) : _backend = backend ?? _defaultBackend(),
       _executionStrategy = executionStrategy,
       _resourceGuard = resourceGuard;

  final LocalLlmBackend _backend;
  final LlmExecutionStrategy? _executionStrategy;
  final ResourceGuard? _resourceGuard;
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

  Stream<String> streamCompletion(
    LocalLlmCompletionRequest request, {
    ExecutionCancelToken? cancelToken,
  }) async* {
    cancelToken?.throwIfCancelled();
    final buffer = StringBuffer();
    await for (final event in _backend.streamCompletion(request)) {
      if (cancelToken?.isCancelled ?? false) {
        await _backend.cancelGeneration();
        throw ExecutionCancelledException();
      }
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
    LocalLlmCompletionRequest request, {
    ExecutionCancelToken? cancelToken,
  }) async {
    final capped = await _capRequest(request);
    final strategy = _executionStrategy ?? LlmExecutionStrategy.shared;

    final outcome = await IsolateJobThrottle.llm.run(
      () {
        return IsolateComputeJob.trace(
          'llm.complete',
          () => strategy.runInference(
            operationLabel: 'local_llm.complete',
            cancelToken: cancelToken,
            requireCanExecute: _resourceGuard != null,
            allowDeferredQueue: _resourceGuard != null,
            action: () => _collectCompletion(capped, cancelToken),
          ),
        );
      },
      cancelToken: cancelToken,
    );

    return outcome.when(
      success: (value) => value,
      onFailure: (failure) => throw StateError(failure.code),
      onDeferred: (reason) =>
          throw LocalInferenceDeferredException(reason.code),
      onCancelled: () => throw ExecutionCancelledException(),
    );
  }

  Future<OfflineReflectionKnowledgeGraph> extractKnowledgeGraphUpdate({
    required String entryId,
    required String transcript,
    List<String> existingThemes = const [],
    LocalLlmCompletionRequest? requestOverride,
    ExecutionCancelToken? cancelToken,
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
      cancelToken: cancelToken,
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

  Future<LocalLlmCompletionRequest> _capRequest(
    LocalLlmCompletionRequest request,
  ) async {
    final guard = _resourceGuard;
    if (guard == null) return request;
    final profile = await guard.buildInferenceProfile();
    final configured = request.maxTokens ?? _config?.maxTokens;
    final maxTokens = configured == null
        ? profile.maxTokens
        : math.min(configured, profile.maxTokens);
    return LocalLlmCompletionRequest(
      prompt: request.prompt,
      maxTokens: maxTokens,
      temperature: request.temperature,
      systemPrompt: request.systemPrompt,
    );
  }

  Future<LocalLlmCompletionResult> _collectCompletion(
    LocalLlmCompletionRequest request,
    ExecutionCancelToken? cancelToken,
  ) async {
    final buffer = StringBuffer();
    var promptId = '';
    var tokenCount = 0;

    await for (final event in _backend.streamCompletion(request)) {
      if (cancelToken?.isCancelled ?? false) {
        await _backend.cancelGeneration();
        throw ExecutionCancelledException();
      }
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
}
