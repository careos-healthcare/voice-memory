import 'dart:io';

import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/core/network/capture_pipeline_api_errors.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_consent_boundary.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/features/voice_capture/analysis/analysis_log.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_log.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_service.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/models/transcript_status.dart';
import 'package:archiveme_mobile/security/account_session_guard.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_dependencies.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_middleware.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_models.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_voice_persistence.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/services/record_pipeline_log.dart';

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
    final scopeKey = CaptureVoicePersistence.audioScopeKey(
      audioFile.path,
      durationSeconds,
    );
    try {
      if (!await _middleware.isPurposeGranted(
        RemoteProcessingPurpose.remoteTranscription,
      )) {
        const reason = 'remote_processing_consent_missing';
        _middleware.logApiGuardBlocked(operation: 'transcribe', reason: reason);
        return _saveLocalOnly(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          syncNote: VoiceCaptureCopy.remoteProcessingConsentPausedNote,
          transcriptionFailureReason: reason,
          
        );
      }

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
            
          );
        }
        _middleware.logApiGuardBlocked(operation: 'transcribe', reason: reason);
        return _saveLocalOnly(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          syncNote: VoiceCaptureCopy.transcriptionFailedDegraded,
          transcriptionFailureReason: reason,
          
        );
      }

      partialTranscript = transcription.transcript;
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
          
        );
      }

      if (transcription.isProvisional) {
        final uploadPath = transcription.uploadAudioPath;
        final resolvedAudio = uploadPath != null && uploadPath.isNotEmpty
            ? File(uploadPath)
            : audioFile;
        return _saveProvisionalNativeTranscript(
          audioFile: resolvedAudio,
          durationSeconds: durationSeconds,
          transcript: trimmedTranscript,
          
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
          
        );
      }

      final entryId = JournalSyncIds.newOfflineEntryId();
      try {
        final verifiedProof = await _middleware.analyzeWithAuthRetry(
          transcript: trimmedTranscript,
          scopeKey: scopeKey,
          entryId: entryId,
          sourceType: ProofSourceType.userVoiceTranscript,
          
          attestFirst: false,
        );
        return _saveAnalyzedVoiceEntry(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          trimmedTranscript: trimmedTranscript,
          verifiedProof: verifiedProof,
          entryId: entryId,
          session: session,
          
        );
      } on AnalyzeBlockedException catch (e) {
        return _saveAfterAnalysisFailure(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          transcript: trimmedTranscript,
          reason: e.reason,
          
        );
      } catch (e) {
        return _saveAfterAnalysisFailure(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          transcript: trimmedTranscript,
          error: e,
          
        );
      }
    } catch (e) {
      return _handleVoiceCaptureFailure(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        partialTranscript: partialTranscript,
        error: e,
        
      );
    }
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
      } on AnalyzeBlockedException catch (e) {
        return pipelineFailure(
          CapturePipelineFailure(
            e.reason.isNotEmpty
                ? e.reason
                : VoiceCaptureCopy.transcriptionFailedDegraded,
          ),
        );
      }
    } catch (e) {
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
        resolveFinalCaptureTranscript(
          transcript: trimmedTranscript,
          body: verifiedProof.reflection.concreteObservation,
          exactLanguage: verifiedProof.reflection.exactLanguagePattern,
          observation: verifiedProof.reflection.concreteObservation,
        ) ??
        trimmedTranscript;
    RecordPipelineLog.preSaveFinalTranscript(length: finalTranscript.length);
    final template = JournalEntry(
      id: entryId,
      createdAt: DateTime.now().toUtc(),
      transcript: trimmedTranscript,
      durationSeconds: durationSeconds,
      reflection: verifiedProof.reflection,
      verifiedProof: verifiedProof,
      syncStatus: SyncStatus.pendingUpload,
      localAudioPath: audioFile.path,
      transcriptStatus: TranscriptStatus.finalTranscript,
    );
    final prepared = applyFinalTranscriptToVoiceEntry(
      template,
      finalTranscript: finalTranscript,
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
    
  }) {
    if (CaptureVoicePersistence.hasUsableTranscript(partialTranscript)) {
      return _saveAfterAnalysisFailure(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        transcript: partialTranscript!.trim(),
        error: error,
        
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
      body: transcript,
      observation: transcript,
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
    );
    final prepared = applyFinalTranscriptToVoiceEntry(
      template,
      finalTranscript: finalTranscript,
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
        resolveFinalCaptureTranscript(
          transcript: trimmed,
          body: verifiedProof.reflection.concreteObservation,
          exactLanguage: verifiedProof.reflection.exactLanguagePattern,
          observation: verifiedProof.reflection.concreteObservation,
        ) ??
        trimmed;
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
    final finalTranscript = resolveFinalCaptureTranscript(
      transcript: trimmed,
      body: trimmed,
      observation: trimmed,
    );
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
      );
      _middleware.clearCaptureToken();
      _stageEmitter(PipelineStage.done);
      return pipelineSuccess(CapturePipelineResult(
        entry: entry,
        localSaved: true,
        syncSucceeded: false,
        analysisSucceeded:
            analysisFailureReason == null &&
            CaptureVoicePersistence.hasUsableTranscript(partialTranscript),
        syncNote: syncNote,
        lowQualityTranscript: lowQualityTranscript,
      ));
    } catch (e) {
      return pipelineFailure(
        CapturePipelineFailure(
          VoiceCaptureCopy.saveFailed,
        ),
      );
    }
  }
}
