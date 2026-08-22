import 'dart:io';

import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/models/transcript_provenance.dart';
import 'package:archiveme_mobile/models/transcript_status.dart';
import 'package:archiveme_mobile/security/account_session_guard.dart';
import 'package:archiveme_mobile/security/private_data_service.dart';
import 'package:archiveme_mobile/security/user_content_safety.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_dependencies.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/services/record_pipeline_log.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';

/// Persists voice entries and shared offline draft helpers.
class CaptureVoicePersistence {
  CaptureVoicePersistence(this._deps);

  final CapturePipelineDependencies _deps;

  JournalStore get _journalStore => _deps.journalStore;

  Future<JournalEntry> saveVoiceEntryAndLog(
    JournalEntry entry, {
    required String first25Source,
    String captureKind = 'voice',
    AccountSessionGuard? session,
  }) async {
    session?.assertActive();
    await _journalStore.save(
      entry,
      first25Source: first25Source,
      captureKind: captureKind,
    );
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

  Future<JournalEntry> saveOfflineDraft({
    required File audioFile,
    required int durationSeconds,
    String? partialTranscript,
    Reflection? reflection,
  }) async {
    const draftPlaceholder =
        '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';
    final finalTranscript = resolveFinalCaptureTranscript(
      transcript: partialTranscript,
    );
    RecordPipelineLog.preSaveFinalTranscript(
      length: finalTranscript?.length ?? 0,
    );

    final template = JournalEntry(
      id: JournalSyncIds.newOfflineEntryId(),
      createdAt: DateTime.now().toUtc(),
      transcript: draftPlaceholder,
      durationSeconds: durationSeconds,
      reflection:
          reflection ??
          const Reflection(
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
      provenance: TranscriptProvenance.speechToText,
      draftPlaceholder: draftPlaceholder,
    );
    return saveVoiceEntryAndLog(
      prepared,
      first25Source: 'offline_voice_capture',
    );
  }

  static bool hasUsableTranscript(String? transcript) =>
      transcript != null && transcript.trim().isNotEmpty;

  static int estimatedDurationSeconds(String transcript) {
    final chars = transcript.trim().length;
    return (chars / 15).ceil().clamp(1, 120);
  }

  static String audioScopeKey(String path, int durationSeconds) =>
      'audio:$path:$durationSeconds';

  static String textScopeKey(String transcript) =>
      'text:${UserContentSafety.privacyHash(transcript)}';
}
