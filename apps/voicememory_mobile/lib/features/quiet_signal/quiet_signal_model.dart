/// Quiet / not-seen-recently moment when a watched thread has not returned.
class QuietSignal {
  const QuietSignal({
    required this.title,
    required this.body,
    required this.footer,
    required this.ctaKeepWatching,
    required this.source,
    required this.daysSinceSet,
    required this.daysSinceSeen,
    required this.unrelatedSaveCount,
    this.lastSeenDateKey,
    this.patternDetailHeading,
    this.patternDetailBody,
    this.weeklyReviewHeading,
    this.weeklyReviewBody,
    this.privateReportLine,
  });

  final String title;
  final String body;
  final String footer;
  final String ctaKeepWatching;
  final String source;
  final int daysSinceSet;
  final int daysSinceSeen;
  final int unrelatedSaveCount;
  final String? lastSeenDateKey;
  final String? patternDetailHeading;
  final String? patternDetailBody;
  final String? weeklyReviewHeading;
  final String? weeklyReviewBody;
  final String? privateReportLine;
}
