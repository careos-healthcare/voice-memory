/// The kind of useful takeaway a closed loop produced.
enum UsefulResultTakeawayType {
  repeat,
  lighter,
  heavier,
  changed,
  concrete,
  unclear,
}

/// A one-glance, useful reading of a closed-loop result.
///
/// Shown before the usefulness rating so the result already feels useful: a
/// clear takeaway, why it matters, and one next check to carry into tomorrow.
class UsefulResultTakeaway {
  const UsefulResultTakeaway({
    required this.type,
    required this.headline,
    required this.whatItMeans,
    required this.whyUseful,
    required this.nextCheck,
    required this.example,
    this.confidenceLabel,
  });

  final UsefulResultTakeawayType type;

  /// One-line takeaway, e.g. "This was a repeat, not a one-off."
  final String headline;

  /// What the result means in plain language.
  final String whatItMeans;

  /// Why the result is useful (may be sharpened by a not-useful reason).
  final String whyUseful;

  /// One concrete thing to check next.
  final String nextCheck;

  /// A short example of what a useful next moment sounds like.
  final String example;

  /// Optional small label, e.g. "Early read" when the reflection was thin.
  final String? confidenceLabel;
}
