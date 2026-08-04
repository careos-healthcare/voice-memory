import '../../../../models/journal_entry.dart';
import '../../../../storage/journal_store.dart';

final class TranscriptEditingService {
  const TranscriptEditingService(this._journal);

  final JournalStore _journal;

  Future<JournalEntry> replace({
    required JournalEntry entry,
    required String transcript,
  }) async {
    final normalized = transcript.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(transcript, 'transcript', 'Cannot be empty.');
    }
    final updated = entry.copyWith(transcript: normalized);
    await _journal.save(updated, first25Source: 'record_transcript_edit');
    return (await _journal.getById(updated.id)) ?? updated;
  }
}
