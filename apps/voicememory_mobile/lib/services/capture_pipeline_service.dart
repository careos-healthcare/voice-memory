import 'dart:io';

import 'package:uuid/uuid.dart';

import '../api/api_exceptions.dart';
import '../features/timeline/timeline_entry_display.dart';
import '../features/voice_capture/analysis/analysis_log.dart';
import '../features/voice_capture/transcription/transcription_log.dart';
import '../features/voice_capture/transcription/transcription_service.dart';
import '../features/voice_capture/voice_capture_copy.dart';
import '../features/voice_capture/voice_capture_quality.dart';
import '../models/journal_entry.dart';
import '../models/reflection.dart';
import '../models/sync_status.dart';
import '../security/api_usage_guard.dart';
import '../security/private_data_service.dart';
import '../security/user_content_safety.dart';
import '../storage/journal_store.dart';
import 'capture_attest_service.dart';
import 'capture_save_messages.dart';
import '../api/api_client.dart';
import 'record_pipeline_log.dart';

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
    required ApiClient api,
    required CaptureAttestService attest,
    required JournalStore journalStore,
    ApiUsageGuard? usageGuard,
  }) : _api = api,
       _attest = attest,
       _journalStore = journalStore,
       _usageGuard = usageGuard ?? ApiUsageGuard.shared;

  final ApiClient _api;
  final CaptureAttestService _attest;
  final JournalStore _journalStore;
  final ApiUsageGuard _usageGuard;
  final _uuid = const Uuid();

  Future<CapturePipelineResult> run({
    required File audioFile,
    required int durationSeconds,
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

    String? partialTranscript;
    final scopeKey = _audioScopeKey(audioFile.path, durationSeconds);
    try {
      onStage?.call(PipelineStage.attesting);
      var token = await _attest.ensureCaptureToken();

      onStage?.call(PipelineStage.transcribing);
      final transcription = await TranscriptionService.transcribeRecording(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        api: _api,
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
            partialTranscript: null,
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
          partialTranscript: null,
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
          partialTranscript: null,
          syncNote: CaptureSaveMessages.syncUnavailableOffline,
          transcriptionFailureReason: reason,
          onStage: onStage,
        );
      }

      onStage?.call(PipelineStage.analyzing);
      final analyzeCheck = _usageGuard.checkAttempt(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
      );
      if (!analyzeCheck.allowed) {
        final reason = analyzeCheck.reason ?? 'blocked';
        RecordPipelineLog.apiGuardBlocked(
          operation: 'analyze',
          reason: reason,
        );
        return _saveAfterAnalysisFailure(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          transcript: trimmedTranscript,
          reason: reason,
          onStage: onStage,
        );
      }

      Reflection reflection;
      final analyzeIdempotency = _usageGuard.idempotencyKey(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
      );
      try {
        reflection = await _api.postAnalyze(
          transcript: trimmedTranscript,
          captureToken: token,
          idempotencyKey: analyzeIdempotency,
        );
        _usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.analyze,
          success: true,
        );
      } on AuthRequiredException {
        token = await _attest.ensureCaptureToken(forceRefresh: true);
        reflection = await _api.postAnalyze(
          transcript: trimmedTranscript,
          captureToken: token,
          idempotencyKey: analyzeIdempotency,
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
      RecordPipelineLog.preSaveFinalTranscript(
        length: finalTranscript.length,
      );
      final template = JournalEntry(
        id: _uuid.v4(),
        createdAt: DateTime.now().toUtc(),
        transcript: trimmedTranscript,
        durationSeconds: durationSeconds,
        reflection: reflection,
        syncStatus: SyncStatus.pendingUpload,
        localAudioPath: audioFile.path,
      );
      final prepared = applyFinalTranscriptToVoiceEntry(
        template,
        finalTranscript: finalTranscript,
      );
      final entry = await _saveVoiceEntryAndLog(
        prepared,
        first25Source: 'voice_capture',
      );
      _attest.clearToken();

      onStage?.call(PipelineStage.done);
      return CapturePipelineResult(
        entry: entry,
        localSaved: true,
        syncSucceeded: true,
        analysisSucceeded: true,
      );
    } on SocketException catch (e) {
      return _handleVoiceCaptureFailure(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        partialTranscript: partialTranscript,
        error: e,
        onStage: onStage,
      );
    } on ApiException catch (e) {
      return _handleVoiceCaptureFailure(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        partialTranscript: partialTranscript,
        error: e,
        onStage: onStage,
      );
    } on FormatException catch (e) {
      return _handleVoiceCaptureFailure(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        partialTranscript: partialTranscript,
        error: e,
        onStage: onStage,
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

    final reason = TranscriptionService.failureReason(error);
    TranscriptionLog.failed(reason: reason);
    if (error is FormatException) {
      RecordPipelineLog.apiGuardBlocked(
        operation: 'response',
        reason: error.message,
      );
    }
    return _saveLocalOnly(
      audioFile: audioFile,
      durationSeconds: durationSeconds,
      partialTranscript: null,
      syncNote: error is FormatException
          ? VoiceCaptureCopy.transcriptionFailedDegraded
          : CaptureSaveMessages.syncNoteFor(error),
      transcriptionFailureReason: reason,
      onStage: onStage,
    );
  }

  Future<CapturePipelineResult> _saveAfterAnalysisFailure({
    required File audioFile,
    required int durationSeconds,
    required String transcript,
    Object? error,
    String? reason,
    void Function(PipelineStage stage)? onStage,
  }) async {
    final resolvedReason = reason ??
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
    return _saveLocalOnly(
      audioFile: audioFile,
      durationSeconds: durationSeconds,
      partialTranscript: transcript,
      syncNote: VoiceCaptureCopy.analysisUnavailableNote,
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

      Reflection reflection;
      final analyzeIdempotency = _usageGuard.idempotencyKey(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
      );
      try {
        reflection = await _api.postAnalyze(
          transcript: trimmed,
          captureToken: token,
          idempotencyKey: analyzeIdempotency,
        );
        _usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.analyze,
          success: true,
        );
      } on AuthRequiredException {
        token = await _attest.ensureCaptureToken(forceRefresh: true);
        reflection = await _api.postAnalyze(
          transcript: trimmed,
          captureToken: token,
          idempotencyKey: analyzeIdempotency,
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
      RecordPipelineLog.preSaveFinalTranscript(
        length: finalTranscript.length,
      );
      final template = JournalEntry(
        id: entry.id,
        createdAt: entry.createdAt,
        transcript: trimmed,
        durationSeconds: entry.durationSeconds,
        reflection: reflection,
        syncStatus: SyncStatus.pendingUpload,
        localAudioPath: entry.localAudioPath,
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
  }) async {
    await _journalStore.save(entry, first25Source: first25Source);
    await TempRecordingCleanup.purgeRetryRecordings();
    final reloaded = await _journalStore.getById(entry.id);
    final saved = reloaded ?? entry;
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
        resolution.text.isNotEmpty ||
        hasPersistedCaptureText(entry);
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
        analysisSucceeded: analysisFailureReason == null &&
            _hasUsableTranscript(partialTranscript),
        syncNote: syncNote,
        lowQualityTranscript: lowQualityTranscript,
      );
    } catch (e) {
      throw CapturePipelineFailure(
        'Could not save this recording on your device. Try again.',
        savedDraft: false,
      );
    }
  }

  /// Typed capture — same analyze + journal path as voice, without audio.
  Future<CapturePipelineResult> saveTextThought({
    required String transcript,
    void Function(PipelineStage stage)? onStage,
  }) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      throw CapturePipelineFailure('Enter a thought before saving.');
    }

    final scopeKey = _textScopeKey(trimmed);
    try {
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
          syncNote: analyzeCheck.reason ?? VoiceCaptureCopy.transcriptionFailedDegraded,
          onStage: onStage,
        );
      }

      Reflection reflection;
      final analyzeIdempotency = _usageGuard.idempotencyKey(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
      );
      try {
        reflection = await _api.postAnalyze(
          transcript: trimmed,
          captureToken: token,
          idempotencyKey: analyzeIdempotency,
        );
        _usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.analyze,
          success: true,
        );
      } on AuthRequiredException {
        token = await _attest.ensureCaptureToken(forceRefresh: true);
        reflection = await _api.postAnalyze(
          transcript: trimmed,
          captureToken: token,
          idempotencyKey: analyzeIdempotency,
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
        id: _uuid.v4(),
        createdAt: DateTime.now().toUtc(),
        transcript: trimmed,
        durationSeconds: _estimatedDurationSeconds(trimmed),
        reflection: reflection,
        syncStatus: SyncStatus.pendingUpload,
      );
      await _journalStore.save(entry, first25Source: 'text_capture');
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
        syncNote: CaptureSaveMessages.syncNoteFor(e),
        onStage: onStage,
      );
    } on ApiException catch (e) {
      return _saveTextLocalOnly(
        transcript: trimmed,
        syncNote: CaptureSaveMessages.syncNoteFor(e),
        onStage: onStage,
      );
    } on FormatException catch (e) {
      RecordPipelineLog.apiGuardBlocked(
        operation: 'response',
        reason: e.message,
      );
      return _saveTextLocalOnly(
        transcript: trimmed,
        syncNote: VoiceCaptureCopy.transcriptionFailedDegraded,
        onStage: onStage,
      );
    } catch (e) {
      return _saveTextLocalOnly(
        transcript: trimmed,
        syncNote: CaptureSaveMessages.syncNoteFor(e),
        onStage: onStage,
      );
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
        'Could not save this thought on your device. Try again.',
        savedDraft: false,
      );
    }
  }

  Future<JournalEntry> _saveOfflineTextDraft(String transcript) async {
    final trimmed = transcript.trim();
    final entry = JournalEntry(
      id: _uuid.v4(),
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
    );
    await _journalStore.save(entry, first25Source: 'offline_text_capture');
    return entry;
  }

  Future<JournalEntry> _saveOfflineDraft({
    required File audioFile,
    required int durationSeconds,
    String? partialTranscript,
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
      id: _uuid.v4(),
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
}
