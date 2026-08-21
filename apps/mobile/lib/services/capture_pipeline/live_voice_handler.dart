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
import 'package:archiveme_mobile/security/user_content_safety.dart';

class LiveVoiceHandler {
  LiveVoiceHandler({
    required CapturePipelineDependencies deps,
    required CapturePipelineMiddleware middleware,
    PipelineStageEmitter stageEmitter = noopPipelineStage,
  }) : _deps = deps,
       _middleware = middleware,
       _stageEmitter = stageEmitter;

  final CapturePipelineDependencies _deps;
  final CapturePipelineMiddleware _middleware;
  final PipelineStageEmitter _stageEmitter;

  Future<CapturePipelineOutcome> saveLiveVoiceTranscript({
    required String transcript,
    required int durationSeconds,
  }) async {
    final session = _deps.sessionGuardFactory();
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      return pipelineFailure(
        CapturePipelineFailure('No live transcript was captured.'),
      );
    }

    final scopeKey = CaptureVoicePersistence.textScopeKey(trimmed);
    try {
      if (!await _middleware.isPurposeGranted(
        RemoteProcessingPurpose.remoteReflection,
      )) {
        return _saveLiveVoiceLocalOnly(
          transcript: trimmed,
          durationSeconds: durationSeconds,
          syncNote: VoiceCaptureCopy.remoteProcessingConsentPausedNote,
          
        );
      }

      final entryId = JournalSyncIds.newOfflineEntryId();
      try {
        final verifiedProof = await _middleware.analyzeWithAuthRetry(
          transcript: trimmed,
          scopeKey: scopeKey,
          entryId: entryId,
          sourceType: ProofSourceType.userVoiceTranscript,
          
        );
        _stageEmitter(PipelineStage.saving);
        final entry = JournalEntry(
          id: entryId,
          createdAt: DateTime.now().toUtc(),
          transcript: trimmed,
          durationSeconds: durationSeconds.clamp(1, 999999),
          reflection: verifiedProof.reflection,
          verifiedProof: verifiedProof,
          syncStatus: SyncStatus.pendingUpload,
          captureContextTag: 'live_voice_capture',
        );
        session.assertActive();
        await _deps.journalStore.save(
          entry,
          first25Source: 'live_voice_capture',
          captureKind: 'voice',
        );
        _middleware.clearCaptureToken();

        _stageEmitter(PipelineStage.done);
        return pipelineSuccess(CapturePipelineResult(
          entry: entry,
          localSaved: true,
          syncSucceeded: true,
          analysisSucceeded: true,
        ));
      } on AnalyzeBlockedException catch (e, stackTrace) {
        return _saveLiveVoiceLocalOnly(
          transcript: trimmed,
          durationSeconds: durationSeconds,
          syncNote: e.reason.isNotEmpty
              ? e.reason
              : VoiceCaptureCopy.transcriptionFailedDegraded,
          
        );
      }
    } catch (e, stackTrace) {
      final invalidMessage = CapturePipelineApiErrors.invalidResponseMessage(e);
      if (invalidMessage != null) {
        _middleware.logApiGuardBlocked(
          operation: 'response',
          reason: invalidMessage,
        );
      }
      return _saveLiveVoiceLocalOnly(
        transcript: trimmed,
        durationSeconds: durationSeconds,
        syncNote: CapturePipelineApiErrors.syncNoteFor(e),
        
      );
    }
  }

  Future<CapturePipelineOutcome> saveRecoveredVaultEntry({
    required String transcript,
    required Map<String, dynamic> reflectionJson,
    required int durationSeconds,
    required bool remoteProcessingConsented,
    
  }) async {
    final session = _deps.sessionGuardFactory();
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      return pipelineFailure(
        CapturePipelineFailure('Recovered vault transcript was empty.'),
      );
    }

    _stageEmitter(PipelineStage.saving);
    final entryId = JournalSyncIds.newOfflineEntryId();
    final raw = RawModelResponse(
      payload: {'reflection': reflectionJson},
      receivedAt: DateTime.now().toUtc(),
    );
    final revision = UserContentSafety.privacyHash(trimmed);
    final admission = _deps.proofAdmission.admit(
      raw: raw,
      sourceEntries: [
        ProofSourceEntry(
          entryId: entryId,
          archiveScope: _deps.archiveScope,
          ownerScope: _deps.ownerScope,
          transcript: trimmed,
          transcriptRevision: revision,
          createdAt: raw.receivedAt,
          sourceType: ProofSourceType.userVoiceTranscript,
          remoteProcessingConsented: remoteProcessingConsented,
        ),
      ],
      activeArchiveScope: _deps.archiveScope,
      activeOwnerScope: _deps.ownerScope,
      primarySourceEntryId: entryId,
    );
    if (admission is! ProofAdmitted) {
      final rejected = admission as ProofNotAdmitted;
      throw FormatException(
        'Recovered analysis was not admitted '
        '(${rejected.outcome.name}:${rejected.reason}).',
      );
    }
    final verifiedProof = admission.proof;
    final entry = JournalEntry(
      id: entryId,
      createdAt: DateTime.now().toUtc(),
      transcript: trimmed,
      durationSeconds: durationSeconds.clamp(1, 999999),
      reflection: verifiedProof.reflection,
      verifiedProof: verifiedProof,
      syncStatus: SyncStatus.pendingUpload,
      captureContextTag: 'live_voice_vault_recovery',
    );
    session.assertActive();
    await _deps.journalStore.save(
      entry,
      first25Source: 'live_voice_vault_recovery',
      captureKind: 'voice',
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

  Future<CapturePipelineOutcome> _saveLiveVoiceLocalOnly({
    required String transcript,
    required int durationSeconds,
    required String syncNote,
    
  }) async {
    _stageEmitter(PipelineStage.saving);
    final entry = JournalEntry(
      id: JournalSyncIds.newOfflineEntryId(),
      createdAt: DateTime.now().toUtc(),
      transcript: transcript,
      durationSeconds: durationSeconds.clamp(1, 999999),
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      captureContextTag: 'live_voice_capture',
    );
    await _deps.journalStore.save(
      entry,
      first25Source: 'live_voice_capture',
      captureKind: 'voice',
    );
    _middleware.clearCaptureToken();
    _stageEmitter(PipelineStage.done);
    return pipelineSuccess(CapturePipelineResult(
      entry: entry,
      localSaved: true,
      syncSucceeded: false,
      syncNote: syncNote,
    ));
  }
}