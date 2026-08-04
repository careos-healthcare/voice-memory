import '../paywall_alignment/paywall_alignment_copy.dart';

/// Display-only copy for the monthly private report preview — no billing logic.
abstract final class MonthlyPrivateReportCopy {
  MonthlyPrivateReportCopy._();

  static const cardTitle = 'Your private monthly report is forming';

  static const cardBody =
      'ArchiveMe is collecting evidence of what returned, changed, softened, helped, or went quiet.';

  static const proReason = PaywallAlignmentCopy.monthlyReportProReason;

  static const chatDifferentiation =
      'This is not a chat transcript. It is a private evidence report built from moments you saved.';

  static const cta = 'Preview monthly report';

  static const secondary = 'Not now';

  static const sheetTitle = 'Private monthly report';

  static const sheetIntro =
      'Based on saved moments so far. This early report may grow as you keep recording.';

  static const whatKeptReturningHeading = 'What kept returning';
  static const whatChangedHeading = 'What changed';
  static const whatHelpedHeading = 'What helped';
  static const whatWentQuietHeading = 'What went quiet';
  static const evidenceHeading = 'Evidence from your own words';

  static const formingPrefix = 'Early signal:';
  static const basedOnSavedMoments = 'Based on saved moments you kept.';

  static const proValueLine =
      'Pro turns your archive into a private evidence report over time.';

  static const sheetSeeProCta = 'See what Pro keeps';

  static List<String> allVisibleStrings() => [
    cardTitle,
    cardBody,
    proReason,
    chatDifferentiation,
    cta,
    secondary,
    sheetTitle,
    sheetIntro,
    whatKeptReturningHeading,
    whatChangedHeading,
    whatHelpedHeading,
    whatWentQuietHeading,
    evidenceHeading,
    formingPrefix,
    basedOnSavedMoments,
    proValueLine,
    sheetSeeProCta,
  ];
}
