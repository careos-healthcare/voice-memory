import 'dart:async';

import 'package:archiveme_mobile/core/execution/execution.dart';
import 'package:archiveme_mobile/core/hardware/resource_guard.dart';
import 'package:archiveme_mobile/services/ai/ai_types.dart';
import 'package:archiveme_mobile/services/ai/gemma_ai_config.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/domain/recurrent_topic_cluster.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/services/weekly_topic_synthesis_prompt.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_knowledge_graph_extractor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma_speech/flutter_gemma_speech.dart';

/// Unified on-device AI facade: LiteRT-LM entity extraction + offline STT.
///
/// All inference runs locally through flutter_gemma to avoid cloud round-trips
/// and keep battery use bounded via [ResourceGuard].
final class AIService {
  AIService({
    ResourceGuard? resourceGuard,
    LlmExecutionStrategy? llmStrategy,
  }) : _resourceGuard = resourceGuard ?? ResourceGuard.shared,
       _llmStrategy = llmStrategy ?? LlmExecutionStrategy.shared;

  final ResourceGuard _resourceGuard;
  final LlmExecutionStrategy _llmStrategy;

  static bool _gemmaInitialized = false;
  static Future<void>? _gemmaInitFuture;

  bool _modelsEnsured = false;
  Future<void>? _modelsEnsureFuture;
  Future<void> _operationTail = Future<void>.value();

  /// Whether native speech backends are available on this platform.
  static bool get supportsOfflineSpeech => !kIsWeb;

  /// Initializes flutter_gemma engines once per process.
  static Future<void> ensureGemmaInitialized() {
    if (_gemmaInitialized) {
      return Future<void>.value();
    }
    return _gemmaInitFuture ??= _initializeGemma();
  }

  static Future<void> _initializeGemma() async {
    await FlutterGemma.initialize(
      inferenceEngines: [LiteRtLmEngine()],
      sttBackends: supportsOfflineSpeech ? const [LiteRtSttBackend()] : const [],
    );
    _gemmaInitialized = true;
  }

  /// Creates a ready [AIService] after flutter_gemma registration.
  static Future<AIService> create({
    ResourceGuard? resourceGuard,
    LlmExecutionStrategy? llmStrategy,
  }) async {
    final service = AIService(
      resourceGuard: resourceGuard,
      llmStrategy: llmStrategy,
    );
    await service.ensureInitialized();
    return service;
  }

  Future<void> ensureInitialized() => ensureGemmaInitialized();

  /// Downloads / verifies moonshine STT + Gemma `.litertlm` weights if missing.
  Future<void> ensureModelsInstalled({
    AiModelInstallProgress? onProgress,
    String? huggingFaceToken,
  }) {
    return _modelsEnsureFuture ??= _ensureModelsInstalled(
      onProgress: onProgress,
      huggingFaceToken: huggingFaceToken,
    );
  }

  Future<void> _ensureModelsInstalled({
    AiModelInstallProgress? onProgress,
    String? huggingFaceToken,
  }) async {
    await ensureInitialized();

    if (supportsOfflineSpeech && FlutterGemma.activeSttSpec == null) {
      await FlutterGemma.installStt()
          .modelFromNetwork(
            GemmaAiConfig.moonshineModelUrl,
            token: huggingFaceToken,
          )
          .tokenizerFromNetwork(GemmaAiConfig.moonshineTokenizerUrl)
          .ofType(SttModelType.moonshine)
          .withModelProgress(onProgress ?? (_) {})
          .install();
    }

    if (FlutterGemma.activeModelSpec == null) {
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.litertlm,
      )
          .fromNetwork(
            GemmaAiConfig.entityExtractionModelUrl,
            token: huggingFaceToken,
          )
          .withProgress(onProgress ?? (_) {})
          .install();
    }

    _modelsEnsured = true;
  }

  /// Transcribes 16 kHz mono PCM using moonshine-tiny on-device STT.
  Future<String> transcribePcm16kMono(Uint8List pcm) async {
    if (!supportsOfflineSpeech) {
      throw UnsupportedError('Offline STT is not available on this platform.');
    }
    if (pcm.isEmpty) return '';

    return _runLlm(
      operationLabel: 'transcribe_pcm',
      action: () async {
        await ensureModelsInstalled();

        final recognizer = await FlutterGemma.getActiveStt();
        try {
          return await recognizer.transcribe(pcm);
        } finally {
          await recognizer.close();
        }
      },
    );
  }

  /// Extracts reflection entities / graph JSON from [transcript].
  Future<LocalLlmGraphUpdate> extractEntities({
    required String entryId,
    required String transcript,
    List<String> existingThemes = const [],
  }) {
    return _runLlm(
      operationLabel: 'extract_entities',
      action: () async {
        final profile = await _resourceGuard.buildInferenceProfile();
        await ensureModelsInstalled();

        final maxTokens = profile.maxTokens.clamp(
          64,
          GemmaAiConfig.defaultEntityExtractionMaxTokens,
        );

        final backend = profile.pauseEmbeddingTasks
            ? PreferredBackend.cpu
            : PreferredBackend.gpu;

        final model = await FlutterGemma.getActiveModel(
          maxTokens: GemmaAiConfig.litertlmMinContextTokens,
          preferredBackend: backend,
        );

        final prompt = LocalLlmKnowledgeGraphExtractor.buildPrompt(
          entryId: entryId,
          transcript: transcript,
          existingThemes: existingThemes,
        );

        final chat = await model.createChat(
          temperature: 0.2,
          systemInstruction:
              'You are a structured extraction engine. Output valid JSON only.',
          maxOutputTokens: maxTokens,
        );

        try {
          await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
          final response = await chat.generateChatResponse();
          final raw = switch (response) {
            TextResponse(:final token) => token,
            _ => '',
          };

          return LocalLlmKnowledgeGraphExtractor.parseGraphJson(
            entryId: entryId,
            rawCompletion: raw,
          );
        } finally {
          await chat.session.close();
        }
      },
    );
  }

  /// Synthesizes recurrent weekly topics into a short headline + summary JSON blob.
  Future<WeeklyTopicSynthesisDraft> synthesizeWeeklyTopics({
    required List<RecurrentTopicCluster> topics,
    required String weekLabel,
    bool requireInstalledModel = false,
  }) {
    return _runLlm(
      operationLabel: 'synthesize_weekly_topics',
      timeout: _llmStrategy.backgroundInferenceTimeout,
      action: () async {
        final profile = await _resourceGuard.buildInferenceProfile();
        if (requireInstalledModel) {
          if (!hasLocalGemmaModel) {
            throw StateError('GEMMA_MODEL_NOT_INSTALLED');
          }
        } else {
          await ensureModelsInstalled();
        }

        final maxTokens = profile.maxTokens.clamp(
          96,
          GemmaAiConfig.defaultEntityExtractionMaxTokens,
        );

        final backend = profile.pauseEmbeddingTasks
            ? PreferredBackend.cpu
            : PreferredBackend.gpu;

        final model = await FlutterGemma.getActiveModel(
          maxTokens: GemmaAiConfig.litertlmMinContextTokens,
          preferredBackend: backend,
        );

        final prompt = WeeklyTopicSynthesisPrompt.build(
          topics: topics,
          weekLabel: weekLabel,
        );

        final chat = await model.createChat(
          temperature: 0.3,
          systemInstruction:
              'You are a local synthesis engine. Output valid JSON only.',
          maxOutputTokens: maxTokens,
        );

        try {
          await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
          final response = await chat.generateChatResponse();
          final raw = switch (response) {
            TextResponse(:final token) => token,
            _ => '',
          };

          return WeeklyTopicSynthesisPrompt.parse(
            rawCompletion: raw,
            topics: topics,
          );
        } finally {
          await chat.session.close();
        }
      },
    );
  }

  /// True when Gemma weights are already on disk (safe for background isolate).
  static bool get hasLocalGemmaModel => FlutterGemma.activeModelSpec != null;

  /// Offline pipeline: optional STT, then on-device entity extraction.
  Future<AiCapturePipelineResult> processOfflineCapture({
    required String entryId,
    Uint8List? pcm16kMono,
    String? transcript,
    List<String> existingThemes = const [],
  }) async {
    final trimmed = transcript?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      final graph = await extractEntities(
        entryId: entryId,
        transcript: trimmed,
        existingThemes: existingThemes,
      );
      return AiCapturePipelineResult(
        entryId: entryId,
        transcript: trimmed,
        graphUpdate: graph,
        transcriptSource: AiTranscriptSource.provided,
      );
    }

    if (pcm16kMono == null || pcm16kMono.isEmpty) {
      throw ArgumentError(
        'Either transcript or pcm16kMono must be provided.',
      );
    }

    final sttTranscript = await transcribePcm16kMono(pcm16kMono);
    final graph = await extractEntities(
      entryId: entryId,
      transcript: sttTranscript,
      existingThemes: existingThemes,
    );

    return AiCapturePipelineResult(
      entryId: entryId,
      transcript: sttTranscript,
      graphUpdate: graph,
      transcriptSource: AiTranscriptSource.onDeviceStt,
    );
  }

  Future<T> _runLlm<T>({
    required String operationLabel,
    required Future<T> Function() action,
    Duration? timeout,
  }) {
    return _runSerialized(() async {
      final result = await _llmStrategy.runInference(
        operationLabel: operationLabel,
        action: action,
        timeout: timeout,
      );
      return result.when(
        success: (value) => value,
        onFailure: (failure) => throw StateError(failure.userMessage),
        onDeferred: (reason) => throw StateError(reason.userMessage),
        onCancelled: () => throw StateError('On-device analysis was cancelled.'),
      );
    });
  }

  Future<T> _runSerialized<T>(Future<T> Function() operation) {
    final run = _operationTail.then((_) => operation());
    _operationTail = run.then((_) {}, onError: (_) {});
    return run;
  }

  bool get modelsEnsured => _modelsEnsured;
}
