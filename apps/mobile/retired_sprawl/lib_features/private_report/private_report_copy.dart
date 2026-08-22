/// User-facing copy for the shareable private archive report.
abstract final class PrivateReportCopy {
  PrivateReportCopy._();

  static const title = 'My ArchiveMe report';

  static const subtitle =
      'A private summary from your saved moments on this device.';

  static const whatRepeatedHeading = 'What repeated';
  static const whatChangedHeading = 'What changed';
  static const whatHelpedHeading = 'What seemed to help';
  static const whatToWatchNextHeading = 'What to watch next';
  static const evidenceHeading = 'Evidence from saved moments';

  static const sectionFallback = 'Not enough evidence yet';

  static const insufficientEvidence =
      'ArchiveMe needs more evidence before creating a private report.';

  static const footer =
      'This report is private. It is based on saved moments from this device. '
      'It is not advice or a diagnosis.';

  static const copyReportCta = 'Copy report';
  static const shareReportCta = 'Share report';
  static const closeCta = 'Close';
  static const copySuccess = 'Private report copied';

  static const openReportCta = 'View private report';

  static const previewTitle = 'Preview private report';
  static const previewBody =
      'Your first repeat shows a preview. Pro keeps every report section.';
  static const previewProCta = 'See Pro';
  static const viewReportCta = 'View report';

  // Legacy card/export aliases — kept for existing surfaces.
  static const String notEnoughEvidence = sectionFallback;
  static const includedHeading = 'Included';
  static const includedItems = [
    'Short pattern summaries',
    'Grounded phrases',
    'Dates or relative dates if already shown safely',
    'User-corrected transcript snippets only when used as evidence',
  ];
  static const notIncludedHeading = 'Not included';
  static const notIncludedItems = [
    'Audio files',
    'Hidden scores',
    'Internal labels',
    'Debug logs',
    'Billing information',
  ];

  static String whatRepeatedBody(String phrase, int count) =>
      '"$phrase" showed up across $count moments.';

  static String evidenceSnippet(String snippet, {String? relativeDate}) {
    if (relativeDate == null || relativeDate.trim().isEmpty) {
      return '"$snippet"';
    }
    return '$relativeDate — "$snippet"';
  }

  static List<String> allVisibleStrings() => [
    title,
    subtitle,
    whatRepeatedHeading,
    whatChangedHeading,
    whatHelpedHeading,
    whatToWatchNextHeading,
    evidenceHeading,
    sectionFallback,
    insufficientEvidence,
    footer,
    copyReportCta,
    shareReportCta,
    closeCta,
    copySuccess,
    openReportCta,
  ];
}