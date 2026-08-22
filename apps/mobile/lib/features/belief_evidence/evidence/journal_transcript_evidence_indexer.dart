import 'package:archiveme_mobile/features/belief_evidence/evidence/legacy_transcript_registry.dart';
import 'package:archiveme_mobile/features/belief_evidence/evidence/transcript_evidence_index.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Feeds saved entries into [TranscriptEvidenceIndex].
///
/// Kept apart from the index so the verifier and the citation widgets do not
/// take a dependency on [JournalEntry] and everything behind it.
///
/// Reads `entry.transcript` and nothing else. Reflection fields are not
/// reachable from here, and an entry whose transcription failed yields no
/// source rather than a placeholder one.
///
/// Provenance is checked before the text is: an entry stored before
/// provenance was recorded may hold speech-to-text output or may hold model
/// output that the old capture path back-filled, and the two are
/// indistinguishable on disk. Such an entry registers no quotable source, so
/// nothing can present its text as the user's exact words. It does register
/// with [LegacyTranscriptRegistry], which is what lets the citation surfaces
/// say *why* there is no quote instead of falling through to the message for
/// claims the archive genuinely does not support.
abstract final class JournalTranscriptEvidenceIndexer {
  JournalTranscriptEvidenceIndexer._();

  static void rememberEntry(JournalEntry entry) {
    if (!entry.transcriptProvenance.isQuotable) {
      // Registered rather than dropped. Silence here is what made a legacy
      // entry indistinguishable from an entry nobody loaded, so both surfaced
      // as "Quote not loaded" — a transient-sounding message for a permanent
      // property of the row.
      LegacyTranscriptRegistry.remember(
        LegacyTranscriptRecord(
          entryId: entry.id,
          recordedAt: entry.createdAt,
          audioPath: entry.localAudioPath,
        ),
      );
      return;
    }
    final spoken = SpokenTranscript.fromCaptureText(
      entryId: entry.id,
      transcript: entry.transcript,
      recordedAt: entry.createdAt,
    );
    if (spoken == null) return;
    TranscriptEvidenceIndex.remember(spoken);
  }

  static void rememberAll(Iterable<JournalEntry> entries) =>
      entries.forEach(rememberEntry);
}
