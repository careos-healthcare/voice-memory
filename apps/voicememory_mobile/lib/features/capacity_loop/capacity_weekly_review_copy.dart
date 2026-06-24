/// Copy for capacity weekly review — cautious evidence language only.
abstract final class CapacityWeeklyReviewCopy {
  CapacityWeeklyReviewCopy._();

  static const route = '/capacity-weekly-review';
  static const recordRoute = '/record';
  static const archiveHomeRoute = '/archive-belief';
  static const capacityLoopRoute = '/capacity-loop';

  static const title = 'Your yes pattern this week';
  static const subtitle =
      'A private weekly review of what repeated, what changed, and what to watch next.';

  static const sectionWhatRepeated = 'What repeated';
  static const sectionWhatChanged = 'What changed';
  static const sectionLaterCost = 'Later cost';
  static const sectionWhatPulledYouIn = 'What pulled you in';
  static const sectionWatchNext = 'Watch next';

  static const reviewThisWeekCta = 'Review this week';
  static const saveNextYesMomentCta = 'Save next yes moment';

  static const cardEyebrow = 'Weekly capacity review';

  static String evidenceCountLabel(int count) =>
      'Built from $count saved moment${count == 1 ? '' : 's'}';

  static String outcomesMarkedLine(int count) =>
      'You marked $count outcome${count == 1 ? '' : 's'} after pausing.';

  static String laterCostRecordedLine(int count) =>
      'Later cost recorded on $count moment${count == 1 ? '' : 's'}.';

  static const whatRepeatedForming =
      'Your archive is starting to show moments where agreeing may have come before checking capacity.';
  static const whatRepeatedStrong =
      'This may be forming: agreeing, helping, or taking something on before checking capacity.';

  static const patternMayHaveChanged =
      'Some moments show the pattern may have changed.';
  static const patternMostlyRepeating =
      'This week mostly shows the pattern repeating.';
  static const patternForming =
      'A few more moments will make this clearer.';

  static const watchNextBody =
      'Before agreeing, save the moment when you feel the pull to say yes.';

  static const laterCostForming =
      'Later cost is still forming across saved moments.';

  static List<String> allVisibleStrings() => [
        title,
        subtitle,
        sectionWhatRepeated,
        sectionWhatChanged,
        sectionLaterCost,
        sectionWhatPulledYouIn,
        sectionWatchNext,
        reviewThisWeekCta,
        saveNextYesMomentCta,
        cardEyebrow,
        whatRepeatedForming,
        whatRepeatedStrong,
        patternMayHaveChanged,
        patternMostlyRepeating,
        patternForming,
        watchNextBody,
        laterCostForming,
      ];
}
