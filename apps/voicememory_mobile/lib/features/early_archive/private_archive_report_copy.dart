import '../private_report/private_report_copy.dart';

/// Copy for the private archive report — evidence summary, not coaching.
abstract final class PrivateArchiveReportCopy {
  PrivateArchiveReportCopy._();

  static const title = PrivateReportCopy.title;

  static const intro = PrivateReportCopy.subtitle;

  static const whatRepeatedHeading = PrivateReportCopy.whatRepeatedHeading;

  static const whatChangedHeading = PrivateReportCopy.whatChangedHeading;

  static const whatHelpedHeading = PrivateReportCopy.whatHelpedHeading;

  static const whatToWatchNextHeading =
      PrivateReportCopy.whatToWatchNextHeading;

  static const evidenceHeading = PrivateReportCopy.evidenceHeading;

  static const missingEvidenceFallback = PrivateReportCopy.notEnoughEvidence;

  static const previewTitle = PrivateReportCopy.previewTitle;

  static const previewBody = PrivateReportCopy.previewBody;

  static const exportIncludedHeading = PrivateReportCopy.includedHeading;

  static List<String> get exportIncludedItems =>
      PrivateReportCopy.includedItems;

  static const exportNotIncludedHeading = PrivateReportCopy.notIncludedHeading;

  static const exportNotIncludedItems = PrivateReportCopy.notIncludedItems;

  static const previewProCta = PrivateReportCopy.previewProCta;

  static const copyReportCta = PrivateReportCopy.copyReportCta;

  static const closeCta = PrivateReportCopy.closeCta;

  static const viewReportCta = PrivateReportCopy.viewReportCta;

  static const copyConfirmation = PrivateReportCopy.copySuccess;

  static String whatRepeatedBody(String phrase, int count) =>
      PrivateReportCopy.whatRepeatedBody(phrase, count);
}
