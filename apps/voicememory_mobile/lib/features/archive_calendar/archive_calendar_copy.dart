/// Calm copy for Archive Calendar — counts only, no private entry text.
abstract final class ArchiveCalendarCopy {
  ArchiveCalendarCopy._();

  static const route = '/archive-calendar';
  static const recordRoute = '/record';
  static const archiveHomeRoute = '/archive-belief';

  static const eyebrow = 'Archive calendar';
  static const subtitle = 'Your saved moments by day';
  static const privacyLine =
      'This shows activity only — not private entry text.';
  static const helperText =
      'Open a day to review counts and safe markers.';
  static const weekCompareHelper =
      'Add one more moment to make this week easier to compare.';

  static const openCalendarCta = 'Open archive calendar';
  static const saveMomentCta = 'Save a moment';
  static const dayDetailArchiveHomeCta =
      'Open Archive Home to review entries privately';
  static const dayDetailRecordCta = 'Save a moment';

  static const emptyTitle =
      'Your calendar will appear after your first saved moment.';
  static const emptyBody =
      'ArchiveMe tracks saved-moment activity by day on this device. '
      'No private entry text is shown here.';

  static const cardHeadlineActive =
      'ArchiveMe is building a visible history by day.';
  static const cardSummaryActive =
      'See which days you saved moments and how this week compares.';

  static const markerOneMoment = 'Moment saved';
  static const markerMultipleMoments = 'Multiple moments saved';
  static const markerWeeklyReview = 'Weekly review window';
  static const markerWatchTheme = 'Watch theme evidence';
  static const markerThenVsNow = 'Then vs now evidence';

  static const supportSectionTitle = 'Archive calendar';
  static const supportSectionBody =
      'Browse saved-moment activity by day from your local archive. '
      'Counts and safe markers only — nothing is uploaded.';

  static const betaOutcomesLabel = 'Archive calendar available';
  static const betaOutcomesYes = 'Yes';
  static const betaOutcomesNo = 'No';

  static const helpSectionTitle = 'Archive calendar';
  static const helpSectionBullet =
      'Open Archive calendar to see saved-moment activity by day — counts only.';

  static const screenshotHeadline = 'Archive calendar (sample)';
  static const screenshotSummary =
      'Example activity counts only — no private data.';

  static String momentCountLabel(int count) =>
      count == 1 ? '1 moment saved' : '$count moments saved';

  static String weekSummaryLabel({required int count, required int dayCount}) {
    if (count <= 0) return 'No moments saved this week yet.';
    if (dayCount <= 1) {
      return 'This week: $count saved moment${count == 1 ? '' : 's'} on 1 day.';
    }
    return 'This week: $count saved moments across $dayCount days.';
  }

  static String monthlyTotalLabel({required int count, required String monthLabel}) {
    if (count <= 0) return 'No moments saved in $monthLabel yet.';
    return '$count saved moment${count == 1 ? '' : 's'} in $monthLabel.';
  }

  static String mostActiveDayLabel(String dayLabel, int count) =>
      'Most active day: $dayLabel ($count moment${count == 1 ? '' : 's'})';

  static String noMostActiveDayLabel() => 'Most active day: not enough data yet.';

  static String dayDetailTitle(String dayLabel) => dayLabel;

  static String dayDetailMomentLine(int count) => momentCountLabel(count);

  static List<String> get allVisibleStrings => [
        eyebrow,
        subtitle,
        privacyLine,
        helperText,
        weekCompareHelper,
        openCalendarCta,
        saveMomentCta,
        dayDetailArchiveHomeCta,
        dayDetailRecordCta,
        emptyTitle,
        emptyBody,
        cardHeadlineActive,
        cardSummaryActive,
        markerOneMoment,
        markerMultipleMoments,
        markerWeeklyReview,
        markerWatchTheme,
        markerThenVsNow,
        supportSectionTitle,
        supportSectionBody,
        betaOutcomesLabel,
        betaOutcomesYes,
        betaOutcomesNo,
        helpSectionTitle,
        helpSectionBullet,
        screenshotHeadline,
        screenshotSummary,
        momentCountLabel(1),
        momentCountLabel(3),
        weekSummaryLabel(count: 2, dayCount: 2),
        monthlyTotalLabel(count: 5, monthLabel: 'June 2026'),
        mostActiveDayLabel('15 June 2026', 2),
        noMostActiveDayLabel(),
        dayDetailTitle('15 June 2026'),
        dayDetailMomentLine(2),
      ];
}
