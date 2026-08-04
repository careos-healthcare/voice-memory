/// A belief-like phrase that repeated in the user's own saved words, with
/// the exact evidence behind it and one gentle line that creates distance
/// from the belief. Noticing only — never a claim that the belief is true,
/// never a diagnosis.
class BeliefDistance {
  const BeliefDistance({
    required this.hasBelief,
    this.title = defaultTitle,
    this.beliefLine = '',
    this.frequencyLine = '',
    this.distanceLine = defaultDistanceLine,
    this.evidenceSnippets = const [],
    this.sourceTerms = const [],
    this.entryIds = const [],
    this.confidenceLabel = '',
  });

  /// A belief-like phrase needs at least this many related entries.
  static const int minRelatedEntries = 2;

  /// Caps keep the card compact and honest — top evidence only.
  static const int maxSnippets = 3;
  static const int maxTerms = 3;

  /// Longer notes read as stories, not belief-like phrases; quoting them
  /// back would feel heavy. Anything longer is skipped, never trimmed.
  static const int maxPhraseLength = 80;

  static const String defaultTitle = 'A belief that showed up';

  /// Title for exactly 2 related entries — cautious, no pattern claim yet.
  static const String cautiousTitle =
      'This may be a belief that is starting to repeat.';

  static const String defaultDistanceLine =
      'You do not need to treat it as fact today. '
      'Just notice that it returned.';

  static const String evidenceHeading = 'Evidence behind this';

  // Count-based confidence labels — hedged, never certain.
  static const String earlySignalConfidence = 'Early signal';
  static const String repeatedSignalConfidence = 'Repeated signal';
  static const String strongRepeatedSignalConfidence = 'Strong repeated signal';

  /// False when no belief-like phrase can be safely formed from the user's
  /// own repeated words.
  final bool hasBelief;

  final String title;

  /// The user's exact phrase in quotes, e.g.
  /// "\u201CI have to keep checking\u201D showed up again."
  final String beliefLine;

  /// Real count over the user's recent archive, e.g.
  /// "This appeared 3 times in your recent archive."
  final String frequencyLine;

  /// The gentle distancing line — notice it, never treat it as fact.
  final String distanceLine;

  /// The user's exact saved words behind the belief (capped at
  /// [maxSnippets]). Never fabricated.
  final List<String> evidenceSnippets;

  /// Repeated words behind the phrase (capped at [maxTerms]).
  final List<String> sourceTerms;

  /// Journal entry ids behind the belief — the exact recordings.
  final List<String> entryIds;

  final String confidenceLabel;

  factory BeliefDistance.none() => const BeliefDistance(hasBelief: false);
}
