import 'dart:io';

import 'package:uuid/uuid.dart';

import '../api/api_exceptions.dart';
import '../models/journal_entry.dart';
import '../models/reflection.dart';
import '../models/sync_status.dart';
import '../storage/journal_store.dart';
import 'capture_attest_service.dart';
import '../api/api_client.dart';

enum PipelineStage {
  attesting,
  transcribing,
  analyzing,
  saving,
  done,
}

class CapturePipelineResult {
  const CapturePipelineResult({required this.entry});

  final JournalEntry entry;
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
    onStage?.call(PipelineStage.attesting);
    var token = await _attest.ensureCaptureToken();

    onStage?.call(PipelineStage.transcribing);
    String transcript;
    try {
      transcript = await _api.postTranscribe(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        captureToken: token,
      );
    } on AuthRequiredException {
      token = await _attest.ensureCaptureToken(forceRefresh: true);
      transcript = await _api.postTranscribe(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        captureToken: token,
      );
    }

    onStage?.call(PipelineStage.analyzing);
    Reflection reflection;
    try {
      reflection = await _api.postAnalyze(
        transcript: transcript,
        captureToken: token,
      );
    } on AuthRequiredException {
      token = await _attest.ensureCaptureToken(forceRefresh: true);
      reflection = await _api.postAnalyze(
        transcript: transcript,
        captureToken: token,
      );
    }

    onStage?.call(PipelineStage.saving);
    final entry = JournalEntry(
      id: _uuid.v4(),
      createdAt: DateTime.now().toUtc(),
      transcript: transcript,
      durationSeconds: durationSeconds,
      reflection: reflection,
      syncStatus: SyncStatus.localOnly,
      localAudioPath: audioFile.path,
    );
    await _journalStore.save(entry);
    _attest.clearToken();

    onStage?.call(PipelineStage.done);
    return CapturePipelineResult(entry: entry);
  }
}
