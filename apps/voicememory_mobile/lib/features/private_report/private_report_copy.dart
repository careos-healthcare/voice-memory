/// User-facing copy for the private archive report export surface.
abstract final class PrivateReportCopy {
  PrivateReportCopy._();

  static const title = 'Private archive report';

  static const subtitle =
      'A local summary you can copy. Your raw recordings are not included.';

  static const whatRepeatedHeading = 'What repeated';
  static const whatChangedHeading = 'What changed';
  static const whatHelpedHeading = 'What helped';
  static const whatToWatchNextHeading = 'What to watch next';
  static const evidenceHeading = 'Evidence from your words';

  static const notEnoughEvidence = 'Not enough evidence yet';

  static const copyReportCta = 'Copy report';
  static const closeCta = 'Close';
  static const copySuccess = 'Private report copied';

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

  static const previewTitle = 'Preview private report';
  static const previewBody =
      'Your first repeat shows a preview. Pro keeps every report section.';
  static const previewProCta = 'See Pro';
  static const viewReportCta = 'View report';

  static String whatRepeatedBody(String phrase, int count) =>
      '"$phrase" showed up across $count moments.';

  static String evidenceSnippet(String snippet, {String? relativeDate}) {
    if (relativeDate == null || relativeDate.trim().isEmpty) {
      return '"$snippet"';
    }
    return '$relativeDate — "$snippet"';
  }
}
