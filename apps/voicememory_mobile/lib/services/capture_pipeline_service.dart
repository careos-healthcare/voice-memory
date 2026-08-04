import 'dart:io';

import 'package:uuid/uuid.dart';

import '../api/api_exceptions.dart';
import '../core/errors/domain_exception.dart';
import '../features/timeline/timeline_entry_display.dart';
import '../features/analysis/prior_analysis_evidence_builder.dart';
import '../features/capture_api_retry/capture_api_retry_queue.dart';
import '../features/processing_preferences/processing_preferences.dart';
import '../features/processing_preferences/processing_preferences_store.dart';
import '../features/remote_transcription/remote_transcription_disclosure.dart';
import '../features/voice_capture/analysis/analysis_log.dart';
import '../features/voice_capture/transcription/transcription_log.dart';
import '../features/voice_capture/transcription/on_device_transcription_engine.dart';
import '../features/voice_capture/transcription/transcription_service.dart';
import '../features/voice_capture/transcription/transcription_connectivity.dart';
import '../features/moment_quality/post_save_moment_detail_model.dart';
import '../features/moment_quality/post_save_moment_detail_service.dart';
import '../features/monetization/domain/access_policy_engine.dart';
import '../features/explainable_conclusion/explainability_history_store.dart';
import '../features/explainable_conclusion/explainable_conclusion_validator.dart';
import '../features/voice_capture/voice_capture_copy.dart';
import '../features/voice_capture/voice_capture_quality.dart';
import '../models/journal_entry.dart';
import '../models/local_capture_context.dart';
import '../models/reflection.dart';
import '../models/sync_status.dart';
import '../security/api_usage_guard.dart';
import '../security/user_content_safety.dart';
import '../storage/journal_store.dart';
import 'capture_attest_service.dart';
import 'capture_save_messages.dart';
import '../api/api_client.dart';
import 'record_pipeline_log.dart';
import 'privacy/audio_vault_service.dart';
import 'privacy/sensitive_temporary_audio_store.dart';

class CapturePipelineFailure extends DomainException {
  CapturePipelineFailure(
    this.message, {
    this.savedDraft = false,
    this.entry,
    Object? cause,
  }) : super(message, userFacingCode: 'CAPTURE_PIPELINE_FAILED', cause: cause);

  final String message;
  final bool savedDraft;
  final JournalEntry? entry;

  @override
  String toString() => message;
}

enum PipelineStage { attesting, transcribing, analyzing, saving, done }

class CapturePipelineResult {
  const CapturePipelineResult({
    required this.entry,
    required this.localSaved,
    required this.syncSucceeded,
    this.analysisSucceeded = false,
    this.syncNote,
    this.attachedTypedTextToVoiceEntry = false,
    this.lowQualityTranscript = false,
  });

  final JournalEntry entry;
  final bool localSaved;
  final bool syncSucceeded;
  final bool analysisSucceeded;
  final String? syncNote;
  final bool attachedTypedTextToVoiceEntry;
  final bool lowQualityTranscript;
}

class CapturePipelineService {
  CapturePipelineService({
    required this._api,
    required this._attest,
    required this._journalStore,
    ApiUsageGuard? usageGuard,
    OnDeviceTranscriptionEngine? onDeviceTranscription,
    TranscriptionConnectivity? transcriptionConnectivity,
    CaptureApiRetryQueue? retryQueue,
    ExplainabilityHistoryStore? explainabilityHistoryStore,
    AudioVaultService? audioVault,
    SensitiveTemporaryAudioStore? temporaryAudioStore,
    ProcessingPreferencesReader processingPreferences =
        const FixedProcessingPreferences(),
    RemoteTranscriptionDisclosureGate remoteDisclosure =
        const DeniedRemoteTranscriptionDisclosureGate(),
  }) : _usageGuard = usageGuard ?? ApiUsageGuard.shared,
       _onDeviceTranscription =
           onDeviceTranscription ?? WhisperOnDeviceTranscriptionEngine(),
       _transcriptionConnectivity =
           transcriptionConnectivity ?? PlatformTranscriptionConnectivity(),
       // Public named parameter cannot be an initializing formal for a
       // private field.
       // ignore: prefer_initializing_formals
       _retryQueue = retryQueue,
       // Public named parameter cannot be an initializing formal.
       // ignore: prefer_initializing_formals
       _explainabilityHistoryStore = explainabilityHistoryStore,
       // Public named parameter cannot be an initializing formal.
       // ignore: prefer_initializing_formals
       _audioVault = audioVault,
       // Public named parameter cannot expose a private field.
       // ignore: prefer_initializing_formals
       _processingPreferences = processingPreferences,
       // Public named parameter cannot expose a private field.
       // ignore: prefer_initializing_formals
       _remoteDisclosure = remoteDisclosure,
       _temporaryAudioStore =
           temporaryAudioStore ?? SensitiveTemporaryAudioStore.production;

  final VoiceCaptureApiClient _api;
  final CaptureAttestService _attest;
  final JournalStore _journalStore;
  final ApiUsageGuard _usageGuard;
  final OnDeviceTranscriptionEngine _onDeviceTranscription;
  final TranscriptionConnectivity _transcriptionConnectivity;
  final CaptureApiRetryQueue? _retryQueue;
  final ExplainabilityHistoryStore? _explainabilityHistoryStore;
  final AudioVaultService? _audioVault;
  final ProcessingPreferencesReader _processingPreferences;
  final RemoteTranscriptionDisclosureGate _remoteDisclosure;
  final SensitiveTemporaryAudioStore _temporaryAudioStore;
  final Map<String, String> _vaultReferenceBySourcePath = {};
  final _uuid = const Uuid();

  /// Downloads the small local model only while connectivity is available.
  Future<void> prepareOfflineTranscription() async {
    try {
      if (!await _transcriptionConnectivity.isOnline() ||
          await _onDeviceTranscription.isReady()) {
        return;
      }
      await _onDeviceTranscription.prepare();
    } catch (error) {
      TranscriptionLog.failed(
        reason: 'local_model_prepare:${error.runtimeType}',
      );
    }
  }

  Future<CapturePipelineResult> run({
    required File audioFile,
    required int durationSeconds,
    String? entryId,
    DateTime? createdAt,
    bool deferFailedTranscription = false,
    bool retryTranscription = false,
    String? transcriptionIdempotencyKey,
    TranscriptionPreference? currentTranscriptionChoice,
    InterpretationPreference? currentInterpretationChoice,
    void Function(PipelineStage stage)? onStage,
  }) async {
    final vault = _audioVault;
    if (vault == null) {
      try {
        final result = await _runWithPlaintext(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          entryId: entryId,
          createdAt: createdAt,
          deferFailedTranscription: deferFailedTranscription,
          retryTranscription: retryTranscription,
          transcriptionIdempotencyKey: transcriptionIdempotencyKey,
          currentTranscriptionChoice: currentTranscriptionChoice,
          currentInterpretationChoice: currentInterpretationChoice,
          onStage: onStage,
        );
        if (await audioFile.exists()) await audioFile.delete();
        return result;
      } on Object {
        // Preserve the only source when capture persistence fails.
        rethrow;
      }
    }
    if (vault.isVaultPath(audioFile.path)) {
      final alreadyOpaque = vault.isVaultReference(audioFile.path);
      final existing = alreadyOpaque
          ? AudioVaultObject(
              reference: audioFile.path,
              file: await vault.resolveReference(audioFile.path),
            )
          : await vault.adoptLegacyEncryptedPath(audioFile.path);
      final createdAdoptedCopy =
          !alreadyOpaque &&
          existing.file.absolute.path != audioFile.absolute.path;
      final resolvedEntryId = entryId ?? _uuid.v4();
      try {
        final result = await vault.withDecryptedFile(existing.reference, (
          workingFile,
        ) async {
          _vaultReferenceBySourcePath[workingFile.path] = existing.reference;
          try {
            return await _runWithPlaintext(
              audioFile: workingFile,
              durationSeconds: durationSeconds,
              entryId: resolvedEntryId,
              createdAt: createdAt,
              deferFailedTranscription: deferFailedTranscription,
              retryTranscription: retryTranscription,
              transcriptionIdempotencyKey: transcriptionIdempotencyKey,
              currentTranscriptionChoice: currentTranscriptionChoice,
              currentInterpretationChoice: currentInterpretationChoice,
              onStage: onStage,
            );
          } finally {
            _vaultReferenceBySourcePath.remove(workingFile.path);
          }
        });
        if (result.entry.localAudioVaultRef != existing.reference) {
          throw CapturePipelineFailure(
            'Encrypted audio reference was not persisted.',
            savedDraft: false,
          );
        }
        if (createdAdoptedCopy && await audioFile.exists()) {
          await audioFile.delete();
        }
        return result;
      } on Object catch (error, stackTrace) {
        final persisted = await _journalStore.getById(resolvedEntryId);
        if (persisted?.localAudioVaultRef == existing.reference) {
          if (createdAdoptedCopy && await audioFile.exists()) {
            await audioFile.delete();
          }
          throw CapturePipelineFailure(
            'The recording was saved securely, but finishing capture failed.',
            savedDraft: true,
          );
        }
        if (createdAdoptedCopy) await vault.delete(existing.reference);
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
    final resolvedEntryId = entryId ?? _uuid.v4();
    final retainedEntry = await _journalStore.getById(resolvedEntryId);
    final retainedReference = retainedEntry?.localAudioVaultRef?.trim();
    if (retainedReference != null &&
        retainedReference.isNotEmpty &&
        vault.isVaultReference(retainedReference) &&
        await vault.exists(retainedReference)) {
      _vaultReferenceBySourcePath[audioFile.path] = retainedReference;
      try {
        final result = await _runWithPlaintext(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          entryId: resolvedEntryId,
          createdAt: createdAt,
          deferFailedTranscription: deferFailedTranscription,
          retryTranscription: retryTranscription,
          transcriptionIdempotencyKey: transcriptionIdempotencyKey,
          currentTranscriptionChoice: currentTranscriptionChoice,
          currentInterpretationChoice: currentInterpretationChoice,
          onStage: onStage,
        );
        if (result.entry.localAudioVaultRef != retainedReference) {
          throw CapturePipelineFailure(
            'Encrypted audio reference was not preserved.',
            savedDraft: true,
          );
        }
        await vault.secureDeletePlaintext(audioFile);
        return result;
      } on Object catch (error, stackTrace) {
        // The durable vault object already existed before this retry. Keep it
        // and remove only the short-lived decrypted queue working file.
        await vault.secureDeletePlaintext(audioFile);
        Error.throwWithStackTrace(error, stackTrace);
      } finally {
        _vaultReferenceBySourcePath.remove(audioFile.path);
      }
    }
    final sealed = await vault.sealCapture(resolvedEntryId, audioFile);
    await _removeSourceAfterEncryption(vault, audioFile);
    try {
      final result = await vault.withDecryptedFile(sealed.reference, (
        workingFile,
      ) async {
        _vaultReferenceBySourcePath[workingFile.path] = sealed.reference;
        try {
          return await _runWithPlaintext(
            audioFile: workingFile,
            durationSeconds: durationSeconds,
            entryId: resolvedEntryId,
            createdAt: createdAt,
            deferFailedTranscription: deferFailedTranscription,
            retryTranscription: retryTranscription,
            transcriptionIdempotencyKey: transcriptionIdempotencyKey,
            currentTranscriptionChoice: currentTranscriptionChoice,
            currentInterpretationChoice: currentInterpretationChoice,
            onStage: onStage,
          );
        } finally {
          _vaultReferenceBySourcePath.remove(workingFile.path);
        }
      });
      if (result.entry.localAudioVaultRef != sealed.reference) {
        throw CapturePipelineFailure(
          'Encrypted audio reference was not persisted.',
          savedDraft: false,
        );
      }
      return result;
    } on Object catch (error, stackTrace) {
      final persisted = await _journalStore.getById(resolvedEntryId);
      if (persisted?.localAudioVaultRef == sealed.reference) {
        throw CapturePipelineFailure(
          'The recording was saved securely, but finishing capture failed.',
          savedDraft: true,
        );
      }
      // Encryption succeeded, so never recreate or retain the plaintext
      // source. Keep the authenticated vault object available for local
      // recovery if the journal commit failed.
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<CapturePipelineResult> _runWithPlaintext({
    required File audioFile,
    required int durationSeconds,
    String? entryId,
    DateTime? createdAt,
    bool deferFailedTranscription = false,
    bool retryTranscription = false,
    String? transcriptionIdempotencyKey,
    TranscriptionPreference? currentTranscriptionChoice,
    InterpretationPreference? currentInterpretationChoice,
    void Function(PipelineStage stage)? onStage,
  }) async {
    final exists = audioFile.existsSync();
    final byteLength = exists ? audioFile.lengthSync() : 0;
    RecordPipelineLog.audioFile(
      path: audioFile.path,
      exists: exists,
      byteLength: byteLength,
    );
    if (!exists || byteLength < VoiceCaptureQuality.minAudioBytes) {
      RecordPipelineLog.rejectInsufficientAudio(byteLength: byteLength);
      throw CapturePipelineFailure(VoiceCaptureCopy.notEnoughAudio);
    }

    final transcriptionPreference = await _resolvedTranscriptionPreference(
      currentTranscriptionChoice,
    );
    if (transcriptionPreference ==
            TranscriptionPreference.saveWithoutTranscript ||
        transcriptionPreference == TranscriptionPreference.askEachTime) {
      return _saveLocalOnly(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        partialTranscript: null,
        syncNote: 'Recording saved without online processing.',
        transcriptionFailureReason: 'transcription_not_authorized',
        retryTranscription: false,
        entryId: entryId,
        createdAt: createdAt,
        onStage: onStage,
      );
    }
    final onlineTranscriptionAllowed =
        transcriptionPreference == TranscriptionPreference.online &&
        await _hasCurrentDisclosure(RemoteProcessingPurpose.transcription);
    if (transcriptionPreference == TranscriptionPreference.online &&
        !onlineTranscriptionAllowed) {
      return _saveLocalOnly(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        partialTranscript: null,
        syncNote: 'Recording saved. Online transcription was not authorized.',
        transcriptionFailureReason: 'transcription_disclosure_required',
        retryTranscription: false,
        entryId: entryId,
        createdAt: createdAt,
        onStage: onStage,
      );
    }

    final transcriptionAccess = AccessPolicyEngine.decide(
      capability: CapabilityId.remoteTranscription,
      entitlement: const EntitlementSnapshot.unknown(),
      usage: const UsageSnapshot.serverAuthoritative(),
    );
    if (!transcriptionAccess.allowed) {
      return _saveLocalOnly(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        partialTranscript: null,
        syncNote: 'Saved locally. Remote transcription is unavailable.',
        transcriptionFailureReason: transcriptionAccess.kind.name,
        retryTranscription: false,
        onStage: onStage,
      );
    }

    String? partialTranscript;
    TranscriptionOutcome? transcriptionOutcome;
    List<Map<String, dynamic>> priorEvidence = const [];
    final scopeKey = _audioScopeKey(audioFile.path, durationSeconds);
    try {
      onStage?.call(PipelineStage.transcribing);
      final transcription = transcriptionOutcome =
          await TranscriptionService.transcribeRecording(
            audioFile: audioFile,
            durationSeconds: durationSeconds,
            api: _api,
            ensureCaptureToken: _attest.ensureCaptureToken,
            scopeKey: scopeKey,
            usageGuard: _usageGuard,
            localEngine: _onDeviceTranscription,
            connectivity: onlineTranscriptionAllowed
                ? _transcriptionConnectivity
                : const _OfflineTranscriptionConnectivity(),
          );

      if (!transcription.succeeded) {
        final reason =
            transcription.skippedReason ??
            transcription.failureReason ??
            'transcription_unavailable';
        if (deferFailedTranscription) {
          throw CapturePipelineFailure(reason, savedDraft: false);
        }
        if (reason.startsWith('low_quality:')) {
          return _saveLocalOnly(
            audioFile: audioFile,
            durationSeconds: durationSeconds,
            partialTranscript: null,
            syncNote: VoiceCaptureCopy.lowQualityTranscriptIssue,
            transcriptionFailureReason: reason,
            lowQualityTranscript: true,
            retryTranscription: transcription.retryableCloudFailure,
            transcriptionIdempotencyKey: transcription.cloudIdempotencyKey,
            onStage: onStage,
          );
        }
        RecordPipelineLog.apiGuardBlocked(
          operation: 'transcribe',
          reason: reason,
        );
        return _saveLocalOnly(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          partialTranscript: null,
          syncNote: VoiceCaptureCopy.transcriptionFailedDegraded,
          transcriptionFailureReason: reason,
          retryTranscription: transcription.retryableCloudFailure,
          transcriptionIdempotencyKey: transcription.cloudIdempotencyKey,
          onStage: onStage,
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
        if (deferFailedTranscription) {
          throw CapturePipelineFailure(reason, savedDraft: false);
        }
        return _saveLocalOnly(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          partialTranscript: null,
          syncNote: CaptureSaveMessages.syncUnavailableOffline,
          transcriptionFailureReason: reason,
          retryTranscription: transcription.retryableCloudFailure,
          transcriptionIdempotencyKey: transcription.cloudIdempotencyKey,
          onStage: onStage,
        );
      }

      if (!await _allowsInterpretation(currentInterpretationChoice)) {
        return _saveLocalOnly(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          partialTranscript: trimmedTranscript,
          syncNote: 'Saved without an interpretation.',
          analysisFailureReason: 'interpretation_not_authorized',
          retryAnalysis: false,
          retryTranscription: false,
          entryId: entryId,
          createdAt: createdAt,
          onStage: onStage,
        );
      }

      onStage?.call(PipelineStage.attesting);
      final persistedEntryId = entryId ?? _uuid.v4();
      var token = await _attest.ensureCaptureToken();
      onStage?.call(PipelineStage.analyzing);
      priorEvidence = await _buildPriorEvidence(
        excludeEntryId: persistedEntryId,
      );
      final analysisAccess = AccessPolicyEngine.decide(
        capability: CapabilityId.remoteObservationGeneration,
        entitlement: const EntitlementSnapshot.unknown(),
        usage: const UsageSnapshot.serverAuthoritative(),
      );
      if (!analysisAccess.allowed) {
        return _saveAfterAnalysisFailure(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          transcript: trimmedTranscript,
          reason: analysisAccess.kind.name,
          entryId: entryId,
          createdAt: createdAt,
          priorEvidence: priorEvidence,
          retryTranscription: transcription.retryableCloudFailure,
          transcriptionIdempotencyKey: transcription.cloudIdempotencyKey,
          onStage: onStage,
        );
      }
      final analyzeCheck = _usageGuard.checkAttempt(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
      );
      if (!analyzeCheck.allowed) {
        final reason = analyzeCheck.reason ?? 'blocked';
        RecordPipelineLog.apiGuardBlocked(operation: 'analyze', reason: reason);
        return _saveAfterAnalysisFailure(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          transcript: trimmedTranscript,
          reason: reason,
          entryId: entryId,
          createdAt: createdAt,
          priorEvidence: priorEvidence,
          retryTranscription: transcription.retryableCloudFailure,
          transcriptionIdempotencyKey: transcription.cloudIdempotencyKey,
          onStage: onStage,
        );
      }

      Reflection reflection;
      final analyzeIdempotency = _usageGuard.idempotencyKey(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
      );
      try {
        reflection = await _postAnalyze(
          transcript: trimmedTranscript,
          captureToken: token,
          priorEvidence: priorEvidence,
          idempotencyKey: analyzeIdempotency,
          entryId: persistedEntryId,
        );
        _usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.analyze,
          success: true,
        );
      } on AuthRequiredException {
        token = await _attest.ensureCaptureToken(forceRefresh: true);
        reflection = await _postAnalyze(
          transcript: trimmedTranscript,
          captureToken: token,
          priorEvidence: priorEvidence,
          idempotencyKey: analyzeIdempotency,
          entryId: persistedEntryId,
        );
        _usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.analyze,
          success: true,
        );
      } catch (e) {
        _usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.analyze,
          success: false,
        );
        return _saveAfterAnalysisFailure(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          transcript: trimmedTranscript,
          error: e,
          entryId: entryId,
          createdAt: createdAt,
          priorEvidence: priorEvidence,
          retryTranscription: transcription.retryableCloudFailure,
          transcriptionIdempotencyKey: transcription.cloudIdempotencyKey,
          onStage: onStage,
        );
      }

      RecordPipelineLog.transcriptLengths(
        transcriptLength: trimmedTranscript.length,
        bodyLength: trimmedTranscript.length,
        observationLength: reflection.concreteObservation.trim().length,
        exactLanguageLength: reflection.exactLanguagePattern.trim().length,
      );

      onStage?.call(PipelineStage.saving);
      final finalTranscript =
          resolveFinalCaptureTranscript(
            transcript: trimmedTranscript,
            body: reflection.concreteObservation,
            exactLanguage: reflection.exactLanguagePattern,
            observation: reflection.concreteObservation,
          ) ??
          trimmedTranscript;
      reflection = reflection.validatedForPersistence(
        transcript: finalTranscript,
        entryId: persistedEntryId,
      );
      RecordPipelineLog.preSaveFinalTranscript(length: finalTranscript.length);
      final template = JournalEntry(
        id: persistedEntryId,
        createdAt: createdAt ?? DateTime.now().toUtc(),
        transcript: trimmedTranscript,
        durationSeconds: durationSeconds,
        reflection: reflection,
        syncStatus: SyncStatus.pendingUpload,
        localAudioVaultRef: _persistedAudioVaultRef(audioFile),
      );
      final prepared = applyFinalTranscriptToVoiceEntry(
        template,
        finalTranscript: finalTranscript,
      );
      final entry = await _saveVoiceEntryAndLog(
        prepared,
        first25Source: 'voice_capture',
        afterInitialSave: transcription.retryableCloudFailure
            ? (saved) => _enqueueTranscriptionRetry(
                entry: saved,
                audioFile: audioFile,
                durationSeconds: durationSeconds,
                idempotencyKey: transcription.cloudIdempotencyKey,
              )
            : null,
      );
      _attest.clearToken();

      onStage?.call(PipelineStage.done);
      return CapturePipelineResult(
        entry: entry,
        localSaved: true,
        syncSucceeded: true,
        analysisSucceeded: true,
      );
    } on CapturePipelineFailure {
      rethrow;
    } on SocketException catch (e) {
      return _handleVoiceCaptureFailure(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        partialTranscript: partialTranscript,
        error: e,
        entryId: entryId,
        createdAt: createdAt,
        priorEvidence: priorEvidence,
        deferFailedTranscription: deferFailedTranscription,
        retryTranscription: transcriptionOutcome?.retryableCloudFailure == true,
        transcriptionIdempotencyKey: transcriptionOutcome?.cloudIdempotencyKey,
        onStage: onStage,
      );
    } on ApiException catch (e) {
      return _handleVoiceCaptureFailure(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        partialTranscript: partialTranscript,
        error: e,
        entryId: entryId,
        createdAt: createdAt,
        priorEvidence: priorEvidence,
        deferFailedTranscription: deferFailedTranscription,
        retryTranscription: transcriptionOutcome?.retryableCloudFailure == true,
        transcriptionIdempotencyKey: transcriptionOutcome?.cloudIdempotencyKey,
        onStage: onStage,
      );
    } on FormatException catch (e) {
      return _handleVoiceCaptureFailure(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        partialTranscript: partialTranscript,
        error: e,
        entryId: entryId,
        createdAt: createdAt,
        priorEvidence: priorEvidence,
        deferFailedTranscription: deferFailedTranscription,
        retryTranscription: transcriptionOutcome?.retryableCloudFailure == true,
        transcriptionIdempotencyKey: transcriptionOutcome?.cloudIdempotencyKey,
        onStage: onStage,
      );
    } catch (e) {
      return _handleVoiceCaptureFailure(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        partialTranscript: partialTranscript,
        error: e,
        entryId: entryId,
        createdAt: createdAt,
        priorEvidence: priorEvidence,
        deferFailedTranscription: deferFailedTranscription,
        retryTranscription: transcriptionOutcome?.retryableCloudFailure == true,
        transcriptionIdempotencyKey: transcriptionOutcome?.cloudIdempotencyKey,
        onStage: onStage,
      );
    }
  }

  Future<CapturePipelineResult> _handleVoiceCaptureFailure({
    required File audioFile,
    required int durationSeconds,
    required String? partialTranscript,
    required Object error,
    String? entryId,
    DateTime? createdAt,
    List<Map<String, dynamic>> priorEvidence = const [],
    bool deferFailedTranscription = false,
    bool retryTranscription = false,
    String? transcriptionIdempotencyKey,
    void Function(PipelineStage stage)? onStage,
  }) {
    if (_hasUsableTranscript(partialTranscript)) {
      return _saveAfterAnalysisFailure(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        transcript: partialTranscript!.trim(),
        error: error,
        entryId: entryId,
        createdAt: createdAt,
        priorEvidence: priorEvidence,
        retryTranscription: retryTranscription,
        transcriptionIdempotencyKey: transcriptionIdempotencyKey,
        onStage: onStage,
      );
    }

    final reason = TranscriptionService.failureReason(error);
    TranscriptionLog.failed(reason: reason);
    if (error is FormatException) {
      RecordPipelineLog.apiGuardBlocked(
        operation: 'response',
        reason: error.message,
      );
    }
    if (deferFailedTranscription) {
      throw CapturePipelineFailure(reason, savedDraft: false);
    }
    return _saveLocalOnly(
      audioFile: audioFile,
      durationSeconds: durationSeconds,
      partialTranscript: null,
      syncNote: error is FormatException
          ? VoiceCaptureCopy.transcriptionFailedDegraded
          : CaptureSaveMessages.syncNoteFor(error),
      transcriptionFailureReason: reason,
      retryTranscription: retryTranscription,
      transcriptionIdempotencyKey: transcriptionIdempotencyKey,
      onStage: onStage,
    );
  }

  Future<CapturePipelineResult> _saveAfterAnalysisFailure({
    required File audioFile,
    required int durationSeconds,
    required String transcript,
    Object? error,
    String? reason,
    String? entryId,
    DateTime? createdAt,
    List<Map<String, dynamic>> priorEvidence = const [],
    bool retryTranscription = false,
    String? transcriptionIdempotencyKey,
    void Function(PipelineStage stage)? onStage,
  }) async {
    final resolvedReason =
        reason ??
        (error == null
            ? 'analysis_unavailable'
            : TranscriptionService.failureReason(error));
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
    final retryAnalysis =
        error != null &&
        classifyCaptureApiRetryFailure(error) !=
            CaptureApiRetryFailure.permanent;
    return _saveLocalOnly(
      audioFile: audioFile,
      durationSeconds: durationSeconds,
      partialTranscript: transcript,
      syncNote: VoiceCaptureCopy.analysisUnavailableNote,
      analysisFailureReason: resolvedReason,
      retryAnalysis: retryAnalysis,
      retryTranscription: retryTranscription,
      transcriptionIdempotencyKey: transcriptionIdempotencyKey,
      analysisIdempotencyKey: _usageGuard.idempotencyKey(
        scopeKey: _audioScopeKey(audioFile.path, durationSeconds),
        operation: ApiUsageOperation.analyze,
      ),
      entryId: entryId,
      createdAt: createdAt,
      priorEvidence: priorEvidence,
      onStage: onStage,
    );
  }

  static bool _hasUsableTranscript(String? transcript) =>
      transcript != null && transcript.trim().isNotEmpty;

  /// Adds typed text to a voice entry that was saved without transcription.
  Future<CapturePipelineResult> attachTypedTextToVoiceEntry({
    required JournalEntry entry,
    required String transcript,
    InterpretationPreference? currentInterpretationChoice,
  }) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      throw CapturePipelineFailure('Enter what you said before saving.');
    }

    final locallySaved = await _attachTypedTextLocally(
      entry: entry,
      trimmed: trimmed,
      syncNote: 'Saved without an interpretation.',
    );
    if (!await _allowsInterpretation(currentInterpretationChoice)) {
      return locallySaved;
    }

    final scopeKey = 'entry:${entry.id}';
    var priorEvidence = const <Map<String, dynamic>>[];
    try {
      var token = await _attest.ensureCaptureToken();
      priorEvidence = await _buildPriorEvidence(excludeEntryId: entry.id);

      final analyzeCheck = _usageGuard.checkAttempt(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
      );
      if (!analyzeCheck.allowed) {
        throw CapturePipelineFailure(
          analyzeCheck.reason ?? VoiceCaptureCopy.transcriptionFailedDegraded,
        );
      }

      Reflection reflection;
      final analyzeIdempotency = _usageGuard.idempotencyKey(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
      );
      try {
        reflection = await _postAnalyze(
          transcript: trimmed,
          captureToken: token,
          priorEvidence: priorEvidence,
          idempotencyKey: analyzeIdempotency,
          entryId: entry.id,
        );
        _usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.analyze,
          success: true,
        );
      } on AuthRequiredException {
        token = await _attest.ensureCaptureToken(forceRefresh: true);
        reflection = await _postAnalyze(
          transcript: trimmed,
          captureToken: token,
          priorEvidence: priorEvidence,
          idempotencyKey: analyzeIdempotency,
          entryId: entry.id,
        );
        _usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.analyze,
          success: true,
        );
      } catch (e) {
        _usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.analyze,
          success: false,
        );
        rethrow;
      }

      final finalTranscript =
          resolveFinalCaptureTranscript(
            transcript: trimmed,
            body: reflection.concreteObservation,
            exactLanguage: reflection.exactLanguagePattern,
            observation: reflection.concreteObservation,
          ) ??
          trimmed;
      reflection = reflection.validatedForPersistence(
        transcript: finalTranscript,
        entryId: entry.id,
      );
      RecordPipelineLog.preSaveFinalTranscript(length: finalTranscript.length);
      final template = JournalEntry(
        id: entry.id,
        createdAt: entry.createdAt,
        transcript: trimmed,
        durationSeconds: entry.durationSeconds,
        reflection: reflection,
        syncStatus: SyncStatus.pendingUpload,
        localAudioPath: entry.localAudioPath,
        localAudioVaultRef: entry.localAudioVaultRef,
        treatAsNew: entry.treatAsNew,
        connectionApproved: entry.connectionApproved,
        keepExactDetails: entry.keepExactDetails,
        keepSeparate: entry.keepSeparate,
        archiveThreadId: entry.archiveThreadId,
        archivePackId: entry.archivePackId,
        isPinned: entry.isPinned,
        pinnedAt: entry.pinnedAt,
        isArchived: entry.isArchived,
        archivedAt: entry.archivedAt,
        entryAboutness: entry.entryAboutness,
        memorySurfacing: entry.memorySurfacing,
        preserveOriginal: entry.preserveOriginal,
        localCaptureContext: entry.localCaptureContext,
      );
      final updated = applyFinalTranscriptToVoiceEntry(
        template,
        finalTranscript: finalTranscript,
      );
      final saved = await _saveVoiceEntryAndLog(
        updated,
        first25Source: 'voice_text_fallback',
      );
      _attest.clearToken();
      RecordPipelineLog.typedTextAttachedToVoiceEntry(entryId: entry.id);
      return CapturePipelineResult(
        entry: saved,
        localSaved: true,
        syncSucceeded: true,
        attachedTypedTextToVoiceEntry: true,
      );
    } on CapturePipelineFailure {
      rethrow;
    } catch (e) {
      return _attachTypedTextLocally(
        entry: entry,
        trimmed: trimmed,
        syncNote: CaptureSaveMessages.syncNoteFor(e),
        retryError: e,
        priorEvidence: priorEvidence,
      );
    }
  }

  Future<CapturePipelineResult> _attachTypedTextLocally({
    required JournalEntry entry,
    required String trimmed,
    required String syncNote,
    Object? retryError,
    List<Map<String, dynamic>> priorEvidence = const [],
  }) async {
    final finalTranscript = resolveFinalCaptureTranscript(
      transcript: trimmed,
      body: trimmed,
      observation: trimmed,
    );
    RecordPipelineLog.preSaveFinalTranscript(
      length: finalTranscript?.length ?? 0,
    );
    final template = JournalEntry(
      id: entry.id,
      createdAt: entry.createdAt,
      transcript: trimmed,
      durationSeconds: entry.durationSeconds,
      reflection: Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: const [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.pendingUpload,
      localAudioPath: entry.localAudioPath,
      localAudioVaultRef: entry.localAudioVaultRef,
      treatAsNew: entry.treatAsNew,
      connectionApproved: entry.connectionApproved,
      keepExactDetails: entry.keepExactDetails,
      keepSeparate: entry.keepSeparate,
      archiveThreadId: entry.archiveThreadId,
      archivePackId: entry.archivePackId,
      isPinned: entry.isPinned,
      pinnedAt: entry.pinnedAt,
      isArchived: entry.isArchived,
      archivedAt: entry.archivedAt,
      entryAboutness: entry.entryAboutness,
      memorySurfacing: entry.memorySurfacing,
      preserveOriginal: entry.preserveOriginal,
      localCaptureContext: entry.localCaptureContext,
    );
    final prepared = applyFinalTranscriptToVoiceEntry(
      template,
      finalTranscript: finalTranscript,
    );
    final updated = await _saveVoiceEntryAndLog(
      prepared,
      first25Source: 'voice_text_fallback',
    );
    if (retryError != null &&
        classifyCaptureApiRetryFailure(retryError) !=
            CaptureApiRetryFailure.permanent) {
      await _enqueueAnalysisRetry(
        entry: updated,
        transcript: trimmed,
        priorEvidence: priorEvidence,
        idempotencyKey: _usageGuard.idempotencyKey(
          scopeKey: 'entry:${entry.id}',
          operation: ApiUsageOperation.analyze,
        ),
      );
    }
    _attest.clearToken();
    RecordPipelineLog.typedTextAttachedToVoiceEntry(entryId: entry.id);
    return CapturePipelineResult(
      entry: updated,
      localSaved: true,
      syncSucceeded: false,
      syncNote: syncNote,
      attachedTypedTextToVoiceEntry: true,
    );
  }

  Future<JournalEntry> _saveVoiceEntryAndLog(
    JournalEntry entry, {
    required String first25Source,
    Future<void> Function(JournalEntry entry)? afterInitialSave,
  }) async {
    await _journalStore.save(entry, first25Source: first25Source);
    await afterInitialSave?.call(entry);
    final saved = entry;
    await _appendCloudConclusion(saved);
    _logSavedEntryReloaded(saved);
    return saved;
  }

  Future<void> _appendCloudConclusion(JournalEntry entry) async {
    final store = _explainabilityHistoryStore;
    final conclusion = entry.reflection.explainableConclusion;
    if (store == null ||
        conclusion == null ||
        conclusion.provenance.generatedBy != 'model') {
      return;
    }
    final gated = ExplainableConclusionRenderGate.visible(
      conclusion,
      canonicalTranscripts: {entry.id: entry.transcript},
    );
    if (gated == null) return;
    try {
      await store.appendIfAbsent(gated);
    } on Object {
      // The journal save is authoritative. A history write can be retried
      // from the persisted conclusion and must not duplicate the capture.
    }
  }

  void _logSavedEntryReloaded(JournalEntry entry) {
    final resolution = resolveEntryDisplayText(entry);
    RecordPipelineLog.persistedCaptureText(
      transcriptLength: entrySanitizedTranscript(entry).length,
      bodyLength: entrySanitizedBody(entry).length,
      displayTextSource: resolution.source.logLabel,
    );
    RecordPipelineLog.savedEntry(
      entryId: entry.id,
      displayTextLength: resolution.text.length,
    );
    final hasUsableDisplay =
        resolution.text.isNotEmpty || hasPersistedCaptureText(entry);
    if (hasUsableDisplay) {
      RecordPipelineLog.voiceSavedTranscriptPresent();
    } else {
      RecordPipelineLog.voiceSavedTranscriptMissing();
    }
  }

  Future<CapturePipelineResult> _saveLocalOnly({
    required File audioFile,
    required int durationSeconds,
    String? partialTranscript,
    required String syncNote,
    String? transcriptionFailureReason,
    String? analysisFailureReason,
    bool lowQualityTranscript = false,
    bool retryTranscription = false,
    String? transcriptionIdempotencyKey,
    bool retryAnalysis = false,
    String? analysisIdempotencyKey,
    String? entryId,
    DateTime? createdAt,
    List<Map<String, dynamic>> priorEvidence = const [],
    void Function(PipelineStage stage)? onStage,
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
    onStage?.call(PipelineStage.saving);
    try {
      final entry = await _saveLocalVoiceEntry(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        partialTranscript: partialTranscript,
        entryId: entryId,
        createdAt: createdAt,
      );
      if (retryTranscription) {
        await _enqueueTranscriptionRetry(
          entry: entry,
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          idempotencyKey: transcriptionIdempotencyKey,
        );
      }
      if (retryAnalysis && _hasUsableTranscript(partialTranscript)) {
        await _enqueueAnalysisRetry(
          entry: entry,
          transcript: partialTranscript!.trim(),
          priorEvidence: priorEvidence,
          idempotencyKey: analysisIdempotencyKey,
        );
      }
      _attest.clearToken();
      onStage?.call(PipelineStage.done);
      return CapturePipelineResult(
        entry: entry,
        localSaved: true,
        syncSucceeded: false,
        analysisSucceeded:
            analysisFailureReason == null &&
            _hasUsableTranscript(partialTranscript),
        syncNote: syncNote,
        lowQualityTranscript: lowQualityTranscript,
      );
    } catch (e) {
      throw CapturePipelineFailure(
        VoiceCaptureCopy.saveFailed,
        savedDraft: false,
      );
    }
  }

  /// Saves or updates a linked local detail entry — no network, no parent overwrite.
  Future<JournalEntry> savePostSaveMomentDetail({
    required JournalEntry parentEntry,
    required PostSaveMomentDetailType detailType,
    required String detailText,
  }) async {
    final trimmed = detailText.trim();
    if (trimmed.isEmpty) {
      throw CapturePipelineFailure('Enter a thought before saving.');
    }

    final tag = PostSaveMomentDetailType.linkedCaptureContextTag(
      type: detailType,
      parentEntryId: parentEntry.id,
    );

    try {
      final all = await _journalStore.loadAll();
      JournalEntry? existing;
      for (final entry in all) {
        if (entry.captureContextTag == tag) {
          existing = entry;
          break;
        }
      }

      if (existing != null) {
        final updated = buildLinkedDetailEntry(
          existing: existing,
          detailText: trimmed,
        );
        await _journalStore.save(
          updated,
          first25Source: 'post_save_detail_update',
        );
        return updated;
      }

      final entry = buildNewLinkedDetailEntry(
        id: _uuid.v4(),
        parentEntryId: parentEntry.id,
        detailType: detailType,
        detailText: trimmed,
        durationSeconds: _estimatedDurationSeconds(trimmed),
      );
      await _journalStore.save(entry, first25Source: 'post_save_detail');
      return entry;
    } catch (e) {
      throw CapturePipelineFailure(
        VoiceCaptureCopy.saveFailed,
        savedDraft: false,
      );
    }
  }

  /// Typed capture — same analyze + journal path as voice, without audio.
  Future<CapturePipelineResult> saveTextThought({
    required String transcript,
    LocalCaptureContext? localCaptureContext,
    InterpretationPreference? currentInterpretationChoice,
    void Function(PipelineStage stage)? onStage,
  }) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      throw CapturePipelineFailure('Enter a thought before saving.');
    }

    final scopeKey = _textScopeKey(trimmed);
    final persistedEntryId = _uuid.v4();
    onStage?.call(PipelineStage.saving);
    final originalEntry = await _saveOfflineTextDraft(
      trimmed,
      entryId: persistedEntryId,
      localCaptureContext: localCaptureContext,
    );
    if (!await _allowsInterpretation(currentInterpretationChoice)) {
      onStage?.call(PipelineStage.done);
      return CapturePipelineResult(
        entry: originalEntry,
        localSaved: true,
        syncSucceeded: false,
        syncNote: 'Saved without an interpretation.',
      );
    }
    var priorEvidence = const <Map<String, dynamic>>[];
    try {
      onStage?.call(PipelineStage.attesting);
      var token = await _attest.ensureCaptureToken();
      priorEvidence = await _buildPriorEvidence(
        excludeEntryId: persistedEntryId,
      );

      onStage?.call(PipelineStage.analyzing);
      final analyzeCheck = _usageGuard.checkAttempt(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
      );
      if (!analyzeCheck.allowed) {
        return _saveTextLocalOnly(
          transcript: trimmed,
          localCaptureContext: localCaptureContext,
          syncNote:
              analyzeCheck.reason ??
              VoiceCaptureCopy.transcriptionFailedDegraded,
          existingEntry: originalEntry,
          onStage: onStage,
        );
      }

      Reflection reflection;
      final analyzeIdempotency = _usageGuard.idempotencyKey(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
      );
      try {
        reflection = await _postAnalyze(
          transcript: trimmed,
          captureToken: token,
          priorEvidence: priorEvidence,
          idempotencyKey: analyzeIdempotency,
          entryId: persistedEntryId,
        );
        _usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.analyze,
          success: true,
        );
      } on AuthRequiredException {
        token = await _attest.ensureCaptureToken(forceRefresh: true);
        reflection = await _postAnalyze(
          transcript: trimmed,
          captureToken: token,
          priorEvidence: priorEvidence,
          idempotencyKey: analyzeIdempotency,
          entryId: persistedEntryId,
        );
        _usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.analyze,
          success: true,
        );
      } catch (e) {
        _usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.analyze,
          success: false,
        );
        rethrow;
      }

      onStage?.call(PipelineStage.saving);
      reflection = reflection.validatedForPersistence(
        transcript: trimmed,
        entryId: persistedEntryId,
      );
      final entry = JournalEntry(
        id: persistedEntryId,
        createdAt: DateTime.now().toUtc(),
        transcript: trimmed,
        durationSeconds: _estimatedDurationSeconds(trimmed),
        reflection: reflection,
        syncStatus: SyncStatus.pendingUpload,
        localCaptureContext: localCaptureContext,
      );
      await _journalStore.save(entry, first25Source: 'text_capture');
      await _appendCloudConclusion(entry);
      _attest.clearToken();

      onStage?.call(PipelineStage.done);
      return CapturePipelineResult(
        entry: entry,
        localSaved: true,
        syncSucceeded: true,
      );
    } on SocketException catch (e) {
      return _saveTextLocalOnly(
        transcript: trimmed,
        localCaptureContext: localCaptureContext,
        syncNote: CaptureSaveMessages.syncNoteFor(e),
        retryError: e,
        priorEvidence: priorEvidence,
        existingEntry: originalEntry,
        onStage: onStage,
      );
    } on ApiException catch (e) {
      return _saveTextLocalOnly(
        transcript: trimmed,
        localCaptureContext: localCaptureContext,
        syncNote: CaptureSaveMessages.syncNoteFor(e),
        retryError: e,
        priorEvidence: priorEvidence,
        existingEntry: originalEntry,
        onStage: onStage,
      );
    } on FormatException catch (e) {
      RecordPipelineLog.apiGuardBlocked(
        operation: 'response',
        reason: e.message,
      );
      return _saveTextLocalOnly(
        transcript: trimmed,
        localCaptureContext: localCaptureContext,
        syncNote: VoiceCaptureCopy.transcriptionFailedDegraded,
        existingEntry: originalEntry,
        onStage: onStage,
      );
    } catch (e) {
      return _saveTextLocalOnly(
        transcript: trimmed,
        localCaptureContext: localCaptureContext,
        syncNote: CaptureSaveMessages.syncNoteFor(e),
        retryError: e,
        priorEvidence: priorEvidence,
        existingEntry: originalEntry,
        onStage: onStage,
      );
    }
  }

  /// Live voice capture — transcript already assembled from Gemini Live events.
  Future<CapturePipelineResult> saveLiveVoiceTranscript({
    required String transcript,
    required int durationSeconds,
    LocalCaptureContext? localCaptureContext,
    InterpretationPreference? currentInterpretationChoice,
    void Function(PipelineStage stage)? onStage,
  }) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      throw CapturePipelineFailure('No live transcript was captured.');
    }

    final scopeKey = _textScopeKey(trimmed);
    final persistedEntryId = _uuid.v4();
    final original = await _saveLiveVoiceLocalOnly(
      transcript: trimmed,
      durationSeconds: durationSeconds,
      entryId: persistedEntryId,
      localCaptureContext: localCaptureContext,
      syncNote: 'Saved without an interpretation.',
      onStage: onStage,
    );
    if (!await _allowsInterpretation(currentInterpretationChoice)) {
      return original;
    }
    var priorEvidence = const <Map<String, dynamic>>[];
    try {
      onStage?.call(PipelineStage.attesting);
      var token = await _attest.ensureCaptureToken();
      priorEvidence = await _buildPriorEvidence(
        excludeEntryId: persistedEntryId,
      );

      onStage?.call(PipelineStage.analyzing);
      final analyzeCheck = _usageGuard.checkAttempt(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
      );
      if (!analyzeCheck.allowed) {
        return _saveLiveVoiceLocalOnly(
          transcript: trimmed,
          durationSeconds: durationSeconds,
          entryId: persistedEntryId,
          localCaptureContext: localCaptureContext,
          syncNote:
              analyzeCheck.reason ??
              VoiceCaptureCopy.transcriptionFailedDegraded,
          onStage: onStage,
        );
      }

      Reflection reflection;
      final analyzeIdempotency = _usageGuard.idempotencyKey(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
      );
      try {
        reflection = await _postAnalyze(
          transcript: trimmed,
          captureToken: token,
          priorEvidence: priorEvidence,
          idempotencyKey: analyzeIdempotency,
          entryId: persistedEntryId,
        );
        _usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.analyze,
          success: true,
        );
      } on AuthRequiredException {
        token = await _attest.ensureCaptureToken(forceRefresh: true);
        reflection = await _postAnalyze(
          transcript: trimmed,
          captureToken: token,
          priorEvidence: priorEvidence,
          idempotencyKey: analyzeIdempotency,
          entryId: persistedEntryId,
        );
        _usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.analyze,
          success: true,
        );
      } catch (e) {
        _usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.analyze,
          success: false,
        );
        rethrow;
      }

      onStage?.call(PipelineStage.saving);
      reflection = reflection.validatedForPersistence(
        transcript: trimmed,
        entryId: persistedEntryId,
      );
      final entry = JournalEntry(
        id: persistedEntryId,
        createdAt: DateTime.now().toUtc(),
        transcript: trimmed,
        durationSeconds: durationSeconds.clamp(1, 999999),
        reflection: reflection,
        syncStatus: SyncStatus.pendingUpload,
        captureContextTag: 'live_voice_capture',
        localCaptureContext: localCaptureContext,
      );
      await _journalStore.save(entry, first25Source: 'live_voice_capture');
      await _appendCloudConclusion(entry);
      _attest.clearToken();

      onStage?.call(PipelineStage.done);
      return CapturePipelineResult(
        entry: entry,
        localSaved: true,
        syncSucceeded: true,
        analysisSucceeded: true,
      );
    } on SocketException catch (e) {
      return _saveLiveVoiceLocalOnly(
        transcript: trimmed,
        durationSeconds: durationSeconds,
        entryId: persistedEntryId,
        localCaptureContext: localCaptureContext,
        syncNote: CaptureSaveMessages.syncNoteFor(e),
        retryError: e,
        priorEvidence: priorEvidence,
        onStage: onStage,
      );
    } on ApiException catch (e) {
      return _saveLiveVoiceLocalOnly(
        transcript: trimmed,
        durationSeconds: durationSeconds,
        entryId: persistedEntryId,
        localCaptureContext: localCaptureContext,
        syncNote: CaptureSaveMessages.syncNoteFor(e),
        retryError: e,
        priorEvidence: priorEvidence,
        onStage: onStage,
      );
    } on FormatException catch (e) {
      RecordPipelineLog.apiGuardBlocked(
        operation: 'response',
        reason: e.message,
      );
      return _saveLiveVoiceLocalOnly(
        transcript: trimmed,
        durationSeconds: durationSeconds,
        entryId: persistedEntryId,
        localCaptureContext: localCaptureContext,
        syncNote: VoiceCaptureCopy.transcriptionFailedDegraded,
        onStage: onStage,
      );
    } catch (e) {
      return _saveLiveVoiceLocalOnly(
        transcript: trimmed,
        durationSeconds: durationSeconds,
        entryId: persistedEntryId,
        localCaptureContext: localCaptureContext,
        syncNote: CaptureSaveMessages.syncNoteFor(e),
        retryError: e,
        priorEvidence: priorEvidence,
        onStage: onStage,
      );
    }
  }

  /// Saves a journal entry from a server-recovered offline live-audio vault.
  Future<CapturePipelineResult> saveRecoveredVaultEntry({
    required String transcript,
    required Reflection reflection,
    required int durationSeconds,
    void Function(PipelineStage stage)? onStage,
  }) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      throw CapturePipelineFailure('Recovered vault transcript was empty.');
    }

    onStage?.call(PipelineStage.saving);
    final persistedEntryId = _uuid.v4();
    final validatedReflection = reflection.validatedForPersistence(
      transcript: trimmed,
      entryId: persistedEntryId,
    );
    final entry = JournalEntry(
      id: persistedEntryId,
      createdAt: DateTime.now().toUtc(),
      transcript: trimmed,
      durationSeconds: durationSeconds.clamp(1, 999999),
      reflection: validatedReflection,
      syncStatus: SyncStatus.pendingUpload,
      captureContextTag: 'live_voice_vault_recovery',
    );
    await _journalStore.save(entry, first25Source: 'live_voice_vault_recovery');
    await _appendCloudConclusion(entry);
    _attest.clearToken();
    onStage?.call(PipelineStage.done);
    return CapturePipelineResult(
      entry: entry,
      localSaved: true,
      syncSucceeded: true,
      analysisSucceeded: true,
    );
  }

  Future<CapturePipelineResult> _saveLiveVoiceLocalOnly({
    required String transcript,
    required int durationSeconds,
    String? entryId,
    LocalCaptureContext? localCaptureContext,
    required String syncNote,
    Object? retryError,
    List<Map<String, dynamic>> priorEvidence = const [],
    void Function(PipelineStage stage)? onStage,
  }) async {
    onStage?.call(PipelineStage.saving);
    final entry = JournalEntry(
      id: entryId ?? _uuid.v4(),
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
      syncStatus: SyncStatus.localOnly,
      captureContextTag: 'live_voice_capture',
      localCaptureContext: localCaptureContext,
    );
    await _journalStore.save(entry, first25Source: 'live_voice_capture');
    if (retryError != null &&
        classifyCaptureApiRetryFailure(retryError) !=
            CaptureApiRetryFailure.permanent) {
      await _enqueueAnalysisRetry(
        entry: entry,
        transcript: transcript,
        priorEvidence: priorEvidence,
        idempotencyKey: _usageGuard.idempotencyKey(
          scopeKey: _textScopeKey(transcript),
          operation: ApiUsageOperation.analyze,
        ),
      );
    }
    _attest.clearToken();
    onStage?.call(PipelineStage.done);
    return CapturePipelineResult(
      entry: entry,
      localSaved: true,
      syncSucceeded: false,
      syncNote: syncNote,
    );
  }

  int _estimatedDurationSeconds(String transcript) {
    final chars = transcript.trim().length;
    return (chars / 15).ceil().clamp(1, 120);
  }

  Future<CapturePipelineResult> _saveTextLocalOnly({
    required String transcript,
    LocalCaptureContext? localCaptureContext,
    required String syncNote,
    Object? retryError,
    List<Map<String, dynamic>> priorEvidence = const [],
    JournalEntry? existingEntry,
    void Function(PipelineStage stage)? onStage,
  }) async {
    onStage?.call(PipelineStage.saving);
    try {
      final entry =
          existingEntry ??
          await _saveOfflineTextDraft(
            transcript,
            localCaptureContext: localCaptureContext,
          );
      if (retryError != null &&
          classifyCaptureApiRetryFailure(retryError) !=
              CaptureApiRetryFailure.permanent) {
        await _enqueueAnalysisRetry(
          entry: entry,
          transcript: transcript,
          priorEvidence: priorEvidence,
          idempotencyKey: _usageGuard.idempotencyKey(
            scopeKey: _textScopeKey(transcript),
            operation: ApiUsageOperation.analyze,
          ),
        );
      }
      _attest.clearToken();
      onStage?.call(PipelineStage.done);
      return CapturePipelineResult(
        entry: entry,
        localSaved: true,
        syncSucceeded: false,
        syncNote: syncNote,
      );
    } catch (e) {
      throw CapturePipelineFailure(
        VoiceCaptureCopy.saveFailed,
        savedDraft: false,
      );
    }
  }

  Future<JournalEntry> _saveOfflineTextDraft(
    String transcript, {
    String? entryId,
    LocalCaptureContext? localCaptureContext,
  }) async {
    final trimmed = transcript.trim();
    final entry = JournalEntry(
      id: entryId ?? _uuid.v4(),
      createdAt: DateTime.now().toUtc(),
      transcript: trimmed,
      durationSeconds: _estimatedDurationSeconds(trimmed),
      reflection: Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: const [],
        exactLanguagePattern: '',
        concreteObservation: CaptureSaveMessages.savedPrivatelyOnDevice,
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.pendingUpload,
      localCaptureContext: localCaptureContext,
    );
    await _journalStore.save(entry, first25Source: 'offline_text_capture');
    return entry;
  }

  Future<JournalEntry> _saveLocalVoiceEntry({
    required File audioFile,
    required int durationSeconds,
    String? partialTranscript,
    String? entryId,
    DateTime? createdAt,
  }) async {
    final draftPlaceholder =
        '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';
    final finalTranscript = resolveFinalCaptureTranscript(
      transcript: partialTranscript,
      body: partialTranscript,
      observation: partialTranscript,
    );
    RecordPipelineLog.preSaveFinalTranscript(
      length: finalTranscript?.length ?? 0,
    );

    final template = JournalEntry(
      id: entryId ?? _uuid.v4(),
      createdAt: createdAt ?? DateTime.now().toUtc(),
      // A usable cloud or on-device transcript is a normal local-first entry.
      // The draft marker is reserved for total transcription failure only.
      transcript: finalTranscript ?? draftPlaceholder,
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
      localAudioVaultRef: _persistedAudioVaultRef(audioFile),
    );
    final prepared = applyFinalTranscriptToVoiceEntry(
      template,
      finalTranscript: finalTranscript,
      draftPlaceholder: draftPlaceholder,
    );
    return _saveVoiceEntryAndLog(
      prepared,
      first25Source: 'offline_voice_capture',
    );
  }

  Future<void> _enqueueTranscriptionRetry({
    required JournalEntry entry,
    required File audioFile,
    required int durationSeconds,
    String? idempotencyKey,
  }) async {
    final queue = _retryQueue;
    if (queue == null) return;
    try {
      final vaultReference = entry.localAudioVaultRef?.trim();
      final retryIdempotencyKey =
          idempotencyKey ??
          _usageGuard.idempotencyKey(
            scopeKey: _audioScopeKey(audioFile.path, durationSeconds),
            operation: ApiUsageOperation.transcribe,
          );
      if (vaultReference != null && vaultReference.isNotEmpty) {
        await queue.enqueueTranscribeVault(
          entryId: entry.id,
          vaultReference: vaultReference,
          durationSeconds: durationSeconds,
          idempotencyKey: retryIdempotencyKey,
        );
      }
    } on Object {
      // The journal entry is the primary local save. Queue persistence must
      // never turn a successful local capture into a user-visible failure.
    }
  }

  String? _persistedAudioVaultRef(File sourceFile) =>
      _vaultReferenceBySourcePath[sourceFile.path];

  Future<void> _removeSourceAfterEncryption(
    AudioVaultService vault,
    File source,
  ) async {
    try {
      await _temporaryAudioStore.markEncryptionComplete(
        file: source,
        ownerId: 'voice-capture',
      );
    } on Object {
      await vault.secureDeletePlaintext(source);
    }
  }

  Future<void> _enqueueAnalysisRetry({
    required JournalEntry entry,
    required String transcript,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
  }) async {
    final queue = _retryQueue;
    if (queue == null) return;
    try {
      await queue.enqueueAnalyze(
        entryId: entry.id,
        transcript: transcript,
        priorEvidence: priorEvidence.isNotEmpty
            ? priorEvidence
            : await _buildPriorEvidence(excludeEntryId: entry.id),
        idempotencyKey:
            idempotencyKey ??
            _usageGuard.idempotencyKey(
              scopeKey: 'entry:${entry.id}',
              operation: ApiUsageOperation.analyze,
            ),
      );
    } on Object {
      // Preserve local-first capture even if encrypted queue storage fails.
    }
  }

  Future<Reflection> _postAnalyze({
    required String transcript,
    required String captureToken,
    required List<Map<String, dynamic>> priorEvidence,
    required String idempotencyKey,
    required String entryId,
  }) async {
    return _api.postAnalyze(
      transcript: transcript,
      captureToken: captureToken,
      priorEvidence: priorEvidence,
      idempotencyKey: idempotencyKey,
      entryId: entryId,
    );
  }

  Future<List<Map<String, dynamic>>> _buildPriorEvidence({
    String? excludeEntryId,
  }) => const PriorAnalysisEvidenceBuilder().build(
    journalStore: _journalStore,
    excludeEntryId: excludeEntryId,
  );

  Future<TranscriptionPreference> _resolvedTranscriptionPreference(
    TranscriptionPreference? currentChoice,
  ) async {
    if (currentChoice != null) return currentChoice;
    try {
      return (await _processingPreferences.read()).transcription;
    } on Object {
      return TranscriptionPreference.askEachTime;
    }
  }

  Future<bool> _allowsInterpretation(
    InterpretationPreference? currentChoice,
  ) async {
    InterpretationPreference choice;
    if (currentChoice != null) {
      choice = currentChoice;
    } else {
      try {
        choice = (await _processingPreferences.read()).interpretation;
      } on Object {
        return false;
      }
    }
    if (choice != InterpretationPreference.generatePossibleRead) return false;
    return _hasCurrentDisclosure(RemoteProcessingPurpose.interpretation);
  }

  Future<bool> _hasCurrentDisclosure(RemoteProcessingPurpose purpose) async {
    try {
      return (await _remoteDisclosure.check(purpose: purpose)).isAccepted;
    } on Object {
      return false;
    }
  }

  static String _audioScopeKey(String path, int durationSeconds) =>
      'audio:$path:$durationSeconds';

  static String _textScopeKey(String transcript) =>
      'text:${UserContentSafety.privacyHash(transcript)}';
}

final class _OfflineTranscriptionConnectivity
    implements TranscriptionConnectivity {
  const _OfflineTranscriptionConnectivity();

  @override
  Future<bool> isOnline() async => false;
}
