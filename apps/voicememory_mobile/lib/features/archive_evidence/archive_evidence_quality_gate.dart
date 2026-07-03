import '../../models/journal_entry.dart';
import 'archive_evidence_analytics.dart';
import 'archive_evidence_quality.dart';
import 'comparable_evidence_text.dart';

/// Shared gate — insight surfaces consult this before rendering evidence.
abstract final class ArchiveEvidenceQualityGate {
  ArchiveEvidenceQualityGate._();

  static const minProofEntryCount = 3;

  /// Entries with usable or strong evidence, oldest first.
  static List<JournalEntry> usableEntries(
    List<JournalEntry> entries, {
    String analyticsSource = 'archive_evidence_quality_gate',
  }) {
    final usable = entries
        .where((e) => ArchiveEvidenceQuality.assess(e).allowsInsights)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final skipped = entries.length - usable.length;
    if (skipped > 0 &&
        ComparableEvidenceText.countPendingTranscriptEntries(entries) > 0) {
      ArchiveEvidenceAnalytics.evidenceSkippedPlaceholder(
        source: analyticsSource,
        entryCount: ComparableEvidenceText.countPendingTranscriptEntries(entries),
      );
    }

    return usable;
  }

  /// Entries with strong evidence for proof/belief/timeline surfaces.
  static List<JournalEntry> strongEntries(List<JournalEntry> entries) {
    return entries
        .where((e) => ArchiveEvidenceQuality.assess(e).allowsProofSurfaces)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  static int usableCount(List<JournalEntry> entries) =>
      usableEntries(entries).length;

  static int strongCount(List<JournalEntry> entries) =>
      strongEntries(entries).length;

  static bool allowsEarlySignals(List<JournalEntry> entries) =>
      usableCount(entries) >= 1;

  static bool allowsEarlyComparisons(List<JournalEntry> entries) =>
      usableCount(entries) >= 2;

  static bool allowsFirstProof(List<JournalEntry> entries) =>
      strongCount(entries) >= minProofEntryCount;

  static bool allowsBeliefSurfaces(List<JournalEntry> entries) =>
      strongCount(entries) >= minProofEntryCount;

  static bool allowsProofTimeline(List<JournalEntry> entries) =>
      allowsBeliefSurfaces(entries);

  static bool allowsPrivateReport(List<JournalEntry> entries) =>
      strongCount(entries) >= minProofEntryCount;

  static bool allowsAdaptiveDailyQuestion(List<JournalEntry> entries) =>
      usableCount(entries) >= 1;

  /// True when saved entries exist but none are usable for insights.
  static bool showsInsightFallbackOnly(List<JournalEntry> entries) {
    if (entries.isEmpty) return false;
    return usableCount(entries) == 0;
  }

  /// True when every saved entry is pending transcript / placeholder.
  static bool showsPendingTranscriptFallback(List<JournalEntry> entries) {
    if (entries.isEmpty) return false;
    return entries.every(
      (e) =>
          ArchiveEvidenceQuality.assess(e).reason ==
          ArchiveEvidenceQualityReason.placeholderOrPending ||
          ArchiveEvidenceQuality.assess(e).reason ==
              ArchiveEvidenceQualityReason.degradedVoice,
    );
  }

  /// True when entries are saved but only weak generic/short text exists.
  static bool showsWeakEvidenceFallback(List<JournalEntry> entries) {
    if (entries.isEmpty) return false;
    if (usableCount(entries) > 0) return false;
    return entries.any(
      (e) =>
          ArchiveEvidenceQuality.assess(e).level ==
          ArchiveEvidenceQualityLevel.weak,
    );
  }
}
