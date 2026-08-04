import 'dart:io';

import '../../../transcription_queue/transcription_job.dart';
import '../../../transcription_queue/transcription_ledger.dart';
import 'recording_ui_state_mapper.dart';

final class VaultPersistenceCoordinator {
  const VaultPersistenceCoordinator(this._ledger);

  final TranscriptionLedger _ledger;

  Future<TranscriptionJob> persistForTranscription({
    required File protectedAudio,
    required int durationSeconds,
    String? entryId,
  }) async {
    try {
      return await _ledger.enqueue(
        protectedAudio,
        durationSeconds: durationSeconds,
        entryId: entryId,
      );
    } on Object catch (error) {
      throw RecordingPersistenceFailure(error);
    }
  }
}
