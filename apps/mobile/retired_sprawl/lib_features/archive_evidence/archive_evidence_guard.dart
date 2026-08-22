import 'package:archiveme_mobile/core/config/v1_feature_flags.dart';
import 'package:archiveme_mobile/features/evidence_contract/evidence_eligibility_policy.dart';
import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Production safeguard — insights only surface when real reflections meet thresholds.
abstract class ArchiveEvidenceGuard {
  ArchiveEvidenceGuard._();

  /// Minimum eligible reflections before beliefs,
  /// discoveries, contradictions, chapters, and weekly stories may render.
  static int get minimumEvidenceCount => V1FeatureFlags.enableV1Only
      ? EvidenceEligibilityPolicy.possiblePatternMinimum
      : AppConfig.patternReviewReflectionTarget;

  /// Matches [archiveMinTranscriptChars] — transcripts shorter than this are not evidence.
  static const int minimumTranscriptChars =
      ArchiveEvidenceQuality.minUsableChars;

  static bool hasUsableReflectionText(JournalEntry entry) =>
      ArchiveEvidenceQuality.assess(entry).allowsInsights;

  static bool hasStrongReflectionText(JournalEntry entry) =>
      ArchiveEvidenceQuality.assess(entry).allowsProofSurfaces;

  static List<JournalEntry> eligibleEntries(
    List<JournalEntry> entries, {
    String analyticsSource = 'archive_evidence_guard',
  }) => ArchiveEvidenceQualityGate.usableEntries(
    entries,
    analyticsSource: analyticsSource,
  );

  static List<JournalEntry> strongEntries(List<JournalEntry> entries) =>
      ArchiveEvidenceQualityGate.strongEntries(entries);

  static int eligibleReflectionCount(List<JournalEntry> entries) =>
      eligibleEntries(entries).length;

  static bool hasMinimumEvidence(List<JournalEntry> entries) =>
      eligibleReflectionCount(entries) >= minimumEvidenceCount;

  static bool canSurfaceBelief(List<JournalEntry> entries) =>
      ArchiveEvidenceQualityGate.allowsBeliefSurfaces(entries);

  static bool canSurfaceDiscovery(List<JournalEntry> entries) =>
      hasMinimumEvidence(entries);

  static bool canSurfaceContradictions(List<JournalEntry> entries) =>
      ArchiveEvidenceQualityGate.allowsBeliefSurfaces(entries);

  static bool canSurfaceChapters(List<JournalEntry> entries) =>
      ArchiveEvidenceQualityGate.allowsBeliefSurfaces(entries);

  static bool canSurfaceWeeklyStory(List<JournalEntry> entries) =>
      ArchiveEvidenceQualityGate.allowsBeliefSurfaces(entries);
}