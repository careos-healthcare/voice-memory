/// Copy for the private archive report — evidence summary, not coaching.
abstract final class PrivateArchiveReportCopy {
  PrivateArchiveReportCopy._();

  static const title = 'Private archive report';

  static const intro =
      'Your archive noticed these evidence patterns from your own words.';

  static const whatRepeatedHeading = 'What repeated';

  static const whatSoftenedHeading = 'What softened';

  static const whatGotLouderHeading = 'What got louder';

  static const whatHelpedHeading = 'What helped';

  static const whatChangedHeading = 'What changed';

  static const whatToRecordNextHeading = 'What to record next';

  static const missingEvidenceFallback = 'Not enough evidence yet.';

  static const whatToRecordNextBody =
      'Record when this comes back again. ArchiveMe will compare it with this report.';

  static const previewTitle = 'Your private archive report is forming';

  static const previewBody =
      'Free shows your first repeat. Pro keeps the full report: what repeated, '
      'what softened, what got louder, what helped, and what changed.';

  static const previewProCta = 'See Pro';

  static const copyReportCta = 'Copy report';

  static const sharePrivatelyCta = 'Share privately';

  static const privateFooter =
      'Private copy — not for public sharing.';

  static const madeWith = 'Made with ArchiveMe';

  static const copyConfirmation = 'Report copied';

  static const shareFallbackMessage =
      'Could not open share sheet. Report copied instead.';

  static String whatRepeatedBody(String phrase, int count) =>
      '"$phrase" showed up across $count moments.';

  static String whatSoftenedBody(String phrase) =>
      'This looked softer than before: "$phrase".';

  static String whatGotLouderBody(String phrase) =>
      'This looked stronger than before: "$phrase".';

  static String whatHelpedBody(String phrase) =>
      'A helpful action appeared: "$phrase".';

  static String whatChangedBody(String phrase) =>
      'Something looked different this time: "$phrase".';
}
