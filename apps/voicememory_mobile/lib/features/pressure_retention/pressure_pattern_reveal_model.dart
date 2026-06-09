import 'pressure_evidence_confidence.dart';

/// A hedged, evidence-based read of the user's recurring pressure pattern.
///
/// Never claims certainty: copy uses "starting to see", "often", "so far".
class PressurePatternReveal {
  const PressurePatternReveal({
    required this.hasPattern,
    required this.headline,
    required this.confidence,
    this.dominantOptionId,
    this.dominantOptionLabel,
    this.dominantPhrase,
    this.repeatedContextId,
    this.repeatedContextLabel,
    this.repeatedFearTheme,
    this.strongestTrigger,
    this.likelyCost,
    this.suggestedExperiment = PressurePatternReveal.experimentCopy,
    this.costs = const [],
  });

  /// Minimum pressure entries before a pattern can be shown.
  static const minEntries = 3;

  static const insufficientCopy =
      'Your archive needs a few more pressure moments before it can show a '
      'pattern confidently.';

  static const experimentCopy =
      'Next time this pressure shows up, stop 5 minutes earlier than usual and '
      'log what changed.';

  /// True when there is enough evidence (3+ entries) to surface a pattern.
  final bool hasPattern;

  /// The hedged, dynamic reveal sentence.
  final String headline;

  final PressureEvidenceConfidence confidence;

  final String? dominantOptionId;
  final String? dominantOptionLabel;
  final String? dominantPhrase;

  final String? repeatedContextId;
  final String? repeatedContextLabel;

  /// A worry the user named more than once (verbatim — never invented).
  final String? repeatedFearTheme;

  /// Pro detail: the strongest repeated trigger phrase.
  final String? strongestTrigger;

  /// Pro detail: the single most likely cost of this loop.
  final String? likelyCost;

  /// Pro detail: a concrete small experiment to try.
  final String suggestedExperiment;

  /// "What this may be costing you" examples, shown to everyone.
  final List<String> costs;

  factory PressurePatternReveal.insufficient() => const PressurePatternReveal(
        hasPattern: false,
        headline: insufficientCopy,
        confidence: PressureEvidenceConfidence.needsMoreEvidence,
      );
}
