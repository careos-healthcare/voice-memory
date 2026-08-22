import 'package:archiveme_mobile/features/private_report/private_report_copy.dart';
import 'package:archiveme_mobile/security/privacy_claim_catalogue.dart';

/// Copy for the Privacy & Trust Centre — factual, no unsupported claims.
abstract final class PrivacyTrustCopy {
  PrivacyTrustCopy._();

  static const title = 'Privacy & your archive';

  // `whatStoresHeading`/`Body` ("What ArchiveMe stores" — "Your saved moments
  // and local archive signals.") and `whatStaysPrivateHeading`/`Body` ("What
  // stays private" — "Your entries are used to build your archive on this
  // device.") were retired when `/privacy` migrated into this screen. Neither
  // was wrong; both were a shorter version of a claim
  // `PrivacyScreenCopy.onDeviceBody` and `privateByDefaultBody` now make in
  // full on the same scroll, and the one thing this screen cannot afford is a
  // claim stated twice, because a correction then lands on one of them.

  static const whatNotIncludedHeading = 'What is not included';
  static const whatNotIncludedBody =
      'ArchiveMe does not include raw audio in private reports.';

  static const yourControlsHeading = 'Your controls';

  static const correctTranscriptControl = 'Correct transcript';
  static const deleteArchiveControl = 'Delete archive';
  static const copyPrivateReportControl = 'Copy private report';
  static const sendBetaFeedbackControl = 'Send beta feedback';

  static const betaMeasurementHeading = 'Beta measurement';
  static const betaMeasurementBody =
      'Beta progress summary uses local counts only, not your words.';

  static const betaProgressSummaryControl = 'Beta progress summary';

  static const String notEnoughReportEvidence = PrivateReportCopy.insufficientEvidence;

  static const deleteArchiveDone = PrivacyClaimCatalogue.localArchiveCleared;

  static List<String> allVisibleStrings() => [
    title,
    whatNotIncludedHeading,
    whatNotIncludedBody,
    yourControlsHeading,
    correctTranscriptControl,
    deleteArchiveControl,
    copyPrivateReportControl,
    sendBetaFeedbackControl,
    betaMeasurementHeading,
    betaMeasurementBody,
    betaProgressSummaryControl,
    notEnoughReportEvidence,
    deleteArchiveDone,
  ];
}