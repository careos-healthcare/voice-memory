import '../activation/weekly_archive_review.dart';

/// Calm, cautious copy for Then vs Now cards.
abstract final class ThenNowCopy {
  ThenNowCopy._();

  static const route = '/then-vs-now';
  static const recordRoute = '/record';
  static const archiveHomeRoute = '/archive-belief';

  static const eyebrow = 'Then vs now';
  static const thenLabel = 'Then';
  static const nowLabel = 'Now';

  static const reviewChangeCta = 'Review change';
  static const saveAnotherMomentCta = 'Save another moment';
  static const saveMomentCta = 'Save a moment';
  static const reviewWeeklyArchiveCta = 'Review weekly archive';
  static const viewThenVsNowCta = 'Open Then vs now';

  static const helperText =
      'Based on saved moments. Open entries to review the evidence.';
  static const cautionLabel = 'Based on saved moments from your local archive.';

  static const earlyHeadline =
      'ArchiveMe is starting to compare earlier and newer moments.';
  static const earlyThenSummary =
      'Earlier saved moments are beginning to form a baseline.';
  static const earlyNowSummary =
      'This is early. Add more moments to make the comparison clearer.';
  static const earlyWhatThisMeans =
      'ArchiveMe has enough saved moments to start grouping earlier and '
      'newer signals. The comparison will get clearer with more evidence.';

  static const comparisonHeadline =
      'A repeated theme may be shifting across your archive.';
  static const thenMoreOften = 'This theme showed up more often.';
  static const nowShifting = 'Newer moments suggest it may be shifting.';
  static const thenAppeared = 'This theme appeared in earlier moments.';
  static const nowStillAppears = 'It still appears in newer moments.';
  static const thenLessOften = 'This theme appeared less often.';
  static const nowAppearingMore =
      'Newer moments suggest it may be appearing more.';
  static const comparisonWhatThisMeans =
      'ArchiveMe grouped earlier and newer saved moments around a repeated '
      'theme. Open entries to review the evidence yourself.';

  static const enoughEvidenceLine =
      'ArchiveMe has enough evidence to compare earlier and newer moments.';

  static const insufficientTitle = 'Then vs Now needs more saved moments.';
  static const insufficientBody =
      'Save a few more useful moments so ArchiveMe can compare what showed up '
      'earlier with what appears now.';
  static const noClearChangeTitle = 'No clear change yet';
  static const noClearChangeBody =
      'ArchiveMe did not find a repeated theme strong enough to compare. '
      'Saving another moment around the same watch theme may help.';

  static const supportSectionTitle = 'Then vs now';
  static const supportSectionBody =
      'See cautious earlier-vs-newer comparisons from your local archive. '
      'No private entry text is shown or uploaded.';

  static const betaOutcomesLabel = 'Then vs now card available';
  static const betaOutcomesYes = 'Yes';
  static const betaOutcomesNo = 'No';

  static const screenshotHeadline = 'Then vs now (sample)';
  static const screenshotThenSummary =
      'Example theme signal in earlier moments.';
  static const screenshotNowSummary = 'Example only — no private data.';

  static String evidenceCountLabel({
    required int earlierCount,
    required int newerCount,
    required int total,
  }) => '$earlierCount earlier · $newerCount newer · $total saved moments';

  static String themeEvidenceLabel(String theme) =>
      'Repeated theme: ${_formatTheme(theme)}';

  static String weeklyReviewRoute({required bool weeklyReviewAvailable}) =>
      weeklyReviewAvailable
      ? WeeklyArchiveReviewNavigation.route
      : archiveHomeRoute;

  static String _formatTheme(String theme) {
    final trimmed = theme.trim();
    if (trimmed.isEmpty) return 'Archive theme';
    if (trimmed.length == 1) return trimmed.toUpperCase();
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  static String formatThemeForDisplay(String theme) => _formatTheme(theme);

  static List<String> get allVisibleStrings => [
    eyebrow,
    thenLabel,
    nowLabel,
    reviewChangeCta,
    saveAnotherMomentCta,
    saveMomentCta,
    reviewWeeklyArchiveCta,
    viewThenVsNowCta,
    helperText,
    cautionLabel,
    earlyHeadline,
    earlyThenSummary,
    earlyNowSummary,
    earlyWhatThisMeans,
    comparisonHeadline,
    thenMoreOften,
    nowShifting,
    thenAppeared,
    nowStillAppears,
    thenLessOften,
    nowAppearingMore,
    comparisonWhatThisMeans,
    enoughEvidenceLine,
    insufficientTitle,
    insufficientBody,
    noClearChangeTitle,
    noClearChangeBody,
    supportSectionTitle,
    supportSectionBody,
    betaOutcomesLabel,
    betaOutcomesYes,
    betaOutcomesNo,
    screenshotHeadline,
    screenshotThenSummary,
    screenshotNowSummary,
    evidenceCountLabel(earlierCount: 2, newerCount: 3, total: 5),
    themeEvidenceLabel('work'),
  ];
}
