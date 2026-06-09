import 'dart:io';

import 'package:uuid/uuid.dart';

import '../api/api_exceptions.dart';
import '../models/journal_entry.dart';
import '../models/reflection.dart';
import '../models/sync_status.dart';
import '../storage/journal_store.dart';
import 'capture_attest_service.dart';
import 'capture_save_messages.dart';
import '../api/api_client.dart';

class CapturePipelineFailure implements Exception {
  CapturePipelineFailure(this.message, {this.savedDraft = false, this.entry});

  final String message;
  final bool savedDraft;
  final JournalEntry? entry;

  @override
  String toString() => message;
}

enum PipelineStage {
  attesting,
  transcribing,
  analyzing,
  saving,
  done,
}

class CapturePipelineResult {
  const CapturePipelineResult({
    required this.entry,
    required this.localSaved,
    required this.syncSucceeded,
    this.syncNote,
  });

  final JournalEntry entry;
  final bool localSaved;
  final bool syncSucceeded;
  final String? syncNote;
}

class CapturePipelineService {
  CapturePipelineService({
    required ApiClient api,
    required CaptureAttestService attest,
    required JournalStore journalStore,
  })  : _api = api,
        _attest = attest,
        _journalStore = journalStore;

  final ApiClient _api;
  final CaptureAttestService _attest;
  final JournalStore _journalStore;
  final _uuid = const Uuid();

  Future<CapturePipelineResult> run({
    required File audioFile,
    required int durationSeconds,
    void Function(PipelineStage stage)? onStage,
  }) async {
    String? partialTranscript;
    try {
      onStage?.call(PipelineStage.attesting);
      var token = await _attest.ensureCaptureToken();

      onStage?.call(PipelineStage.transcribing);
      try {
        partialTranscript = await _api.postTranscribe(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          captureToken: token,
        );
      } on AuthRequiredException {
        token = await _attest.ensureCaptureToken(forceRefresh: true);
        partialTranscript = await _api.postTranscribe(
          audioFile: audioFile,
          durationSeconds: durationSeconds,
          captureToken: token,
        );
      }

      onStage?.call(PipelineStage.analyzing);
      Reflection reflection;
      try {
        reflection = await _api.postAnalyze(
          transcript: partialTranscript,
          captureToken: token,
        );
      } on AuthRequiredException {
        token = await _attest.ensureCaptureToken(forceRefresh: true);
        reflection = await _api.postAnalyze(
          transcript: partialTranscript,
          captureToken: token,
        );
      }

      onStage?.call(PipelineStage.saving);
      final entry = JournalEntry(
        id: _uuid.v4(),
        createdAt: DateTime.now().toUtc(),
        transcript: partialTranscript,
        durationSeconds: durationSeconds,
        reflection: reflection,
        syncStatus: SyncStatus.pendingUpload,
        localAudioPath: audioFile.path,
      );
      await _journalStore.save(entry, first25Source: 'voice_capture');
      _attest.clearToken();

      onStage?.call(PipelineStage.done);
      return CapturePipelineResult(
        entry: entry,
        localSaved: true,
        syncSucceeded: true,
      );
    } on SocketException catch (e) {
      return _saveLocalOnly(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        partialTranscript: partialTranscript,
        syncNote: CaptureSaveMessages.syncNoteFor(e),
        onStage: onStage,
      );
    } on ApiException catch (e) {
      return _saveLocalOnly(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        partialTranscript: partialTranscript,
        syncNote: CaptureSaveMessages.syncNoteFor(e),
        onStage: onStage,
      );
    } catch (e) {
      return _saveLocalOnly(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        partialTranscript: partialTranscript,
        syncNote: CaptureSaveMessages.syncNoteFor(e),
        onStage: onStage,
      );
    }
  }

  Future<CapturePipelineResult> _saveLocalOnly({
    required File audioFile,
    required int durationSeconds,
    String? partialTranscript,
    required String syncNote,
    void Function(PipelineStage stage)? onStage,
  }) async {
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
        syncNote: syncNote,
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

    try {
      onStage?.call(PipelineStage.attesting);
      var token = await _attest.ensureCaptureToken();

      onStage?.call(PipelineStage.analyzing);
      Reflection reflection;
      try {
        reflection = await _api.postAnalyze(
          transcript: trimmed,
          captureToken: token,
        );
      } on AuthRequiredException {
        token = await _attest.ensureCaptureToken(forceRefresh: true);
        reflection = await _api.postAnalyze(
          transcript: trimmed,
          captureToken: token,
        );
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
    final entry = JournalEntry(
      id: _uuid.v4(),
      createdAt: DateTime.now().toUtc(),
      transcript: partialTranscript?.trim().isNotEmpty == true
          ? partialTranscript!.trim()
          : '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
      durationSeconds: durationSeconds,
      reflection: Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: const [],
        exactLanguagePattern: '',
        concreteObservation: CaptureSaveMessages.savedPrivatelyOnDevice,
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.pendingUpload,
      localAudioPath: audioFile.path,
    );
    await _journalStore.save(entry, first25Source: 'offline_voice_capture');
    return entry;
  }
}
