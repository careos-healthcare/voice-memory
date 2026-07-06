/// User-facing copy for quiet / not-seen-recently moments.
abstract final class QuietSignalCopy {
  QuietSignalCopy._();

  static const title = 'This has not shown up recently';

  static const body =
      'ArchiveMe was watching this thread, but your recent moments did not show it.';

  static const footer = 'That may matter too.';

  static const ctaKeepWatching = 'Keep watching';

  static const ctaViewPatternDetails = 'View pattern details';

  static const patternDetailHeading = 'Last seen';

  static const patternDetailBody =
      'ArchiveMe last saw this thread earlier. Your recent saved moments have not shown it clearly.';

  static const weeklyReviewHeading = 'Quiet signal';

  static const weeklyReviewBody =
      'This pattern was being watched, but it has not appeared in your recent saved moments.';

  static const privateReportLine =
      'This pattern has not shown up recently.';

  static List<String> allVisibleStrings() => [
        title,
        body,
        footer,
        ctaKeepWatching,
        ctaViewPatternDetails,
        patternDetailHeading,
        patternDetailBody,
        weeklyReviewHeading,
        weeklyReviewBody,
        privateReportLine,
      ];
}
