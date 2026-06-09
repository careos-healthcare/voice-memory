import '../../config/app_config.dart';
import '../../models/journal_entry.dart';

/// Production safeguard — insights only surface when real reflections meet thresholds.
abstract final class ArchiveEvidenceGuard {
  ArchiveEvidenceGuard._();

  /// Minimum eligible reflections (usable transcript length) before beliefs,
  /// discoveries, contradictions, chapters, and weekly stories may render.
  static int get minimumEvidenceCount =>
      AppConfig.patternReviewReflectionTarget;

  /// Matches [archiveMinTranscriptChars] — transcripts shorter than this are not evidence.
  static const int minimumTranscriptChars = 24;

  static List<JournalEntry> eligibleEntries(List<JournalEntry> entries) {
    return entries
        .where((e) => e.transcript.trim().length >= minimumTranscriptChars)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  static int eligibleReflectionCount(List<JournalEntry> entries) =>
      eligibleEntries(entries).length;

  static bool hasMinimumEvidence(List<JournalEntry> entries) =>
      eligibleReflectionCount(entries) >= minimumEvidenceCount;

  static bool canSurfaceBelief(List<JournalEntry> entries) =>
      hasMinimumEvidence(entries);

  static bool canSurfaceDiscovery(List<JournalEntry> entries) =>
      hasMinimumEvidence(entries);

  static bool canSurfaceContradictions(List<JournalEntry> entries) =>
      hasMinimumEvidence(entries);

  static bool canSurfaceChapters(List<JournalEntry> entries) =>
      hasMinimumEvidence(entries);

  static bool canSurfaceWeeklyStory(List<JournalEntry> entries) =>
      hasMinimumEvidence(entries);
}
