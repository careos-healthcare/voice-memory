import 'package:archiveme_mobile/features/belief_evidence/evidence/transcript_evidence_index.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Feeds saved entries into [TranscriptEvidenceIndex].
///
/// Kept apart from the index so the verifier and the citation widgets do not
/// take a dependency on [JournalEntry] and everything behind it.
abstract final class JournalTranscriptEvidenceIndexer {
  JournalTranscriptEvidenceIndexer._();

  static void rememberEntry(JournalEntry entry) {
    TranscriptEvidenceIndex.rememberStoredText(
      entryId: entry.id,
      transcript: entry.transcript,
      recordedAt: entry.createdAt,
    );
  }

  static void rememberAll(Iterable<JournalEntry> entries) =>
      entries.forEach(rememberEntry);
}
