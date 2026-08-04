import 'weekly_review.dart';

/// Why a week produced no review.
enum WeeklyReviewShortfall {
  tooFewSavedMoments,
  tooFewDays,
  tooFewItems,
  generationNotPermitted,
}

/// What a candidate week actually contains, measured before anything is said.
class WeeklyReviewEvidence {
  const WeeklyReviewEvidence({
    required this.distinctSavedMoments,
    required this.distinctDays,
    required this.itemCount,
  });

  const WeeklyReviewEvidence.none()
    : distinctSavedMoments = 0,
      distinctDays = 0,
      itemCount = 0;

  /// Distinct saved moments cited by the candidate items.
  final int distinctSavedMoments;

  /// Distinct calendar days those moments were captured on.
  final int distinctDays;

  /// Candidate items, at most one per [WeeklyReviewItemKind].
  final int itemCount;
}

/// The single explicit bar a week must clear before ArchiveMe says anything.
///
/// A weekly review is an interruption, so the bar is stated as numbers rather
/// than a feeling, and it is checked in exactly one place:
/// [WeeklyReviewSufficiency.shortfall], which
/// `WeeklyReviewEngine.build` consults before it constructs a review.
///
/// The bar is deliberately *not* an entry-count milestone. Saving a fiftieth
/// moment is not evidence of anything; three moments across two days that
/// produced two separate findings is.
abstract final class WeeklyReviewSufficiency {
  WeeklyReviewSufficiency._();

  /// The review window: the seven days ending at the moment it is generated.
  static const window = Duration(days: 7);

  /// Fewer than three cited moments cannot separate a pattern from a coincidence.
  static const minimumDistinctSavedMoments = 3;

  /// One day of moments is one mood, not a week.
  static const minimumDistinctDays = 2;

  /// One finding is a thread update; it does not need a weekly summary.
  static const minimumItems = 2;

  /// Null when the week qualifies; otherwise the first unmet condition.
  static WeeklyReviewShortfall? shortfall(WeeklyReviewEvidence evidence) {
    if (evidence.distinctSavedMoments < minimumDistinctSavedMoments) {
      return WeeklyReviewShortfall.tooFewSavedMoments;
    }
    if (evidence.distinctDays < minimumDistinctDays) {
      return WeeklyReviewShortfall.tooFewDays;
    }
    if (evidence.itemCount < minimumItems) {
      return WeeklyReviewShortfall.tooFewItems;
    }
    return null;
  }

  static bool isSufficient(WeeklyReviewEvidence evidence) =>
      shortfall(evidence) == null;
}

/// The outcome of asking for this week's review.
class WeeklyReviewOutcome {
  const WeeklyReviewOutcome.generated(WeeklyReview this.review)
    : shortfall = null,
      evidence = const WeeklyReviewEvidence.none();

  const WeeklyReviewOutcome.withheld({
    required WeeklyReviewShortfall this.shortfall,
    required this.evidence,
  }) : review = null;

  final WeeklyReview? review;
  final WeeklyReviewShortfall? shortfall;
  final WeeklyReviewEvidence evidence;

  bool get hasReview => review != null;
}
