import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/core/network/capture_pipeline_api_errors.dart';
import 'package:archiveme_mobile/data/repositories/capture_repository.dart';
import 'package:archiveme_mobile/features/moment_quality/post_save_moment_detail_model.dart';
import 'package:archiveme_mobile/features/moment_quality/post_save_moment_detail_service.dart';
import 'package:archiveme_mobile/features/proof_admission/archive_correction_store.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_analytics.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_service.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_scope_provider.dart';
import 'package:archiveme_mobile/features/proof_admission/related_source_resolver.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/features/voice_capture/analysis/analysis_log.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_log.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_service.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/models/transcript_status.dart';
import 'package:archiveme_mobile/security/account_session_guard.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/security/private_data_service.dart';
import 'package:archiveme_mobile/security/user_content_safety.dart';
import 'package:archiveme_mobile/services/capture_attest_service.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/services/product_analytics.dart';
import 'package:archiveme_mobile/services/record_pipeline_log.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';

class CapturePipelineFailure implements Exception {
  CapturePipelineFailure(this.message, {this.savedDraft = false, this.entry});

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
    required this._captureRepository,
    required this._attest,
    required this._journalStore,
    required this.consentStore, this._scopeProvider = const AppServicesProofScopeProvider(),
    ApiUsageGuard? usageGuard,
  }) : _usageGuard = usageGuard ?? ApiUsageGuard.shared;

  final CaptureRepository _captureRepository;
  final CaptureAttestService _attest;
  final JournalStore _journalStore;
  final ApiUsageGuard _usageGuard;

  /// Which account/guest namespace and archive newly-admitted proofs and
  /// resolved related sources are stamped with. Read live on every access
  /// (never cached at construction) — see [ProofScopeProvider] — so an
  /// account switch is reflected immediately rather than only after this
  /// service is rebuilt. In production `AppServices` does rebuild this
  /// service fresh on every switch anyway (see `_wireAccountScopedServices`),
  /// but nothing here should depend on that to be correct.
  final ProofScopeProvider _scopeProvider;
  String get _archiveScope => _scopeProvider.activeArchiveScope;
  String get _ownerScope => _scopeProvider.activeOwnerScope;

  /// Account-scoped consent for remote transcript processing — injected at
  /// composition root so pipeline runs stay off the service locator.
  final RemoteProcessingConsentStore consentStore;

  /// Purpose-specific consent for remote work — fails closed on read errors.
  Future<bool> _isPurposeGranted(RemoteProcessingPurpose purpose) async {
    try {
      return await consentStore.isPurposeGrantedNow(purpose);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _remoteProcessingConsented() =>
      _isPurposeGranted(RemoteProcessingPurpose.remoteReflection);

  final CanonicalProofAdmissionService _proofAdmission =
      CanonicalProofAdmissionService(
        correctionPolicy: ArchiveCorrectionStore.instance,
      );

  Future<CapturePipelineResult> run({
    required File audioFile,
    required int durationSeconds,
    void Function(PipelineStage stage)? onStage,
  }) async {
    final session = AccountSessionGuard.capture();
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

    String? partialTranscript;
    final scopeKey = _audioScopeKey(audioFile.path, durationSeconds);
    try {
      if (!await _isPurposeGranted(RemoteProcessingPurpose.remoteTranscription)) {
        const reason = 'remote_processing_consent_missing';
        RecordPipelineLog.apiGuardBlocked(
          operation: 'transcribe',
          reason: reason,
        );
        return _saveLocalOnly(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          syncNote: VoiceCaptureCopy.remoteProcessingConsentPausedNote,
          transcriptionFailureReason: reason,
          onStage: onStage,
        );
      }

      onStage?.call(PipelineStage.attesting);
      var token = await _attest.ensureCaptureToken();

      onStage?.call(PipelineStage.transcribing);
      final transcription = await TranscriptionService.transcribeRecording(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        captureRepository: _captureRepository,
        ensureCaptureToken: _attest.ensureCaptureToken,
        scopeKey: scopeKey,
        usageGuard: _usageGuard,
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
          syncNote: VoiceCaptureCopy.transcriptionFailedDegraded,
          transcriptionFailureReason: reason,
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
        return _saveLocalOnly(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          syncNote: CaptureSaveMessages.syncUnavailableOffline,
          transcriptionFailureReason: reason,
          onStage: onStage,
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
          onStage: onStage,
        );
      }

      onStage?.call(PipelineStage.analyzing);
      if (!await _isPurposeGranted(RemoteProcessingPurpose.remoteReflection)) {
        const reason = 'remote_processing_consent_missing';
        RecordPipelineLog.apiGuardBlocked(operation: 'analyze', reason: reason);
        return _saveAfterAnalysisFailure(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          transcript: trimmedTranscript,
          reason: reason,
          syncNote: VoiceCaptureCopy.remoteProcessingConsentPausedNote,
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
          onStage: onStage,
        );
      }

      final entryId = JournalSyncIds.newOfflineEntryId();
      VerifiedProof verifiedProof;
      final analyzeIdempotency = _usageGuard.idempotencyKey(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
      );
      try {
        verifiedProof = await _postAndAdmit(
          transcript: trimmedTranscript,
          captureToken: token,
          idempotencyKey: analyzeIdempotency,
          entryId: entryId,
          sourceType: ProofSourceType.userVoiceTranscript,
        );
        _usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.analyze,
          success: true,
        );
      } on AuthRequiredException {
        token = await _attest.ensureCaptureToken(forceRefresh: true);
        verifiedProof = await _postAndAdmit(
          transcript: trimmedTranscript,
          captureToken: token,
          idempotencyKey: analyzeIdempotency,
          entryId: entryId,
          sourceType: ProofSourceType.userVoiceTranscript,
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
          onStage: onStage,
        );
      }

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

      onStage?.call(PipelineStage.saving);
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
      final entry = await _saveVoiceEntryAndLog(
        prepared,
        first25Source: 'voice_capture',
        session: session,
      );
      _attest.clearToken();

      onStage?.call(PipelineStage.done);
      return CapturePipelineResult(
        entry: entry,
        localSaved: true,
        syncSucceeded: true,
        analysisSucceeded: true,
      );
    } catch (e) {
      return _handleVoiceCaptureFailure(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        partialTranscript: partialTranscript,
        error: e,
        onStage: onStage,
      );
    }
  }

  Future<CapturePipelineResult> _handleVoiceCaptureFailure({
    required File audioFile,
    required int durationSeconds,
    required String? partialTranscript,
    required Object error,
    void Function(PipelineStage stage)? onStage,
  }) {
    if (_hasUsableTranscript(partialTranscript)) {
      return _saveAfterAnalysisFailure(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        transcript: partialTranscript!.trim(),
        error: error,
        onStage: onStage,
      );
    }

    final reason = CapturePipelineApiErrors.failureReason(error);
    TranscriptionLog.failed(reason: reason);
    final invalidMessage = CapturePipelineApiErrors.invalidResponseMessage(
      error,
    );
    if (invalidMessage != null) {
      RecordPipelineLog.apiGuardBlocked(
        operation: 'response',
        reason: invalidMessage,
      );
    }
    return _saveLocalOnly(
      audioFile: audioFile,
      durationSeconds: durationSeconds,
      syncNote: CapturePipelineApiErrors.syncNoteFor(error),
      transcriptionFailureReason: reason,
      onStage: onStage,
    );
  }

  Future<CapturePipelineResult> _saveProvisionalNativeTranscript({
    required File audioFile,
    required int durationSeconds,
    required String transcript,
    void Function(PipelineStage stage)? onStage,
  }) async {
    RecordPipelineLog.transcriptionFallback(
      reason: 'native_provisional_stt',
      audioPath: audioFile.path,
    );
    onStage?.call(PipelineStage.saving);
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
    final entry = await _saveVoiceEntryAndLog(
      prepared,
      first25Source: 'native_provisional_voice_capture',
    );
    _attest.clearToken();
    onStage?.call(PipelineStage.done);
    return CapturePipelineResult(
      entry: entry,
      localSaved: true,
      syncSucceeded: false,
      analysisSucceeded: false,
      syncNote: VoiceCaptureCopy.transcriptionFailedDegraded,
    );
  }

  Future<CapturePipelineResult> _saveAfterAnalysisFailure({
    required File audioFile,
    required int durationSeconds,
    required String transcript,
    Object? error,
    String? reason,
    String syncNote = VoiceCaptureCopy.analysisUnavailableNote,
    void Function(PipelineStage stage)? onStage,
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
      onStage: onStage,
    );
  }

  static bool _hasUsableTranscript(String? transcript) =>
      transcript != null && transcript.trim().isNotEmpty;

  /// Adds typed text to a voice entry that was saved without transcription.
  Future<CapturePipelineResult> attachTypedTextToVoiceEntry({
    required JournalEntry entry,
    required String transcript,
  }) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      throw CapturePipelineFailure('Enter what you said before saving.');
    }

    final scopeKey = 'entry:${entry.id}';
    try {
      if (!await _isPurposeGranted(RemoteProcessingPurpose.remoteReflection)) {
        return _attachTypedTextLocally(
          entry: entry,
          trimmed: trimmed,
          syncNote: VoiceCaptureCopy.remoteProcessingConsentPausedNote,
        );
      }

      var token = await _attest.ensureCaptureToken();
      final analyzeCheck = _usageGuard.checkAttempt(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
      );
      if (!analyzeCheck.allowed) {
        throw CapturePipelineFailure(
          analyzeCheck.reason ?? VoiceCaptureCopy.transcriptionFailedDegraded,
        );
      }

      VerifiedProof verifiedProof;
      final analyzeIdempotency = _usageGuard.idempotencyKey(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
      );
      try {
        verifiedProof = await _postAndAdmit(
          transcript: trimmed,
          captureToken: token,
          idempotencyKey: analyzeIdempotency,
          entryId: entry.id,
          sourceType: ProofSourceType.userVoiceTranscript,
        );
        _usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.analyze,
          success: true,
        );
      } on AuthRequiredException {
        token = await _attest.ensureCaptureToken(forceRefresh: true);
        verifiedProof = await _postAndAdmit(
          transcript: trimmed,
          captureToken: token,
          idempotencyKey: analyzeIdempotency,
          entryId: entry.id,
          sourceType: ProofSourceType.userVoiceTranscript,
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
      );
    }
  }

  Future<CapturePipelineResult> _attachTypedTextLocally({
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
    final updated = await _saveVoiceEntryAndLog(
      prepared,
      first25Source: 'voice_text_fallback',
    );
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
    AccountSessionGuard? session,
  }) async {
    session?.assertActive();
    await _journalStore.save(entry, first25Source: first25Source);
    await TempRecordingCleanup.purgeRetryRecordings();
    final saved = await TempRecordingCleanup.releaseTempAudioIfSafe(
      entry,
      _journalStore,
    );
    _logSavedEntryReloaded(saved);
    return saved;
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
    required String syncNote, String? partialTranscript,
    String? transcriptionFailureReason,
    String? analysisFailureReason,
    bool lowQualityTranscript = false,
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
      final entry = await _saveOfflineDraft(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        partialTranscript: partialTranscript,
      );
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
        id: JournalSyncIds.newOfflineEntryId(),
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
      );
    }
  }

  /// Typed capture — same analyze + journal path as voice, without audio.
  Future<CapturePipelineResult> saveTextThought({
    required String transcript,
    void Function(PipelineStage stage)? onStage,
  }) async {
    final session = AccountSessionGuard.capture();
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      throw CapturePipelineFailure('Enter a thought before saving.');
    }

    final scopeKey = _textScopeKey(trimmed);
    try {
      if (!await _isPurposeGranted(RemoteProcessingPurpose.remoteReflection)) {
        return _saveTextLocalOnly(
          transcript: trimmed,
          syncNote: VoiceCaptureCopy.remoteProcessingConsentPausedNote,
          onStage: onStage,
        );
      }

      onStage?.call(PipelineStage.attesting);
      var token = await _attest.ensureCaptureToken();

      onStage?.call(PipelineStage.analyzing);
      final analyzeCheck = _usageGuard.checkAttempt(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
      );
      if (!analyzeCheck.allowed) {
        return _saveTextLocalOnly(
          transcript: trimmed,
          syncNote:
              analyzeCheck.reason ??
              VoiceCaptureCopy.transcriptionFailedDegraded,
          onStage: onStage,
        );
      }

      final entryId = JournalSyncIds.newOfflineEntryId();
      VerifiedProof verifiedProof;
      final analyzeIdempotency = _usageGuard.idempotencyKey(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
      );
      try {
        verifiedProof = await _postAndAdmit(
          transcript: trimmed,
          captureToken: token,
          idempotencyKey: analyzeIdempotency,
          entryId: entryId,
          sourceType: ProofSourceType.userTyped,
        );
        _usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.analyze,
          success: true,
        );
      } on AuthRequiredException {
        token = await _attest.ensureCaptureToken(forceRefresh: true);
        verifiedProof = await _postAndAdmit(
          transcript: trimmed,
          captureToken: token,
          idempotencyKey: analyzeIdempotency,
          entryId: entryId,
          sourceType: ProofSourceType.userTyped,
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
      final entry = JournalEntry(
        id: entryId,
        createdAt: DateTime.now().toUtc(),
        transcript: trimmed,
        durationSeconds: _estimatedDurationSeconds(trimmed),
        reflection: verifiedProof.reflection,
        verifiedProof: verifiedProof,
        syncStatus: SyncStatus.pendingUpload,
      );
      session.assertActive();
      await _journalStore.save(entry, first25Source: 'text_capture');
      _attest.clearToken();

      onStage?.call(PipelineStage.done);
      return CapturePipelineResult(
        entry: entry,
        localSaved: true,
        syncSucceeded: true,
      );
    } catch (e) {
      final invalidMessage = CapturePipelineApiErrors.invalidResponseMessage(e);
      if (invalidMessage != null) {
        RecordPipelineLog.apiGuardBlocked(
          operation: 'response',
          reason: invalidMessage,
        );
      }
      return _saveTextLocalOnly(
        transcript: trimmed,
        syncNote: CapturePipelineApiErrors.syncNoteFor(e),
        onStage: onStage,
      );
    }
  }

  /// Image + caption capture — persists caption via typed capture path.
  Future<CapturePipelineResult> saveImageCaptionEntry({
    required String caption,
    required ImageEvidence imageEvidence,
    void Function(PipelineStage stage)? onStage,
  }) {
    return saveTextThought(transcript: caption, onStage: onStage);
  }

  /// Live voice capture — transcript already assembled from Gemini Live events.
  Future<CapturePipelineResult> saveLiveVoiceTranscript({
    required String transcript,
    required int durationSeconds,
    void Function(PipelineStage stage)? onStage,
  }) async {
    final session = AccountSessionGuard.capture();
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      throw CapturePipelineFailure('No live transcript was captured.');
    }

    final scopeKey = _textScopeKey(trimmed);
    try {
      if (!await _isPurposeGranted(RemoteProcessingPurpose.remoteReflection)) {
        return _saveLiveVoiceLocalOnly(
          transcript: trimmed,
          durationSeconds: durationSeconds,
          syncNote: VoiceCaptureCopy.remoteProcessingConsentPausedNote,
          onStage: onStage,
        );
      }

      onStage?.call(PipelineStage.attesting);
      var token = await _attest.ensureCaptureToken();

      onStage?.call(PipelineStage.analyzing);
      final analyzeCheck = _usageGuard.checkAttempt(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
      );
      if (!analyzeCheck.allowed) {
        return _saveLiveVoiceLocalOnly(
          transcript: trimmed,
          durationSeconds: durationSeconds,
          syncNote:
              analyzeCheck.reason ??
              VoiceCaptureCopy.transcriptionFailedDegraded,
          onStage: onStage,
        );
      }

      final entryId = JournalSyncIds.newOfflineEntryId();
      VerifiedProof verifiedProof;
      final analyzeIdempotency = _usageGuard.idempotencyKey(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
      );
      try {
        verifiedProof = await _postAndAdmit(
          transcript: trimmed,
          captureToken: token,
          idempotencyKey: analyzeIdempotency,
          entryId: entryId,
          sourceType: ProofSourceType.userVoiceTranscript,
        );
        _usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.analyze,
          success: true,
        );
      } on AuthRequiredException {
        token = await _attest.ensureCaptureToken(forceRefresh: true);
        verifiedProof = await _postAndAdmit(
          transcript: trimmed,
          captureToken: token,
          idempotencyKey: analyzeIdempotency,
          entryId: entryId,
          sourceType: ProofSourceType.userVoiceTranscript,
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
      await _journalStore.save(entry, first25Source: 'live_voice_capture');
      _attest.clearToken();

      onStage?.call(PipelineStage.done);
      return CapturePipelineResult(
        entry: entry,
        localSaved: true,
        syncSucceeded: true,
        analysisSucceeded: true,
      );
    } catch (e) {
      final invalidMessage = CapturePipelineApiErrors.invalidResponseMessage(e);
      if (invalidMessage != null) {
        RecordPipelineLog.apiGuardBlocked(
          operation: 'response',
          reason: invalidMessage,
        );
      }
      return _saveLiveVoiceLocalOnly(
        transcript: trimmed,
        durationSeconds: durationSeconds,
        syncNote: CapturePipelineApiErrors.syncNoteFor(e),
        onStage: onStage,
      );
    }
  }

  /// Saves a journal entry from a server-recovered offline live-audio vault.
  Future<CapturePipelineResult> saveRecoveredVaultEntry({
    required String transcript,
    required Map<String, dynamic> reflectionJson,
    required int durationSeconds,
    required bool remoteProcessingConsented,
    void Function(PipelineStage stage)? onStage,
  }) async {
    final session = AccountSessionGuard.capture();
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      throw CapturePipelineFailure('Recovered vault transcript was empty.');
    }

    onStage?.call(PipelineStage.saving);
    final entryId = JournalSyncIds.newOfflineEntryId();
    final raw = RawModelResponse(
      payload: {'reflection': reflectionJson},
      receivedAt: DateTime.now().toUtc(),
    );
    final revision = UserContentSafety.privacyHash(trimmed);
    final admission = _proofAdmission.admit(
      raw: raw,
      sourceEntries: [
        ProofSourceEntry(
          entryId: entryId,
          archiveScope: _archiveScope,
          ownerScope: _ownerScope,
          transcript: trimmed,
          transcriptRevision: revision,
          createdAt: raw.receivedAt,
          sourceType: ProofSourceType.userVoiceTranscript,
          remoteProcessingConsented: remoteProcessingConsented,
        ),
      ],
      activeArchiveScope: _archiveScope,
      activeOwnerScope: _ownerScope,
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
    await _journalStore.save(entry, first25Source: 'live_voice_vault_recovery');
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
    required String syncNote,
    void Function(PipelineStage stage)? onStage,
  }) async {
    onStage?.call(PipelineStage.saving);
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
    await _journalStore.save(entry, first25Source: 'live_voice_capture');
    _attest.clearToken();
    onStage?.call(PipelineStage.done);
    return CapturePipelineResult(
      entry: entry,
      localSaved: true,
      syncSucceeded: false,
      syncNote: syncNote,
    );
  }

  Future<VerifiedProof> _postAndAdmit({
    required String transcript,
    required String captureToken,
    required String idempotencyKey,
    required String entryId,
    required ProofSourceType sourceType,
  }) async {
    final revision = UserContentSafety.privacyHash(transcript);
    final analyzeResult = await _captureRepository.postAnalyzeRaw(
      transcript: transcript,
      captureToken: captureToken,
      idempotencyKey: idempotencyKey,
    );
    final raw = analyzeResult.when(
      success: (value) => value,
      onFailure: (failure) => throw failure.toApiException(),
    );
    // Every caller already checked `_remoteProcessingConsented()` live
    // before it was willing to make the `postAnalyzeRaw` call above — that is
    // the actual capture-time gate. This is checked again, here, at the
    // moment the resulting `ProofSourceEntry` is stamped, so a withdrawal
    // that happens to land in the network round trip above is reflected in
    // what gets stamped rather than trusting a now-stale answer: a
    // withdrawal mid-flight fails this admission (`evidence_verifier.dart`
    // rejects an unconsented source) rather than quietly stamping it as
    // consented after the fact.
    final consentedNow = await _remoteProcessingConsented();
    final startedAt = DateTime.now();
    final subject = ProofSourceEntry(
      entryId: entryId,
      archiveScope: _archiveScope,
      ownerScope: _ownerScope,
      transcript: transcript,
      transcriptRevision: revision,
      createdAt: raw.receivedAt,
      sourceType: sourceType,
      remoteProcessingConsented: consentedNow,
    );
    final result = _proofAdmission.admit(
      raw: raw,
      sourceEntries: [subject, ...await _relatedSources(subject)],
      activeArchiveScope: _archiveScope,
      activeOwnerScope: _ownerScope,
      primarySourceEntryId: entryId,
    );
    final admitted = result is ProofAdmitted ? result.proof : null;
    unawaited(
      ProductAnalytics.track(
        ProofAdmissionAnalytics.eventName,
        parameters: ProofAdmissionAnalytics.payload(
          result: result,
          distinctSourceCount:
              admitted?.qualityReceipt.frequency.distinctMoments ?? 0,
          contradictionCount:
              admitted?.qualityReceipt.contradictions.length ?? 0,
          duration: DateTime.now().difference(startedAt),
        ),
      ),
    );
    if (admitted != null) return admitted;
    final rejected = result as ProofNotAdmitted;
    throw FormatException(
      'Analysis was not admitted (${rejected.outcome.name}:${rejected.reason}).',
    );
  }

  /// The earlier moments offered alongside [subject] for this admission.
  ///
  /// Without these the pipeline only ever sees the entry just saved, so every
  /// claim needing two distinct sources — a repeat, a change — fails its source
  /// minimum and the archive can produce nothing but single-moment
  /// observations. Supplying candidates does not make a claim provable: the
  /// verifier still has to find its exact quotes inside them.
  ///
  /// Failure here is deliberately silent. Related sources widen what *may* be
  /// proved; losing them costs a possible repeat, never the saved original, so
  /// a read failure must not take the admission down with it.
  Future<List<ProofSourceEntry>> _relatedSources(
    ProofSourceEntry subject,
  ) async {
    try {
      final archive = await _journalStore.loadAll();
      final resolver = RelatedSourceResolver(
        archiveScope: _archiveScope,
        ownerScope: _ownerScope,
      )..sync(archive);
      // The entry being saved is usually not in the journal yet, so it has to
      // be indexed explicitly or it would have no terms to match against.
      resolver.index.upsertEntry(subject);
      return resolver.index
          .relatedSources(subject.entryId)
          .map((id) => archive.where((entry) => entry.id == id).firstOrNull)
          .whereType<JournalEntry>()
          .map(resolver.sourceFor)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  int _estimatedDurationSeconds(String transcript) {
    final chars = transcript.trim().length;
    return (chars / 15).ceil().clamp(1, 120);
  }

  Future<CapturePipelineResult> _saveTextLocalOnly({
    required String transcript,
    required String syncNote,
    void Function(PipelineStage stage)? onStage,
  }) async {
    onStage?.call(PipelineStage.saving);
    try {
      final entry = await _saveOfflineTextDraft(transcript);
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
      );
    }
  }

  Future<JournalEntry> _saveOfflineTextDraft(String transcript) async {
    final trimmed = transcript.trim();
    final entry = JournalEntry(
      id: JournalSyncIds.newOfflineEntryId(),
      createdAt: DateTime.now().toUtc(),
      transcript: trimmed,
      durationSeconds: _estimatedDurationSeconds(trimmed),
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
    await _journalStore.save(entry, first25Source: 'offline_text_capture');
    return entry;
  }

  Future<JournalEntry> _saveOfflineDraft({
    required File audioFile,
    required int durationSeconds,
    String? partialTranscript,
  }) async {
    const draftPlaceholder =
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
      id: JournalSyncIds.newOfflineEntryId(),
      createdAt: DateTime.now().toUtc(),
      transcript: draftPlaceholder,
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
      transcriptStatus: partialTranscript != null && partialTranscript.trim().isNotEmpty
          ? TranscriptStatus.finalTranscript
          : TranscriptStatus.pending,
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

  static String _audioScopeKey(String path, int durationSeconds) =>
      'audio:$path:$durationSeconds';

  static String _textScopeKey(String transcript) =>
      'text:${UserContentSafety.privacyHash(transcript)}';

  /// Ingests audio forwarded from the Apple Watch companion inbox.
  Future<CapturePipelineResult> runWatchCapture({
    required String audioFilePath,
    int? durationSeconds,
  }) {
    return run(
      audioFile: File(audioFilePath),
      durationSeconds: durationSeconds ?? 1,
    );
  }
}