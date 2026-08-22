import 'package:archiveme_mobile/features/capture_flow/interfaces/capture_flow_ports.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/features/transcript_correction/transcript_correction_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/transcript_provenance.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';

class TranscriptCorrectionFailure implements Exception {
  TranscriptCorrectionFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Applies transcript corrections through injected storage — no service locator.
class JournalTranscriptCorrectionAdapter implements TranscriptCorrectionPort {
  JournalTranscriptCorrectionAdapter(this._journalStore);

  final JournalStore _journalStore;

  @override
  Future<JournalEntry> apply({
    required JournalEntry entry,
    required String correctedText,
  }) async {
    final trimmed = correctedText.trim();
    if (trimmed.isEmpty) {
      throw TranscriptCorrectionFailure(TranscriptCorrectionCopy.saveFailed);
    }

    final existing = await _journalStore.getById(entry.id);
    if (existing == null) {
      throw TranscriptCorrectionFailure(TranscriptCorrectionCopy.saveFailed);
    }

    // User-authored correction, no AI rewrite — still the user's own words.
    final updated = applyFinalTranscriptToVoiceEntry(
      existing,
      finalTranscript: trimmed,
      provenance: TranscriptProvenance.userEdited,
    );
    await _journalStore.update(updated);
    return updated;
  }
}
