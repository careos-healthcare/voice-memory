import 'dart:io';

import 'package:archiveme_mobile/features/capture_flow/interfaces/capture_flow_ports.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';

/// Local-first persistence via the existing capture pipeline.
class PipelineLocalMomentRepository implements LocalMomentRepository {
  PipelineLocalMomentRepository({
    required CapturePipelineService pipeline,
    required JournalStore journalStore,
  }) : _pipeline = pipeline,
       _journalStore = journalStore;

  final CapturePipelineService _pipeline;
  final JournalStore _journalStore;

  @override
  Stream<PipelineState> get pipelineStates => _pipeline.pipelineStates;

  @override
  Future<CapturePipelineOutcome> saveVoiceCapture({
    required File audioFile,
    required int durationSeconds,
  }) => _pipeline.run(
    audioFile: audioFile,
    durationSeconds: durationSeconds,
  );

  @override
  Future<CapturePipelineOutcome> saveTypedCapture({
    required String transcript,
  }) => _pipeline.saveTextThought(transcript: transcript);

  @override
  Future<CapturePipelineOutcome> retryRemoteForEntry({
    required JournalEntry entry,
  }) async {
    final audioPath = entry.localAudioPath?.trim();
    if (audioPath == null || audioPath.isEmpty) {
      return pipelineFailure(
        CapturePipelineFailure('No audio available for retry.'),
      );
    }
    final audioFile = File(audioPath);
    return _pipeline.run(
      audioFile: audioFile,
      durationSeconds: entry.durationSeconds,
    );
  }

  @override
  Future<CapturePipelineOutcome> attachTypedToVoiceEntry({
    required JournalEntry entry,
    required String transcript,
  }) => _pipeline.attachTypedTextToVoiceEntry(
    entry: entry,
    transcript: transcript,
  );

  @override
  Future<JournalEntry?> loadEntry(String entryId) =>
      _journalStore.getById(entryId);

  @override
  Future<int> entryCount() async {
    final entries = await _journalStore.loadAll();
    return entries.length;
  }
}

/// Purpose-specific consent — fails closed on read errors.
class StoreRemoteConsentPolicy implements RemoteConsentPolicy {
  StoreRemoteConsentPolicy(this._store);

  final RemoteProcessingConsentStore _store;

  @override
  Future<bool> isGranted(RemoteProcessingPurpose purpose) async {
    try {
      return await _store.isPurposeGrantedNow(purpose);
    } catch (_) {
      return false;
    }
  }
}

class PipelineRemoteTranscriptionGateway implements RemoteTranscriptionGateway {
  PipelineRemoteTranscriptionGateway(this._consent);

  final RemoteConsentPolicy _consent;

  @override
  Future<bool> transcriptionAllowed() =>
      _consent.isGranted(RemoteProcessingPurpose.remoteTranscription);
}

class PipelineRemoteReflectionGateway implements RemoteReflectionGateway {
  PipelineRemoteReflectionGateway(this._consent);

  final RemoteConsentPolicy _consent;

  @override
  Future<bool> reflectionAllowed() =>
      _consent.isGranted(RemoteProcessingPurpose.remoteReflection);
}
