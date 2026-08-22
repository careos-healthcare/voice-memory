import 'dart:async';

import 'package:archiveme_mobile/core/execution/execution.dart';
import 'package:archiveme_mobile/core/hardware/resource_guard.dart';
import 'package:archiveme_mobile/features/capture/models/capture_audio_metadata.dart';
import 'package:archiveme_mobile/features/capture/storage/capture_audio_metadata_store.dart';
import 'package:archiveme_mobile/features/llm/domain/llm_feed_card_state.dart';
import 'package:archiveme_mobile/features/llm/worker/llm_background_worker.dart';
import 'package:archiveme_mobile/features/reflections/data/offline_reflection_knowledge_graph.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_knowledge_graph_extractor.dart';
import 'package:archiveme_mobile/storage/sqlite/reflection_knowledge_graph_repository.dart';
import 'package:flutter/foundation.dart';

/// Coordinates pending capture rows, isolate streaming, and graph persistence.
class LlmCaptureAnalysisService {
  LlmCaptureAnalysisService({
    required CaptureAudioMetadataStore metadataStore,
    required LlmBackgroundWorker worker,
    ReflectionKnowledgeGraphRepository? graphRepository,
    ResolveLocalLlm? resolveLocalLlm,
    ResourceGuard? resourceGuard,
    LlmExecutionStrategy? llmStrategy,
  }) : _metadataStore = metadataStore,
       _worker = worker,
       _graphRepository = graphRepository,
       _resolveLocalLlm = resolveLocalLlm,
       _resourceGuard = resourceGuard ?? ResourceGuard.shared,
       _llmStrategy = llmStrategy ?? LlmExecutionStrategy.shared;

  final CaptureAudioMetadataStore _metadataStore;
  final LlmBackgroundWorker _worker;
  final ReflectionKnowledgeGraphRepository? _graphRepository;
  final ResolveLocalLlm? _resolveLocalLlm;
  final ResourceGuard _resourceGuard;
  final LlmExecutionStrategy _llmStrategy;

  final ValueNotifier<Map<String, LlmFeedCardState>> feedStates =
      ValueNotifier(const {});

  final _tokenControllers = <String, StreamController<LlmStreamToken>>{};

  Stream<LlmStreamToken>? tokenStreamFor(String captureId) {
    return _tokenControllers[captureId]?.stream;
  }

  LlmFeedCardState stateFor(String captureId) {
    return feedStates.value[captureId] ??
        LlmFeedCardState(
          captureId: captureId,
          createdAt: DateTime.now(),
          status: LlmAnalysisStatus.pendingAnalysis,
        );
  }

  /// Seeds UI state for a freshly recorded capture row.
  void registerPendingCapture(
    CaptureAudioMetadata metadata, {
    String rawTranscript = '',
  }) {
    _updateState(
      metadata.id,
      LlmFeedCardState(
        captureId: metadata.id,
        createdAt: metadata.createdAt,
        status: LlmAnalysisStatus.pendingAnalysis,
        rawTranscript: rawTranscript,
      ),
    );
  }

  Future<void> refreshPendingCaptures() async {
    final pending = await _metadataStore.listPendingAnalysis();
    for (final row in pending) {
      registerPendingCapture(row);
    }
  }

  /// Runs STT-free analysis when [transcript] is already available.
  Future<OfflineReflectionKnowledgeGraph?> analyzeCapture({
    required CaptureAudioMetadata metadata,
    required String transcript,
    required String entryId,
    List<String> existingThemes = const [],
  }) async {
    final result = await _llmStrategy.runOrQueue(
      operationLabel: 'capture_analysis:${metadata.id}',
      action: () => _analyzeCaptureImpl(
        metadata: metadata,
        transcript: transcript,
        entryId: entryId,
        existingThemes: existingThemes,
      ),
    );
    return result.when(
      success: (graph) => graph,
      onDeferred: (_) {
        _updateState(
          metadata.id,
          stateFor(metadata.id).copyWith(
            status: LlmAnalysisStatus.pendingAnalysis,
            rawTranscript: transcript,
            errorMessage: const LlmFailureConstraints().userMessage,
          ),
        );
        return null;
      },
      onFailure: (failure) {
        _applyLlmFailure(metadata.id, transcript, failure);
        return null;
      },
      onCancelled: () => null,
    );
  }

  Future<OfflineReflectionKnowledgeGraph?> _analyzeCaptureImpl({
    required CaptureAudioMetadata metadata,
    required String transcript,
    required String entryId,
    List<String> existingThemes = const [],
  }) async {
    final captureId = metadata.id;
    await _metadataStore.updateStatus(id: captureId, status: 'processing');
    _updateState(
      captureId,
      stateFor(captureId).copyWith(
        status: LlmAnalysisStatus.processing,
        rawTranscript: transcript,
        clearError: true,
      ),
    );

    final tokenController = StreamController<LlmStreamToken>.broadcast();
    _tokenControllers[captureId] = tokenController;

    OfflineReflectionKnowledgeGraph? graph;
    try {
      final result = await _llmStrategy.runInference(
        operationLabel: 'capture_stream:$captureId',
        action: () async {
          final worker = await _resolveWorker();
          await worker.ensureStarted();
          final profile = await _resourceGuard.buildInferenceProfile();

          final stream = worker.streamKnowledgeGraphExtraction(
            captureId: captureId,
            entryId: entryId,
            transcript: transcript,
            existingThemes: existingThemes,
            maxTokens: profile.maxTokens,
          );

          OfflineReflectionKnowledgeGraph? extracted;
          await for (final token in stream) {
            tokenController.add(token);
            if (token.token.isNotEmpty || token.accumulatedText.isNotEmpty) {
              _updateState(
                captureId,
                stateFor(captureId).copyWith(
                  status: LlmAnalysisStatus.streaming,
                  streamingText: token.accumulatedText,
                ),
              );
            }
            if (token.isFinal) {
              final update = LocalLlmKnowledgeGraphExtractor.parseGraphJson(
                entryId: entryId,
                rawCompletion: token.accumulatedText,
              );
              extracted = update.toKnowledgeGraph();
              final summary = _buildSummary(update, transcript);
              final nodes = update.nodes
                  .map(
                    (node) => LlmFeedGraphNode(
                      id: node.id,
                      kind: node.kind,
                      label: node.label,
                    ),
                  )
                  .toList(growable: false);

              _updateState(
                captureId,
                stateFor(captureId).copyWith(
                  status: LlmAnalysisStatus.completed,
                  summary: summary,
                  nodes: nodes,
                  streamingText: token.accumulatedText,
                  clearError: true,
                ),
              );

              final graphRepo = _graphRepository;
              if (graphRepo != null) {
                await graphRepo.replaceGraph(extracted);
              }
              await _metadataStore.completeProcessing(captureId);
            }
          }
          return extracted;
        },
      );

      graph = result.when(
        success: (value) => value,
        onFailure: (failure) {
          _applyLlmFailure(captureId, transcript, failure);
          return null;
        },
        onDeferred: (reason) {
          _updateState(
            captureId,
            stateFor(captureId).copyWith(
              status: LlmAnalysisStatus.pendingAnalysis,
              rawTranscript: transcript,
              errorMessage: reason.userMessage,
            ),
          );
          return null;
        },
        onCancelled: () => null,
      );
    } on Object catch (error) {
      _applyLlmFailure(
        captureId,
        transcript,
        mapErrorToLlmFailure(error),
      );
      if (!tokenController.isClosed) {
        tokenController.addError(error);
      }
    } finally {
      await tokenController.close();
      _tokenControllers.remove(captureId);
    }

    return graph;
  }

  void _applyLlmFailure(
    String captureId,
    String transcript,
    ExecutionFailureState failure,
  ) {
    final llmFailure = failure is LlmExecutionFailure
        ? failure
        : mapErrorToLlmFailure(failure);
    unawaited(
      _metadataStore.updateStatus(
        id: captureId,
        status: llmFailure.shouldQueueForRetry ? 'pending_analysis' : 'error',
      ),
    );
    _updateState(
      captureId,
      stateFor(captureId).copyWith(
        status: llmFailure.analysisStatus,
        rawTranscript: transcript,
        errorMessage: llmFailure.userMessage,
      ),
    );
  }

  Future<LlmBackgroundWorker> _resolveWorker() async {
    if (_worker.isLoaded) return _worker;
    final resolver = _resolveLocalLlm;
    if (resolver == null) return _worker;
    final llm = await resolver();
    if (llm == null) return _worker;
    return _worker.attachLoadedService(llm);
  }

  String _buildSummary(LocalLlmGraphUpdate update, String transcript) {
    final parts = <String>[
      if (update.tensionOrContradiction?.trim().isNotEmpty ?? false)
        update.tensionOrContradiction!.trim(),
      if (update.nextSmallAction?.trim().isNotEmpty ?? false)
        update.nextSmallAction!.trim(),
    ];
    if (parts.isNotEmpty) return parts.join(' · ');
    final snippet = transcript.trim();
    if (snippet.isEmpty) return 'Analysis complete.';
    return snippet.length <= 160 ? snippet : '${snippet.substring(0, 157)}…';
  }

  void _updateState(String captureId, LlmFeedCardState next) {
    feedStates.value = {...feedStates.value, captureId: next};
  }

  Future<void> dispose() async {
    for (final controller in _tokenControllers.values) {
      await controller.close();
    }
    _tokenControllers.clear();
    feedStates.dispose();
  }
}
