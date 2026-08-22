import 'package:archiveme_mobile/features/archive_evidence/comparable_evidence_text.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/features/trust/pending_transcript_recovery_gate.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// When a saved moment may be corrected vs repaired with Add words.
abstract final class TranscriptCorrectionGate {
  TranscriptCorrectionGate._();

  static bool entryAllowsCorrection(JournalEntry entry) {
    if (PendingTranscriptRecoveryGate.entryNeedsRecovery(entry)) {
      return false;
    }

    final transcript = entrySanitizedTranscript(entry);
    if (transcript.isEmpty) return false;
    if (isDraftOrSystemTranscriptPlaceholder(transcript)) return false;

    return ComparableEvidenceText.userText(entry).isNotEmpty;
  }
}