import 'dart:io';

import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_capture_api.dart';
import 'package:archiveme_mobile/features/reflections/data/local_ai_confidence.dart';
import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/reflections/data/local_ai_remote_fallback.dart';
import 'package:archiveme_mobile/features/reflections/data/local_reflection_data_source.dart';
import 'package:archiveme_mobile/features/reflections/data/local_reflection_heuristic_inference.dart';
import 'package:archiveme_mobile/features/reflections/data/offline_reflection_knowledge_graph.dart';
import 'package:archiveme_mobile/features/reflections/data/onnx_llm_reflection_extractor.dart';
import 'package:archiveme_mobile/features/reflections/data/onnx_whisper_transcription.dart';
import 'package:archiveme_mobile/features/reflections/data/whisper_audio_processor.dart';
import 'package:archiveme_mobile/services/audio_structuring/audio_structuring_service.dart';
import 'package:archiveme_mobile/workers/speech_to_text/speech_to_text_worker_service.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcript_quality.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter/foundation.dart';

export 'data/local_ai_confidence.dart';
export 'data/local_ai_remote_fallback.dart';
export 'data/onnx_llm_reflection_extractor.dart';
export 'data/onnx_whisper_transcription.dart';

/// Resolves a lazily loaded [AudioStructuringService] for offline transcript editing.
typedef AudioStructuringResolver = Future<AudioStructuringService?> Function();

/// Capture pipeline boundary for on-device STT + reflection extraction.
abstract interface class VoiceLocalAiPort {
  double get confidenceThreshold;

  Future<LocalAiPipelineResult> processAudio({
    required File audioFile,
    required int durationSeconds,
    required String entryId,
    String? captureToken,
    String? idempotencyKey,
    String? existingTranscript,
  });

  Future<LocalAiPipelineResult> processTranscript({
    required String transcript,
    required int durationSeconds,
    required String entryId,
    String? captureToken,
    String? idempotencyKey,
  });
}

/// Unified on-device intelligence pipeline:
/// 1. Whisper-tiny.en ONNX STT on audio chunks
/// 2. Lightweight LLM / logits ONNX → [ReflectionDto]
/// 3. Remote Retrofit fallback when confidence < 80%
class LocalAiPipeline implements VoiceLocalAiPort {
  LocalAiPipeline({
    required LocalReflectionExtractor reflectionExtractor,
    OnnxWhisperSpeechToText? whisper,
    LocalAiRemoteFallback? remoteFallback,
    SpeechToTextWorkerService? speechToTextWorker,
    AudioStructuringResolver? audioStructuringResolver,
    @visibleForTesting Future<WhisperTranscriptionResult?> Function(File audioFile)?
        localSttOverride,
    this.confidenceThreshold = LocalAiConfidence.remoteFallbackThreshold,
  }) : _reflectionExtractor = reflectionExtractor,
       _whisper = whisper,
       _remoteFallback = remoteFallback,
       _speechToTextWorker = speechToTextWorker ?? SpeechToTextWorkerService.instance,
       _audioStructuringResolver = audioStructuringResolver,
       _localSttOverride = localSttOverride;

  final LocalReflectionExtractor _reflectionExtractor;
  final OnnxWhisperSpeechToText? _whisper;
  final LocalAiRemoteFallback? _remoteFallback;
  final SpeechToTextWorkerService _speechToTextWorker;
  final AudioStructuringResolver? _audioStructuringResolver;
  final Future<WhisperTranscriptionResult?> Function(File audioFile)?
  _localSttOverride;

  @override
  final double confidenceThreshold;

  static Future<LocalAiPipeline> create({
    VoiceMemoryCaptureApi? remoteCaptureApi,
    LocalReflectionExtractor? reflectionExtractorOverride,
    OnnxWhisperSpeechToText? whisperOverride,
    double confidenceThreshold = LocalAiConfidence.remoteFallbackThreshold,
  }) async {
    final whisper = whisperOverride ?? await OnnxWhisperSpeechToText.tryCreate();
    final reflection =
        reflectionExtractorOverride ?? await LocalReflectionExtractor.create();
    final remote = remoteCaptureApi == null
        ? null
        : LocalAiRemoteFallback(remoteCaptureApi);

    return LocalAiPipeline(
      reflectionExtractor: reflection,
      whisper: whisper,
      remoteFallback: remote,
      confidenceThreshold: confidenceThreshold,
    );
  }

  /// Heuristic-only pipeline for offline wiring (no bundled ONNX assets required).
  static LocalAiPipeline heuristic({
    AudioStructuringResolver? audioStructuringResolver,
  }) {
    return LocalAiPipeline(
      reflectionExtractor: LocalReflectionExtractor(
        logitsSource: LocalReflectionDataSource(
          inference: const LocalReflectionHeuristicInference(),
        ),
      ),
      audioStructuringResolver: audioStructuringResolver,
    );
  }

  /// Standalone resolver for tests or tooling — loads its own GGUF copy.
  ///
  /// Production wiring should use [AppServices.resolveAudioStructuring] so
  /// audio structuring shares [AppServices.resolveLocalLlm].
  static AudioStructuringResolver audioStructuringResolverFor(
    String documentsBasePath,
  ) {
    return () => AudioStructuringService.tryCreate(
      documentsBasePath: documentsBasePath,
    );
  }

  /// Pass 1: transcribe audio. Pass 2: extract reflection. Remote fallback if low confidence.
  @override
  Future<LocalAiPipelineResult> processAudio({
    required File audioFile,
    required int durationSeconds,
    required String entryId,
    String? captureToken,
    String? idempotencyKey,
    String? existingTranscript,
  }) async {
    var transcript = existingTranscript?.trim() ?? '';
    var sttConfidence = existingTranscript != null ? 0.85 : 0.0;
    var usedLocalStt = false;

    if (transcript.isEmpty) {
      final stt = await _transcribeLocally(audioFile);
      if (stt != null && stt.transcript.trim().isNotEmpty) {
        transcript = stt.transcript.trim();
        sttConfidence = stt.confidence;
        usedLocalStt = stt.usedOnnx;
      }
    }

    if (transcript.isEmpty) {
      return _maybeRemoteFallback(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        captureToken: captureToken,
        idempotencyKey: idempotencyKey,
        reason: 'local_stt_empty',
      );
    }

    var usedLocalStructuring = false;
    if (usedLocalStt) {
      final structured = await _maybeStructureTranscript(transcript);
      if (structured != null) {
        transcript = structured;
        usedLocalStructuring = true;
      }
    }

    return _processTranscriptInternal(
      transcript: transcript,
      durationSeconds: durationSeconds,
      entryId: entryId,
      sttConfidence: sttConfidence,
      usedLocalStt: usedLocalStt,
      usedLocalStructuring: usedLocalStructuring,
      audioFile: audioFile,
      captureToken: captureToken,
      idempotencyKey: idempotencyKey,
    );
  }

  /// Reflection extraction only — for typed capture or pre-transcribed voice.
  @override
  Future<LocalAiPipelineResult> processTranscript({
    required String transcript,
    required int durationSeconds,
    required String entryId,
    String? captureToken,
    String? idempotencyKey,
  }) {
    return _processTranscriptInternal(
      transcript: transcript.trim(),
      durationSeconds: durationSeconds,
      entryId: entryId,
      sttConfidence: LocalAiConfidence.transcriptionConfidence(
        transcript: transcript,
      ),
      usedLocalStt: false,
      captureToken: captureToken,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<LocalAiPipelineResult> _processTranscriptInternal({
    required String transcript,
    required int durationSeconds,
    required String entryId,
    required double sttConfidence,
    required bool usedLocalStt,
    bool usedLocalStructuring = false,
    File? audioFile,
    String? captureToken,
    String? idempotencyKey,
  }) async {
    if (!TranscriptQuality.isUsableEvidence(transcript)) {
      return _maybeRemoteFallback(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        captureToken: captureToken,
        idempotencyKey: idempotencyKey,
        reason: 'transcript_not_usable',
        partialTranscript: transcript,
      );
    }

    final extraction = await _reflectionExtractor.extract(
      transcript: transcript,
      entryId: entryId,
    );

    final reflectionConfidence = LocalAiConfidence.reflectionConfidence(
      reflection: extraction.reflection,
      modelScore: extraction.confidence,
      usedOnnx: extraction.usedOnnx,
    );

    final overall = LocalAiConfidence.overall(
      transcription: sttConfidence > 0
          ? sttConfidence
          : LocalAiConfidence.transcriptionConfidence(transcript: transcript),
      reflection: reflectionConfidence,
    );

    final threshold = await LocalAiConfidence.effectiveRemoteFallbackThreshold();
    if (overall >= threshold) {
      return LocalAiPipelineResult(
        transcript: transcript,
        reflection: extraction.reflection,
        knowledgeGraph: extraction.knowledgeGraph,
        overallConfidence: overall,
        transcriptionConfidence: sttConfidence,
        reflectionConfidence: reflectionConfidence,
        usedLocalStt: usedLocalStt,
        usedLocalStructuring: usedLocalStructuring,
        usedLocalLlm: extraction.usedGenerativeLlm,
        usedLocalLogitsExtractor:
            extraction.usedOnnx && !extraction.usedGenerativeLlm,
        fellBackToRemote: false,
      );
    }

    return _maybeRemoteFallback(
      audioFile: audioFile,
      durationSeconds: durationSeconds,
      captureToken: captureToken,
      idempotencyKey: idempotencyKey,
      reason: 'confidence_below_threshold',
      partialTranscript: transcript,
      localReflection: extraction.reflection,
      localGraph: extraction.knowledgeGraph,
      overallConfidence: overall,
      transcriptionConfidence: sttConfidence,
      reflectionConfidence: reflectionConfidence,
      usedLocalStt: usedLocalStt,
      usedLocalStructuring: usedLocalStructuring,
      usedLocalLlm: extraction.usedGenerativeLlm,
    );
  }

  Future<String?> _maybeStructureTranscript(String rawTranscript) async {
    final resolver = _audioStructuringResolver;
    if (resolver == null) return null;

    try {
      final service = await resolver();
      if (service == null) return null;
      final result = await service.structureTranscript(rawTranscript);
      return result.structuredEntry;
    } on Object {
      return null;
    }
  }

  Future<WhisperTranscriptionResult?> _transcribeLocally(File audioFile) async {
    final override = _localSttOverride;
    if (override != null) {
      return override(audioFile);
    }

    final workerResult = await _speechToTextWorker.transcribeAudioFile(
      audioFile.path,
    );
    if (workerResult != null) {
      return workerResult;
    }

    // Fallback when the worker isolate or ONNX assets are unavailable (tests).
    final mel = WhisperAudioProcessor.buildMelFeaturesFromFile(audioFile);
    if (mel == null) return null;

    final whisper = _whisper;
    if (whisper == null) return null;
    return whisper.transcribeWavFile(mel);
  }

  Future<LocalAiPipelineResult> _maybeRemoteFallback({
    required int durationSeconds,
    String? captureToken,
    String? idempotencyKey,
    required String reason,
    File? audioFile,
    String? partialTranscript,
    ReflectionDto? localReflection,
    OfflineReflectionKnowledgeGraph? localGraph,
    double overallConfidence = 0.0,
    double transcriptionConfidence = 0.0,
    double reflectionConfidence = 0.0,
    bool usedLocalStt = false,
    bool usedLocalStructuring = false,
    bool usedLocalLlm = false,
  }) async {
    await OnDeviceProcessingStore.ensureLoaded();
    if (OnDeviceProcessingStore.enabled) {
      if (localReflection != null) {
        return LocalAiPipelineResult(
          transcript: partialTranscript ?? '',
          reflection: localReflection,
          knowledgeGraph: localGraph,
          overallConfidence: overallConfidence,
          transcriptionConfidence: transcriptionConfidence,
          reflectionConfidence: reflectionConfidence,
          usedLocalStt: usedLocalStt,
          usedLocalStructuring: usedLocalStructuring,
          usedLocalLlm: usedLocalLlm,
          usedLocalLogitsExtractor: !usedLocalLlm,
          fellBackToRemote: false,
          fallbackBlockedReason: 'on_device_processing_only',
        );
      }
      return LocalAiPipelineResult.failure(
        reason: reason,
        transcript: partialTranscript,
      );
    }

    final remote = _remoteFallback;
    if (remote == null || captureToken == null || captureToken.isEmpty) {
      if (localReflection != null) {
        return LocalAiPipelineResult(
          transcript: partialTranscript ?? '',
          reflection: localReflection,
          knowledgeGraph: localGraph,
          overallConfidence: overallConfidence,
          transcriptionConfidence: transcriptionConfidence,
          reflectionConfidence: reflectionConfidence,
          usedLocalStt: usedLocalStt,
          usedLocalStructuring: usedLocalStructuring,
          usedLocalLlm: usedLocalLlm,
          usedLocalLogitsExtractor: !usedLocalLlm,
          fellBackToRemote: false,
          fallbackBlockedReason: reason,
        );
      }
      return LocalAiPipelineResult.failure(
        reason: reason,
        transcript: partialTranscript,
      );
    }

    try {
      final remoteResult = audioFile != null
          ? await remote.transcribeAndAnalyze(
              audioFile: audioFile,
              durationSeconds: durationSeconds,
              captureToken: captureToken,
              idempotencyKey: idempotencyKey,
            )
          : await remote.analyzeTranscript(
              transcript: partialTranscript ?? '',
              durationSeconds: durationSeconds,
              captureToken: captureToken,
              idempotencyKey: idempotencyKey,
            );

      return LocalAiPipelineResult(
        transcript: remoteResult.transcript,
        reflection: remoteResult.reflection,
        overallConfidence: remoteResult.confidence,
        transcriptionConfidence: remoteResult.confidence,
        reflectionConfidence: remoteResult.confidence,
        fellBackToRemote: true,
        fallbackReason: reason,
      );
    } on Object {
      if (localReflection != null) {
        return LocalAiPipelineResult(
          transcript: partialTranscript ?? '',
          reflection: localReflection,
          knowledgeGraph: localGraph,
          overallConfidence: overallConfidence,
          transcriptionConfidence: transcriptionConfidence,
          reflectionConfidence: reflectionConfidence,
          usedLocalStt: usedLocalStt,
          usedLocalStructuring: usedLocalStructuring,
          usedLocalLlm: usedLocalLlm,
          usedLocalLogitsExtractor: !usedLocalLlm,
          fellBackToRemote: false,
          fallbackBlockedReason: 'remote_failed:$reason',
        );
      }
      return LocalAiPipelineResult.failure(
        reason: 'remote_failed:$reason',
        transcript: partialTranscript,
      );
    }
  }
}

class LocalAiPipelineResult {
  const LocalAiPipelineResult({
    required this.transcript,
    required this.reflection,
    this.knowledgeGraph,
    required this.overallConfidence,
    this.transcriptionConfidence = 0.0,
    this.reflectionConfidence = 0.0,
    this.usedLocalStt = false,
    this.usedLocalStructuring = false,
    this.usedLocalLlm = false,
    this.usedLocalLogitsExtractor = false,
    this.fellBackToRemote = false,
    this.fallbackReason,
    this.fallbackBlockedReason,
    this.reason,
  });

  const LocalAiPipelineResult.failure({
    required this.reason,
    this.transcript,
  }) : reflection = null,
       knowledgeGraph = null,
       overallConfidence = 0.0,
       transcriptionConfidence = 0.0,
       reflectionConfidence = 0.0,
       usedLocalStt = false,
       usedLocalStructuring = false,
       usedLocalLlm = false,
       usedLocalLogitsExtractor = false,
       fellBackToRemote = false,
       fallbackReason = null,
       fallbackBlockedReason = null;

  final String? transcript;
  final ReflectionDto? reflection;
  final OfflineReflectionKnowledgeGraph? knowledgeGraph;
  final double overallConfidence;
  final double transcriptionConfidence;
  final double reflectionConfidence;
  final bool usedLocalStt;
  final bool usedLocalStructuring;
  final bool usedLocalLlm;
  final bool usedLocalLogitsExtractor;
  final bool fellBackToRemote;
  final String? fallbackReason;
  final String? fallbackBlockedReason;
  final String? reason;

  bool get succeeded =>
      reflection != null && (transcript?.trim().isNotEmpty ?? false);

  Reflection? toDomainReflection() {
    final dto = reflection;
    if (dto == null) return null;
    return Reflection(
      mood: dto.mood,
      emotionalIntensity: dto.emotionalIntensity,
      recurringThemes: dto.recurringThemes,
      exactLanguagePattern: dto.exactLanguagePattern ?? '',
      concreteObservation: dto.concreteObservation ?? '',
      repeatedSignal: dto.repeatedSignal ?? '',
      tensionOrContradiction: dto.tensionOrContradiction,
      avoidedOrVagueArea: dto.avoidedOrVagueArea,
      nextSmallAction: dto.nextSmallAction,
      patternObservations: dto.patternObservations,
    );
  }
}
