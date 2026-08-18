import 'package:archiveme_mobile/core/network/capture_pipeline_api_errors.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_dependencies.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_middleware.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_models.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_voice_persistence.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/services/record_pipeline_log.dart';
import 'package:flutter/foundation.dart';

class TextCaptureHandler {
  TextCaptureHandler({
    required CapturePipelineDependencies deps,
    required CapturePipelineMiddleware middleware,
    PipelineStageEmitter stageEmitter = noopPipelineStage,
  }) : _deps = deps,
       _middleware = middleware,
       _stageEmitter = stageEmitter;

  final CapturePipelineDependencies _deps;
  final CapturePipelineMiddleware _middleware;
  final PipelineStageEmitter _stageEmitter;

  @visibleForTesting
  CapturePipelineMiddleware get middlewareForTest => _middleware;

  Future<CapturePipelineOutcome> saveTextThought({
    required String transcript,
  }) async {
    final session = _deps.sessionGuardFactory();
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      return pipelineFailure(
        CapturePipelineFailure('Enter a thought before saving.'),
      );
    }

    final scopeKey = CaptureVoicePersistence.textScopeKey(trimmed);
    try {
      if (!await _middleware.isPurposeGranted(
        RemoteProcessingPurpose.remoteReflection,
      )) {
        return _saveTextLocalOnly(
          transcript: trimmed,
          syncNote: VoiceCaptureCopy.remoteProcessingConsentPausedNote,
          
        );
      }

      final entryId = JournalSyncIds.newOfflineEntryId();
      try {
        final verifiedProof = await _middleware.analyzeWithAuthRetry(
          transcript: trimmed,
          scopeKey: scopeKey,
          entryId: entryId,
          sourceType: ProofSourceType.userTyped,
          
        );
        _stageEmitter(PipelineStage.saving);
        final entry = JournalEntry(
          id: entryId,
          createdAt: DateTime.now().toUtc(),
          transcript: trimmed,
          durationSeconds: CaptureVoicePersistence.estimatedDurationSeconds(
            trimmed,
          ),
          reflection: verifiedProof.reflection,
          verifiedProof: verifiedProof,
          syncStatus: SyncStatus.pendingUpload,
        );
        session.assertActive();
        await _deps.journalStore.save(
          entry,
          first25Source: 'text_capture',
          captureKind: 'typed',
        );
        _middleware.clearCaptureToken();

        _stageEmitter(PipelineStage.done);
        return pipelineSuccess(CapturePipelineResult(
          entry: entry,
          localSaved: true,
          syncSucceeded: true,
        ));
      } on AnalyzeBlockedException catch (e) {
        return _saveTextLocalOnly(
          transcript: trimmed,
          syncNote: e.reason.isNotEmpty
              ? e.reason
              : VoiceCaptureCopy.transcriptionFailedDegraded,
          
        );
      }
    } catch (e) {
      final invalidMessage = CapturePipelineApiErrors.invalidResponseMessage(e);
      if (invalidMessage != null) {
        _middleware.logApiGuardBlocked(
          operation: 'response',
          reason: invalidMessage,
        );
      }
      return _saveTextLocalOnly(
        transcript: trimmed,
        syncNote: CapturePipelineApiErrors.syncNoteFor(e),
        
      );
    }
  }

  Future<CapturePipelineOutcome> _saveTextLocalOnly({
    required String transcript,
    required String syncNote,
    
  }) async {
    _stageEmitter(PipelineStage.saving);
    try {
      final entry = await _saveOfflineTextDraft(transcript);
      _middleware.clearCaptureToken();
      _stageEmitter(PipelineStage.done);
      return pipelineSuccess(CapturePipelineResult(
        entry: entry,
        localSaved: true,
        syncSucceeded: false,
        syncNote: syncNote,
      ));
    } catch (e) {
      return pipelineFailure(
        CapturePipelineFailure(
          VoiceCaptureCopy.saveFailed,
        ),
      );
    }
  }

  Future<JournalEntry> _saveOfflineTextDraft(String transcript) async {
    final trimmed = transcript.trim();
    final entry = JournalEntry(
      id: JournalSyncIds.newOfflineEntryId(),
      createdAt: DateTime.now().toUtc(),
      transcript: trimmed,
      durationSeconds: CaptureVoicePersistence.estimatedDurationSeconds(trimmed),
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: CaptureSaveMessages.savedPrivatelyOnDevice,
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.pendingUpload,
    );
    await _deps.journalStore.save(
      entry,
      first25Source: 'offline_text_capture',
      captureKind: 'typed',
    );
    return entry;
  }
}
