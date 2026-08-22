import 'dart:io';

import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/core/network/capture_pipeline_api_errors.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_consent_boundary.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/features/reflections/data/local_ai_confidence.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/features/voice_capture/analysis/analysis_log.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_log.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_service.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/models/transcript_provenance.dart';
import 'package:archiveme_mobile/models/transcript_status.dart';
import 'package:archiveme_mobile/security/account_session_guard.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_dependencies.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_middleware.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_models.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_voice_persistence.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/services/record_pipeline_log.dart';

/// [usedOnnx] is nullable because "we did not run ONNX" and "we make no claim
/// about where this was processed" are different, and the entry-detail chip
/// reads the flag as though it were the second: null renders nothing, true
/// renders "Processed on your device", and false renders "Sent securely for
/// higher-accuracy processing". A `SFSpeechRecognizer` transcript is neither
/// ONNX nor sent anywhere, so it passes null rather than claiming an upload
/// that did not happen. See the reported fix to `EntryProcessingTrustChip`,
/// which should read `processingUsedLocalStt` too.
JournalProofData processingProofFlags({
  required bool? usedOnnx,
  bool usedLocalStt = false,
  bool usedGenerativeLlm = false,
}) {
  return JournalProofData(
    processingUsedOnnx: usedOnnx,
    processingUsedLocalStt: usedLocalStt,
    processingUsedGenerativeLlm: usedGenerativeLlm,
  );
}

class VoiceCaptureHandler {
  VoiceCaptureHandler({
    required CapturePipelineDependencies deps,
    required CapturePipelineMiddleware middleware,
    CaptureVoicePersistence? persistence,
    PipelineStageEmitter stageEmitter = noopPipelineStage,
  }) : _deps = deps,
       _middleware = middleware,
       _persistence = persistence ?? CaptureVoicePersistence(deps),
       _stageEmitter = stageEmitter;

  final CapturePipelineDependencies _deps;
  final CapturePipelineMiddleware _middleware;
  final CaptureVoicePersistence _persistence;
  final PipelineStageEmitter _stageEmitter;

  Future<CapturePipelineOutcome> run({
    required File audioFile,
    required int durationSeconds,
  }) async {
    final session = _deps.sessionGuardFactory();
    final exists = audioFile.existsSync();
    final byteLength = exists ? audioFile.lengthSync() : 0;
    RecordPipelineLog.audioFile(
      path: audioFile.path,
      exists: exists,
      byteLength: byteLength,
    );
    if (!exists || byteLength < VoiceCaptureQuality.minAudioBytes) {
      RecordPipelineLog.rejectInsufficientAudio(byteLength: byteLength);
      return pipelineFailure(
        CapturePipelineFailure(VoiceCaptureCopy.notEnoughAudio),
      );
    }

    String? partialTranscript;
    Reflection? localReflection;
    final scopeKey = CaptureVoicePersistence.audioScopeKey(
      audioFile.path,
      durationSeconds,
    );
    final entryId = JournalSyncIds.newOfflineEntryId();
    try {
      final localPreflight = await _attemptLocalAiPipeline(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        entryId: entryId,
        session: session,
      );
      if (localPreflight.completed != null) {
        return localPreflight.completed!;
      }
      partialTranscript = localPreflight.transcript;
      localReflection = localPreflight.reflection;

      if (!CaptureVoicePersistence.hasUsableTranscript(partialTranscript)) {
        // Before any consideration of the network. The bundled Whisper ONNX
        // asset the step above wants is not in the build, so on a default iOS
        // install this is the only thing that can produce a transcript, and it
        // used to run only after a remote request had already failed.
        partialTranscript = await _attemptOnDeviceSpeech(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          scopeKey: scopeKey,
        );
      }

      final hasLocalTranscript =
          CaptureVoicePersistence.hasUsableTranscript(partialTranscript);

      if (!hasLocalTranscript &&
          !await _middleware.isPurposeGranted(
            RemoteProcessingPurpose.remoteTranscription,
          )) {
        const reason = 'remote_processing_consent_missing';
        _middleware.logApiGuardBlocked(operation: 'transcribe', reason: reason);
        return _saveLocalOnly(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          syncNote: VoiceCaptureCopy.remoteProcessingConsentPausedNote,
          transcriptionFailureReason: reason,
          partialTranscript: partialTranscript,
          localReflection: localReflection,
        );
      }

      if (!hasLocalTranscript) {
        _stageEmitter(PipelineStage.attesting);
        await _middleware.ensureCaptureToken();

        _stageEmitter(PipelineStage.transcribing);
        await BetaAnalyticsConsentBoundary.auditRemoteAttempt(
          purpose: RemoteProcessingPurpose.remoteTranscription,
          permitted: true,
        );
        final transcription = await TranscriptionService.transcribeRecording(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          captureRepository: _deps.captureRepository,
          ensureCaptureToken: _deps.attest.ensureCaptureToken,
          scopeKey: scopeKey,
          usageGuard: _deps.usageGuard,
          // The remote path, reached only with transcription consent granted
          // and on-device-only off. The locale still travels, because a
          // permitted upload that finds the network gone falls back to the same
          // native recogniser and needs to know what language to expect.
          speechLocale: await _readConfirmedSpeechLocale(),
          onDeviceOnly: false,
        );

        if (!transcription.succeeded) {
          final reason =
              transcription.skippedReason ??
              transcription.failureReason ??
              'transcription_unavailable';
          if (reason.startsWith('low_quality:')) {
            return _saveLocalOnly(
              audioFile: audioFile,
              durationSeconds: durationSeconds,
              syncNote: VoiceCaptureCopy.lowQualityTranscriptIssue,
              transcriptionFailureReason: reason,
              lowQualityTranscript: true,
              partialTranscript: partialTranscript,
              localReflection: localReflection,
            );
          }
          _middleware.logApiGuardBlocked(operation: 'transcribe', reason: reason);
          return _saveLocalOnly(
            audioFile: audioFile,
            durationSeconds: durationSeconds,
            syncNote: VoiceCaptureCopy.transcriptionFailedDegraded,
            transcriptionFailureReason: reason,
            partialTranscript: partialTranscript,
            localReflection: localReflection,
          );
        }

        partialTranscript = transcription.transcript;

        if (transcription.isProvisional) {
          final uploadPath = transcription.uploadAudioPath;
          final resolvedAudio = uploadPath != null && uploadPath.isNotEmpty
              ? File(uploadPath)
              : audioFile;
          return _saveProvisionalNativeTranscript(
            audioFile: resolvedAudio,
            durationSeconds: durationSeconds,
            transcript: partialTranscript!.trim(),
          );
        }
      } else {
        RecordPipelineLog.transcriptionFallback(
          reason: 'local_ai_transcript',
          audioPath: audioFile.path,
        );
      }

      final trimmedTranscript = partialTranscript!.trim();
      RecordPipelineLog.transcriptLengths(
        transcriptLength: trimmedTranscript.length,
        bodyLength: trimmedTranscript.length,
        observationLength: 0,
        exactLanguageLength: 0,
      );

      if (trimmedTranscript.isEmpty) {
        const reason = 'empty_transcript';
        TranscriptionLog.failed(reason: reason);
        return _saveLocalOnly(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          syncNote: CaptureSaveMessages.syncUnavailableOffline,
          transcriptionFailureReason: reason,
          localReflection: localReflection,
        );
      }

      _stageEmitter(PipelineStage.analyzing);
      if (!await _middleware.isPurposeGranted(
        RemoteProcessingPurpose.remoteReflection,
      )) {
        const reason = 'remote_processing_consent_missing';
        _middleware.logApiGuardBlocked(operation: 'analyze', reason: reason);
        return _saveAfterAnalysisFailure(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          transcript: trimmedTranscript,
          reason: reason,
          syncNote: VoiceCaptureCopy.remoteProcessingConsentPausedNote,
          localReflection: localReflection,
        );
      }

      try {
        final verifiedProof = await _middleware.analyzeWithAuthRetry(
          transcript: trimmedTranscript,
          scopeKey: scopeKey,
          entryId: entryId,
          sourceType: ProofSourceType.userVoiceTranscript,
          attestFirst: !hasLocalTranscript,
        );
        return _saveAnalyzedVoiceEntry(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          trimmedTranscript: trimmedTranscript,
          verifiedProof: verifiedProof,
          entryId: entryId,
          session: session,
        );
      } on AnalyzeBlockedException catch (e, stackTrace) {
        return _saveAfterAnalysisFailure(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          transcript: trimmedTranscript,
          reason: e.reason,
          localReflection: localReflection,
        );
      } catch (e, stackTrace) {
        return _saveAfterAnalysisFailure(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          transcript: trimmedTranscript,
          error: e,
          localReflection: localReflection,
        );
      }
    } catch (e, stackTrace) {
      return _handleVoiceCaptureFailure(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        partialTranscript: partialTranscript,
        localReflection: localReflection,
        error: e,
      );
    }
  }

  /// Platform speech recognition, when the customer asked for on-device only.
  ///
  /// Returns null — meaning "no transcript" and never a guess — when the
  /// setting is off, when this platform has no recogniser, or when nobody has
  /// confirmed which language the recording is in. The last case is the one
  /// worth being strict about: `SFSpeechRecognizer` pointed at the wrong
  /// language does not error, it returns fluent text in that language, and the
  /// archive later quotes it back as the customer's own words.
  Future<String?> _attemptOnDeviceSpeech({
    required File audioFile,
    required int durationSeconds,
    required String scopeKey,
  }) async {
    await OnDeviceProcessingStore.ensureLoaded();
    if (!OnDeviceProcessingStore.enabled) return null;

    final ConfirmedSpeechLocale? speechLocale =
        await _readConfirmedSpeechLocale();

    _stageEmitter(PipelineStage.transcribing);
    final outcome = await TranscriptionService.transcribeRecording(
      audioFile: audioFile,
      durationSeconds: durationSeconds,
      captureRepository: _deps.captureRepository,
      ensureCaptureToken: _deps.attest.ensureCaptureToken,
      scopeKey: scopeKey,
      usageGuard: _deps.usageGuard,
      speechLocale: speechLocale,
      onDeviceOnly: true,
    );

    if (!outcome.succeeded) {
      RecordPipelineLog.transcriptionFallback(
        reason: outcome.skippedReason ??
            outcome.failureReason ??
            'on_device_stt_unavailable',
        audioPath: audioFile.path,
      );
      return null;
    }
    return outcome.transcript;
  }

  Future<ConfirmedSpeechLocale?> _readConfirmedSpeechLocale() async {
    final reader = _deps.speechLocale;
    if (reader == null) return null;
    try {
      return await reader();
    } on Object {
      // ignore: silent_catch_audit — an unreadable preference is not a
      // confirmed language, and the safe reading of "unknown" is "do not
      // transcribe", not "assume the phone's language".
      return null;
    }
  }

  Future<({
    CapturePipelineOutcome? completed,
    String? transcript,
    Reflection? reflection,
  })> _attemptLocalAiPipeline({
    required File audioFile,
    required int durationSeconds,
    required String entryId,
    required AccountSessionGuard session,
  }) async {
    final pipeline = _deps.localAiPipeline;
    if (pipeline == null) {
      return (completed: null, transcript: null, reflection: null);
    }

    _stageEmitter(PipelineStage.transcribing);
    RecordPipelineLog.transcriptionFallback(
      reason: 'local_ai_pipeline_first',
      audioPath: audioFile.path,
    );

    final local = await pipeline.processAudio(
      audioFile: audioFile,
      durationSeconds: durationSeconds,
      entryId: entryId,
    );

    final reflection = local.toDomainReflection();
    final confidenceThreshold =
        await LocalAiConfidence.effectiveRemoteFallbackThreshold();
    if (local.succeeded &&
        local.overallConfidence >= confidenceThreshold &&
        reflection != null &&
        CaptureVoicePersistence.hasUsableTranscript(local.transcript)) {
      final completed = await _saveLocallyAnalyzedVoiceEntry(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        trimmedTranscript: local.transcript!.trim(),
        reflection: reflection,
        entryId: entryId,
        session: session,
        usedLocalStt: local.usedLocalStt,
        usedLocalLlm: local.usedLocalLlm,
        usedLocalStructuring: local.usedLocalStructuring,
      );
      return (
        completed: completed,
        transcript: local.transcript,
        reflection: reflection,
      );
    }

    return (
      completed: null,
      transcript: local.transcript,
      reflection: reflection,
    );
  }

  Future<CapturePipelineOutcome> _saveLocallyAnalyzedVoiceEntry({
    required File audioFile,
    required int durationSeconds,
    required String trimmedTranscript,
    required Reflection reflection,
    required String entryId,
    required AccountSessionGuard session,
    required bool usedLocalStt,
    required bool usedLocalLlm,
    bool usedLocalStructuring = false,
  }) async {
    RecordPipelineLog.analysisFallback(
      reason: usedLocalStructuring
          ? 'local_ai_stt_structured_reflection'
          : usedLocalStt && usedLocalLlm
          ? 'local_ai_stt_and_reflection'
          : usedLocalLlm
          ? 'local_ai_reflection'
          : 'local_ai_pipeline',
      audioPath: audioFile.path,
    );
    RecordPipelineLog.transcriptLengths(
      transcriptLength: trimmedTranscript.length,
      bodyLength: trimmedTranscript.length,
      observationLength: reflection.concreteObservation.trim().length,
      exactLanguageLength: reflection.exactLanguagePattern.trim().length,
    );

    _stageEmitter(PipelineStage.saving);
    session.assertActive();
    final finalTranscript =
        resolveFinalCaptureTranscript(transcript: trimmedTranscript) ??
        trimmedTranscript;
    RecordPipelineLog.preSaveFinalTranscript(length: finalTranscript.length);
    if (usedLocalStructuring) {
      _deps.reflectionEmbeddingIndexWorker?.stageLlmSummary(
        entryId: entryId,
        llmSummary: trimmedTranscript,
      );
    }
    final template = JournalEntry(
      id: entryId,
      createdAt: DateTime.now().toUtc(),
      transcript: trimmedTranscript,
      durationSeconds: durationSeconds,
      reflection: reflection,
      syncStatus: SyncStatus.pendingUpload,
      localAudioPath: audioFile.path,
      transcriptStatus: TranscriptStatus.finalTranscript,
      proof: processingProofFlags(
        usedOnnx: usedLocalStt || usedLocalLlm,
        usedLocalStt: usedLocalStt,
        usedGenerativeLlm: usedLocalLlm,
      ),
    );
    final prepared = applyFinalTranscriptToVoiceEntry(
      template,
      finalTranscript: finalTranscript,
      provenance: TranscriptProvenance.speechToText,
    );
    final entry = await _persistence.saveVoiceEntryAndLog(
      prepared,
      first25Source: 'local_ai_voice_capture',
      session: session,
    );
    _middleware.clearCaptureToken();
    _stageEmitter(PipelineStage.done);
    return pipelineSuccess(CapturePipelineResult(
      entry: entry,
      localSaved: true,
      syncSucceeded: false,
      analysisSucceeded: true,
    ));
  }

  Future<CapturePipelineOutcome> attachTypedTextToVoiceEntry({
    required JournalEntry entry,
    required String transcript,
  }) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      return pipelineFailure(
        CapturePipelineFailure('Enter what you said before saving.'),
      );
    }

    final scopeKey = 'entry:${entry.id}';
    try {
      if (!await _middleware.isPurposeGranted(
        RemoteProcessingPurpose.remoteReflection,
      )) {
        return _attachTypedTextLocally(
          entry: entry,
          trimmed: trimmed,
          syncNote: VoiceCaptureCopy.remoteProcessingConsentPausedNote,
        );
      }

      try {
        final verifiedProof = await _middleware.analyzeWithAuthRetry(
          transcript: trimmed,
          scopeKey: scopeKey,
          entryId: entry.id,
          sourceType: ProofSourceType.userVoiceTranscript,
        );
        return _saveAttachedTypedText(
          entry: entry,
          trimmed: trimmed,
          verifiedProof: verifiedProof,
          syncSucceeded: true,
        );
      } on AnalyzeBlockedException catch (e, stackTrace) {
        return pipelineFailure(
          CapturePipelineFailure(
            e.reason.isNotEmpty
                ? e.reason
                : VoiceCaptureCopy.transcriptionFailedDegraded,
          ),
        );
      }
    } catch (e, stackTrace) {
      return _attachTypedTextLocally(
        entry: entry,
        trimmed: trimmed,
        syncNote: CaptureSaveMessages.syncNoteFor(e),
      );
    }
  }

  Future<CapturePipelineOutcome> _saveAnalyzedVoiceEntry({
    required File audioFile,
    required int durationSeconds,
    required String trimmedTranscript,
    required VerifiedProof verifiedProof,
    required String entryId,
    required AccountSessionGuard session,
    
  }) async {
    RecordPipelineLog.transcriptLengths(
      transcriptLength: trimmedTranscript.length,
      bodyLength: trimmedTranscript.length,
      observationLength: verifiedProof.reflection.concreteObservation
          .trim()
          .length,
      exactLanguageLength: verifiedProof.reflection.exactLanguagePattern
          .trim()
          .length,
    );

    _stageEmitter(PipelineStage.saving);
    session.assertActive();
    final finalTranscript =
        resolveFinalCaptureTranscript(transcript: trimmedTranscript) ??
        trimmedTranscript;
    RecordPipelineLog.preSaveFinalTranscript(length: finalTranscript.length);
    final template = JournalEntry(
      id: entryId,
      createdAt: DateTime.now().toUtc(),
      transcript: trimmedTranscript,
      durationSeconds: durationSeconds,
      reflection: verifiedProof.reflection,
      syncStatus: SyncStatus.pendingUpload,
      localAudioPath: audioFile.path,
      transcriptStatus: TranscriptStatus.finalTranscript,
      proof: processingProofFlags(usedOnnx: false).copyWith(
        verifiedProof: verifiedProof,
      ),
    );
    final prepared = applyFinalTranscriptToVoiceEntry(
      template,
      finalTranscript: finalTranscript,
      provenance: TranscriptProvenance.speechToText,
    );
    final entry = await _persistence.saveVoiceEntryAndLog(
      prepared,
      first25Source: 'voice_capture',
      session: session,
    );
    _middleware.clearCaptureToken();

    _stageEmitter(PipelineStage.done);
    return pipelineSuccess(CapturePipelineResult(
      entry: entry,
      localSaved: true,
      syncSucceeded: true,
      analysisSucceeded: true,
    ));
  }

  Future<CapturePipelineOutcome> _handleVoiceCaptureFailure({
    required File audioFile,
    required int durationSeconds,
    required String? partialTranscript,
    required Object error,
    Reflection? localReflection,
  }) {
    if (CaptureVoicePersistence.hasUsableTranscript(partialTranscript)) {
      return _saveAfterAnalysisFailure(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        transcript: partialTranscript!.trim(),
        error: error,
        localReflection: localReflection,
      );
    }

    final reason = CapturePipelineApiErrors.failureReason(error);
    TranscriptionLog.failed(reason: reason);
    final invalidMessage = CapturePipelineApiErrors.invalidResponseMessage(
      error,
    );
    if (invalidMessage != null) {
      _middleware.logApiGuardBlocked(
        operation: 'response',
        reason: invalidMessage,
      );
    }
    return _saveLocalOnly(
      audioFile: audioFile,
      durationSeconds: durationSeconds,
      syncNote: CapturePipelineApiErrors.syncNoteFor(error),
      transcriptionFailureReason: reason,
      
    );
  }

  Future<CapturePipelineOutcome> _saveProvisionalNativeTranscript({
    required File audioFile,
    required int durationSeconds,
    required String transcript,
    
  }) async {
    RecordPipelineLog.transcriptionFallback(
      reason: 'native_provisional_stt',
      audioPath: audioFile.path,
    );
    _stageEmitter(PipelineStage.saving);
    final finalTranscript = resolveFinalCaptureTranscript(
      transcript: transcript,
    );
    RecordPipelineLog.preSaveFinalTranscript(
      length: finalTranscript?.length ?? transcript.length,
    );
    final template = JournalEntry(
      id: JournalSyncIds.newOfflineEntryId(),
      createdAt: DateTime.now().toUtc(),
      transcript: transcript,
      durationSeconds: durationSeconds,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.pendingUpload,
      localAudioPath: audioFile.path,
      transcriptStatus: TranscriptStatus.provisional,
      // `SFSpeechRecognizer`, not ONNX. The flag said `usedOnnx: true` because
      // it is what drives the "Processed on your device" chip, which was true
      // about the device and false about the model.
      proof: processingProofFlags(usedOnnx: null, usedLocalStt: true),
    );
    final prepared = applyFinalTranscriptToVoiceEntry(
      template,
      finalTranscript: finalTranscript,
      provenance: TranscriptProvenance.speechToText,
    );
    final entry = await _persistence.saveVoiceEntryAndLog(
      prepared,
      first25Source: 'native_provisional_voice_capture',
    );
    _middleware.clearCaptureToken();
    _stageEmitter(PipelineStage.done);
    return pipelineSuccess(CapturePipelineResult(
      entry: entry,
      localSaved: true,
      syncSucceeded: false,
      analysisSucceeded: false,
      syncNote: VoiceCaptureCopy.transcriptionFailedDegraded,
    ));
  }

  Future<CapturePipelineOutcome> _saveAfterAnalysisFailure({
    required File audioFile,
    required int durationSeconds,
    required String transcript,
    Object? error,
    String? reason,
    String syncNote = VoiceCaptureCopy.analysisUnavailableNote,
    Reflection? localReflection,
  }) async {
    final resolvedReason =
        reason ??
        (error == null
            ? 'analysis_unavailable'
            : TranscriptionService.classifyFailureReason(error));
    if (error is ApiException) {
      AnalysisLog.failed(
        status: error.statusCode,
        code: error.code,
        reason: resolvedReason,
      );
    } else {
      AnalysisLog.failed(reason: resolvedReason);
    }
    RecordPipelineLog.analysisFailed(reason: resolvedReason);
    return _saveLocalOnly(
      audioFile: audioFile,
      durationSeconds: durationSeconds,
      partialTranscript: transcript,
      syncNote: syncNote,
      analysisFailureReason: resolvedReason,
      localReflection: localReflection,
    );
  }

  Future<CapturePipelineOutcome> _saveAttachedTypedText({
    required JournalEntry entry,
    required String trimmed,
    required VerifiedProof verifiedProof,
    required bool syncSucceeded,
    String? syncNote,
  }) async {
    final finalTranscript =
        resolveFinalCaptureTranscript(transcript: trimmed) ?? trimmed;
    RecordPipelineLog.preSaveFinalTranscript(length: finalTranscript.length);
    final template = entry.copyWith(
      transcript: trimmed,
      reflection: verifiedProof.reflection,
      verifiedProof: verifiedProof,
      syncStatus: SyncStatus.pendingUpload,
    );
    final updated = applyFinalTranscriptToVoiceEntry(
      template,
      finalTranscript: finalTranscript,
      provenance: TranscriptProvenance.userEdited,
    );
    final saved = await _persistence.saveVoiceEntryAndLog(
      updated,
      first25Source: 'voice_text_fallback',
      captureKind: 'typed_attach',
    );
    _middleware.clearCaptureToken();
    RecordPipelineLog.typedTextAttachedToVoiceEntry(entryId: entry.id);
    return pipelineSuccess(CapturePipelineResult(
      entry: saved,
      localSaved: true,
      syncSucceeded: syncSucceeded,
      syncNote: syncNote,
      attachedTypedTextToVoiceEntry: true,
    ));
  }

  Future<CapturePipelineOutcome> _attachTypedTextLocally({
    required JournalEntry entry,
    required String trimmed,
    required String syncNote,
  }) async {
    final finalTranscript = resolveFinalCaptureTranscript(transcript: trimmed);
    RecordPipelineLog.preSaveFinalTranscript(
      length: finalTranscript?.length ?? 0,
    );
    final template = entry.copyWith(
      transcript: trimmed,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.pendingUpload,
    );
    final prepared = applyFinalTranscriptToVoiceEntry(
      template,
      finalTranscript: finalTranscript,
      provenance: TranscriptProvenance.userEdited,
    );
    final updated = await _persistence.saveVoiceEntryAndLog(
      prepared,
      first25Source: 'voice_text_fallback',
      captureKind: 'typed_attach',
    );
    _middleware.clearCaptureToken();
    RecordPipelineLog.typedTextAttachedToVoiceEntry(entryId: entry.id);
    return pipelineSuccess(CapturePipelineResult(
      entry: updated,
      localSaved: true,
      syncSucceeded: false,
      syncNote: syncNote,
      attachedTypedTextToVoiceEntry: true,
    ));
  }

  Future<CapturePipelineOutcome> _saveLocalOnly({
    required File audioFile,
    required int durationSeconds,
    required String syncNote,
    String? partialTranscript,
    String? transcriptionFailureReason,
    String? analysisFailureReason,
    bool lowQualityTranscript = false,
    Reflection? localReflection,
  }) async {
    if (analysisFailureReason != null) {
      RecordPipelineLog.analysisFallback(
        reason: analysisFailureReason,
        audioPath: audioFile.path,
      );
    } else if (transcriptionFailureReason != null) {
      RecordPipelineLog.transcriptionFallback(
        reason: transcriptionFailureReason,
        audioPath: audioFile.path,
      );
    }
    _stageEmitter(PipelineStage.saving);
    try {
      final entry = await _persistence.saveOfflineDraft(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        partialTranscript: partialTranscript,
        reflection: localReflection,
      );
      _middleware.clearCaptureToken();
      _stageEmitter(PipelineStage.done);
      // Judged on extracted content, not on an intensity number: the on-device
      // extractor reports no intensity at all, so it is not a liveness signal.
      final hasLocalReflection = localReflection != null &&
          (localReflection.recurringThemes.isNotEmpty ||
              localReflection.concreteObservation.trim().isNotEmpty ||
              (localReflection.tensionOrContradiction ?? '').trim().isNotEmpty ||
              (localReflection.nextSmallAction ?? '').trim().isNotEmpty);
      return pipelineSuccess(CapturePipelineResult(
        entry: entry,
        localSaved: true,
        syncSucceeded: false,
        analysisSucceeded:
            hasLocalReflection ||
            (analysisFailureReason == null &&
                CaptureVoicePersistence.hasUsableTranscript(partialTranscript)),
        syncNote: syncNote,
        lowQualityTranscript: lowQualityTranscript,
      ));
    } catch (e, stackTrace) {
      return pipelineFailure(
        CapturePipelineFailure(
          VoiceCaptureCopy.saveFailed,
        ),
      );
    }
  }
}