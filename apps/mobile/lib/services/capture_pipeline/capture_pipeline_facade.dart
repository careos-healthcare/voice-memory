import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/core/async/keyed_async_lock.dart';
import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/features/moment_quality/post_save_moment_detail_model.dart';
import 'package:archiveme_mobile/features/moment_quality/post_save_moment_detail_service.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_dependencies.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_log.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_middleware.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_models.dart';
import 'package:fpdart/fpdart.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_proof_analyzer.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_voice_persistence.dart';
import 'package:archiveme_mobile/services/capture_pipeline/image_caption_handler.dart';
import 'package:archiveme_mobile/services/capture_pipeline/live_voice_handler.dart';
import 'package:archiveme_mobile/services/capture_pipeline/text_capture_handler.dart';
import 'package:archiveme_mobile/services/capture_pipeline/voice_capture_handler.dart';
import 'package:flutter/foundation.dart';

/// Standardized entry point orchestrating capture handlers and shared middleware.
class CapturePipelineFacade {
  /// App code should prefer [CapturePipelineFacade.standard].
  ///
  /// The primary constructor remains available for tests that inject individual
  /// handlers; production wiring should go through [standard].
  @visibleForTesting
  factory CapturePipelineFacade({
    required CapturePipelineDependencies dependencies,
    CaptureProofAnalyzer? analyzer,
    CapturePipelineMiddleware? middleware,
    VoiceCaptureHandler? voiceHandler,
    TextCaptureHandler? textHandler,
    LiveVoiceHandler? liveVoiceHandler,
    ImageCaptionHandler? imageCaptionHandler,
  }) {
    final stageController = StreamController<PipelineState>.broadcast();
    final stageEmitter = _pipelineStageEmitter(stageController);
    final resolvedAnalyzer = analyzer ?? CaptureProofAnalyzer(dependencies);
    final resolvedMiddleware =
        middleware ??
        CapturePipelineMiddleware(
          dependencies,
          resolvedAnalyzer,
          stageEmitter: stageEmitter,
        );
    final resolvedTextHandler =
        textHandler ??
        TextCaptureHandler(
          deps: dependencies,
          middleware: resolvedMiddleware,
          stageEmitter: stageEmitter,
        );
    return CapturePipelineFacade._(
      dependencies: dependencies,
      analyzer: resolvedAnalyzer,
      middleware: resolvedMiddleware,
      pipelineStateController: stageController,
      voiceHandler:
          voiceHandler ??
          VoiceCaptureHandler(
            deps: dependencies,
            middleware: resolvedMiddleware,
            stageEmitter: stageEmitter,
          ),
      textHandler: resolvedTextHandler,
      liveVoiceHandler:
          liveVoiceHandler ??
          LiveVoiceHandler(
            deps: dependencies,
            middleware: resolvedMiddleware,
            stageEmitter: stageEmitter,
          ),
      imageCaptionHandler:
          imageCaptionHandler ??
          ImageCaptionHandler(
            deps: dependencies,
            textHandler: resolvedTextHandler,
          ),
    );
  }

  /// Builds a facade with a single shared analyzer and middleware instance.
  factory CapturePipelineFacade.standard(
    CapturePipelineDependencies dependencies,
  ) {
    final stageController = StreamController<PipelineState>.broadcast();
    final stageEmitter = _pipelineStageEmitter(stageController);
    final analyzer = CaptureProofAnalyzer(dependencies);
    final middleware = CapturePipelineMiddleware(
      dependencies,
      analyzer,
      stageEmitter: stageEmitter,
    );
    final textHandler = TextCaptureHandler(
      deps: dependencies,
      middleware: middleware,
      stageEmitter: stageEmitter,
    );
    return CapturePipelineFacade._(
      dependencies: dependencies,
      analyzer: analyzer,
      middleware: middleware,
      pipelineStateController: stageController,
      voiceHandler: VoiceCaptureHandler(
        deps: dependencies,
        middleware: middleware,
        stageEmitter: stageEmitter,
      ),
      textHandler: textHandler,
      liveVoiceHandler: LiveVoiceHandler(
        deps: dependencies,
        middleware: middleware,
        stageEmitter: stageEmitter,
      ),
      imageCaptionHandler: ImageCaptionHandler(
        deps: dependencies,
        textHandler: textHandler,
      ),
    );
  }

  CapturePipelineFacade._({
    required CapturePipelineDependencies dependencies,
    required CaptureProofAnalyzer analyzer,
    required CapturePipelineMiddleware middleware,
    required StreamController<PipelineState> pipelineStateController,
    required VoiceCaptureHandler voiceHandler,
    required TextCaptureHandler textHandler,
    required LiveVoiceHandler liveVoiceHandler,
    required ImageCaptionHandler imageCaptionHandler,
  }) : _deps = dependencies,
       _analyzer = analyzer,
       _middleware = middleware,
       _pipelineStateController = pipelineStateController,
       _voiceHandler = voiceHandler,
       _textHandler = textHandler,
       _liveVoiceHandler = liveVoiceHandler,
       _imageCaptionHandler = imageCaptionHandler,
       _postSaveDetailLocks = KeyedAsyncLock();

  /// Fallback duration when watch capture does not report elapsed seconds.
  static const _watchCaptureFallbackDurationSeconds = 1;

  static PipelineStageEmitter _pipelineStageEmitter(
    StreamController<PipelineState> controller,
  ) {
    return (PipelineStage stage) {
      if (!controller.isClosed) {
        controller.add(PipelineState(stage: stage));
      }
    };
  }

  final CapturePipelineDependencies _deps;
  final CaptureProofAnalyzer _analyzer;
  final CapturePipelineMiddleware _middleware;
  final StreamController<PipelineState> _pipelineStateController;
  final VoiceCaptureHandler _voiceHandler;
  final TextCaptureHandler _textHandler;
  final LiveVoiceHandler _liveVoiceHandler;
  final ImageCaptionHandler _imageCaptionHandler;
  final KeyedAsyncLock _postSaveDetailLocks;

  /// Broadcast stream of pipeline stage progression for UI and background listeners.
  Stream<PipelineState> get pipelineStates => _pipelineStateController.stream;

  /// Closes [pipelineStates]. Call when the facade is discarded.
  void dispose() {
    if (!_pipelineStateController.isClosed) {
      _pipelineStateController.close();
    }
  }

  CapturePipelineDependencies get dependencies => _deps;
  CaptureProofAnalyzer get analyzer => _analyzer;
  CapturePipelineMiddleware get middleware => _middleware;

  @visibleForTesting
  CapturePipelineMiddleware get textHandlerMiddlewareForTest =>
      _textHandler.middlewareForTest;

  Future<CapturePipelineOutcome> run({
    required File audioFile,
    required int durationSeconds,
  }) =>
      _voiceHandler.run(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
      );

  Future<CapturePipelineOutcome> attachTypedTextToVoiceEntry({
    required JournalEntry entry,
    required String transcript,
  }) =>
      _voiceHandler.attachTypedTextToVoiceEntry(
        entry: entry,
        transcript: transcript,
      );

  Future<CapturePipelineOutcome> saveTextThought({
    required String transcript,
  }) => _textHandler.saveTextThought(transcript: transcript);

  Future<CapturePipelineOutcome> saveLiveVoiceTranscript({
    required String transcript,
    required int durationSeconds,
  }) =>
      _liveVoiceHandler.saveLiveVoiceTranscript(
        transcript: transcript,
        durationSeconds: durationSeconds,
      );

  Future<CapturePipelineOutcome> saveImageCaptionEntry({
    required String caption,
    required ImageEvidence imageEvidence,
  }) =>
      _imageCaptionHandler.saveImageCaptionEntry(
        caption: caption,
        imageEvidence: imageEvidence,
      );

  Future<CapturePipelineOutcome> saveRecoveredVaultEntry({
    required String transcript,
    required Map<String, dynamic> reflectionJson,
    required int durationSeconds,
    required bool remoteProcessingConsented,
  }) =>
      _liveVoiceHandler.saveRecoveredVaultEntry(
        transcript: transcript,
        reflectionJson: reflectionJson,
        durationSeconds: durationSeconds,
        remoteProcessingConsented: remoteProcessingConsented,
      );

  Future<CapturePipelineOutcome> runWatchCapture({
    required String audioFilePath,
    int? durationSeconds,
  }) =>
      run(
        audioFile: File(audioFilePath),
        durationSeconds:
            durationSeconds ?? _watchCaptureFallbackDurationSeconds,
      );

  /// Saves or updates a linked local detail entry — no network, no parent overwrite.
  Future<PostSaveMomentDetailOutcome> savePostSaveMomentDetail({
    required JournalEntry parentEntry,
    required PostSaveMomentDetailType detailType,
    required String detailText,
  }) async {
    final trimmed = detailText.trim();
    if (trimmed.isEmpty) {
      return Left(CapturePipelineFailure('Enter a thought before saving.'));
    }

    final lockKey =
        '${parentEntry.id}:${detailType.analyticsValue}';
    return _postSaveDetailLocks.runLocked(
      lockKey,
      () => _savePostSaveMomentDetailLocked(
        parentEntry: parentEntry,
        detailType: detailType,
        detailText: trimmed,
      ),
    );
  }

  Future<PostSaveMomentDetailOutcome> _savePostSaveMomentDetailLocked({
    required JournalEntry parentEntry,
    required PostSaveMomentDetailType detailType,
    required String detailText,
  }) async {
    final tag = PostSaveMomentDetailType.linkedCaptureContextTag(
      type: detailType,
      parentEntryId: parentEntry.id,
    );

    try {
      final existing = await _deps.journalStore.findByCaptureContextTag(tag);

      if (existing != null) {
        final updated = buildLinkedDetailEntry(
          existing: existing,
          detailText: detailText,
        );
        await _deps.journalStore.save(
          updated,
          first25Source: DatabaseConstants.first25SourcePostSaveDetailUpdate,
          captureKind: DatabaseConstants.captureKindTypedAttach,
        );
        return Right(updated);
      }

      final entry = buildNewLinkedDetailEntry(
        id: JournalSyncIds.newOfflineEntryId(),
        parentEntryId: parentEntry.id,
        detailType: detailType,
        detailText: detailText,
        durationSeconds: CaptureVoicePersistence.estimatedDurationSeconds(
          detailText,
        ),
      );
      await _deps.journalStore.save(
        entry,
        first25Source: DatabaseConstants.first25SourcePostSaveDetail,
        captureKind: DatabaseConstants.captureKindTypedAttach,
      );
      return Right(entry);
    } catch (e, stackTrace) {
      CapturePipelineLog.postSaveMomentDetailFailed(
        error: e,
        stackTrace: stackTrace,
      );
      return Left(
        CapturePipelineFailure(
          VoiceCaptureCopy.saveFailed,
          cause: e,
          innerException: e,
        ),
      );
    }
  }
}
