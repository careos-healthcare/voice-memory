import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_quality.dart';
import '../archive_evidence/comparable_evidence_text.dart';
import '../voice_capture/voice_capture_quality.dart';

/// Identifies saved moments that can be repaired with typed text.
abstract final class PendingTranscriptRecoveryGate {
  PendingTranscriptRecoveryGate._();

  static bool entryNeedsRecovery(JournalEntry entry) {
    if (VoiceCaptureQuality.isDegradedVoiceCapture(entry)) return true;
    if (ComparableEvidenceText.entryHasPendingTranscript(entry)) return true;

    final verdict = ArchiveEvidenceQuality.assess(entry);
    return verdict.level == ArchiveEvidenceQualityLevel.unusable &&
        (verdict.reason == ArchiveEvidenceQualityReason.degradedVoice ||
            verdict.reason ==
                ArchiveEvidenceQualityReason.placeholderOrPending);
  }

  static JournalEntry? newestRecoverableEntry(Iterable<JournalEntry> entries) {
    JournalEntry? newest;
    for (final entry in entries) {
      if (!entryNeedsRecovery(entry)) continue;
      if (newest == null || entry.createdAt.isAfter(newest.createdAt)) {
        newest = entry;
      }
    }
    return newest;
  }

  static bool hasRecoverableEntry(Iterable<JournalEntry> entries) =>
      newestRecoverableEntry(entries) != null;
}
