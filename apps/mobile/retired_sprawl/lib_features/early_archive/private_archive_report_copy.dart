import 'package:archiveme_mobile/features/private_report/private_report_copy.dart';

/// Copy for the private archive report — evidence summary, not coaching.
abstract final class PrivateArchiveReportCopy {
  PrivateArchiveReportCopy._();

  static const String title = PrivateReportCopy.title;

  static const String intro = PrivateReportCopy.subtitle;

  static const String whatRepeatedHeading = PrivateReportCopy.whatRepeatedHeading;

  static const String whatChangedHeading = PrivateReportCopy.whatChangedHeading;

  static const String whatHelpedHeading = PrivateReportCopy.whatHelpedHeading;

  static const String whatToWatchNextHeading =
      PrivateReportCopy.whatToWatchNextHeading;

  static const String evidenceHeading = PrivateReportCopy.evidenceHeading;

  static const String missingEvidenceFallback = PrivateReportCopy.notEnoughEvidence;

  static const String previewTitle = PrivateReportCopy.previewTitle;

  static const String previewBody = PrivateReportCopy.previewBody;

  static const String exportIncludedHeading = PrivateReportCopy.includedHeading;

  static List<String> get exportIncludedItems =>
      PrivateReportCopy.includedItems;

  static const String exportNotIncludedHeading = PrivateReportCopy.notIncludedHeading;

  static const List<String> exportNotIncludedItems = PrivateReportCopy.notIncludedItems;

  static const String previewProCta = PrivateReportCopy.previewProCta;

  static const String copyReportCta = PrivateReportCopy.copyReportCta;

  static const String closeCta = PrivateReportCopy.closeCta;

  static const String viewReportCta = PrivateReportCopy.viewReportCta;

  static const String copyConfirmation = PrivateReportCopy.copySuccess;

  static String whatRepeatedBody(String phrase, int count) =>
      PrivateReportCopy.whatRepeatedBody(phrase, count);
}