import 'package:archiveme_mobile/features/pressure_retention/pressure_evidence_confidence.dart';

/// A periodic, evidence-only review of the user's pressure loop, unlocked
/// once there are 5+ logged pressure moments.
///
/// Hedged by design: copy uses "keeps repeating", "may be", "so far" and
/// never claims certainty. Sections are only populated from real local
/// evidence — a trigger, context, or change is never invented.
class PressurePatternReview {
  const PressurePatternReview({
    required this.hasReview,
    required this.entryCount,
    required this.confidence,
    this.repeatingSummary,
    this.strongestTrigger,
    this.likelyCost,
    this.changeSummary,
    this.experimentSuggestion = experimentCopy,
  });

  factory PressurePatternReview.insufficient(int entryCount) =>
      PressurePatternReview(
        hasReview: false,
        entryCount: entryCount,
        confidence: PressureEvidenceConfidence.needsMoreEvidence,
      );

  /// Minimum pressure entries before the review unlocks.
  static const minEntries = 5;

  static const title = 'Your first pressure review is ready';

  static const insufficientCopy =
      'Your archive needs a few more pressure moments before it can build '
      'your first review.';

  static const repeatingSectionTitle = 'What keeps repeating';
  static const costSectionTitle = 'What this may be costing you';
  static const changeSectionTitle = 'What changed';
  static const experimentSectionTitle = 'Try this next week';

  /// Honest fallback when no change is supported by the evidence yet.
  static const noChangeCopy =
      'No clear change since your first entry yet, so far. Keep logging — '
      'your review will track it.';

  static const experimentCopy =
      'Next time this pressure shows up, stop 5 minutes earlier than usual '
      'and log what changed.';

  /// True once there are [minEntries]+ entries to review.
  final bool hasReview;

  final int entryCount;

  final PressureEvidenceConfidence confidence;

  /// "What keeps repeating" — hedged summary of the dominant pattern.
  final String? repeatingSummary;

  /// Strongest repeated trigger/context, only when actually repeated.
  final String? strongestTrigger;

  /// The single most likely cost of the dominant pattern.
  final String? likelyCost;

  /// What changed since the first entry — null unless supported by evidence.
  final String? changeSummary;

  /// One suggested experiment for next week.
  final String experimentSuggestion;
}