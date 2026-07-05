/// Copy for the Privacy & Trust Centre — factual, no unsupported claims.
abstract final class PrivacyTrustCopy {
  PrivacyTrustCopy._();

  static const title = 'Privacy & your archive';

  static const whatStoresHeading = 'What ArchiveMe stores';
  static const whatStoresBody =
      'Your saved moments and local archive signals.';

  static const whatNotIncludedHeading = 'What is not included';
  static const whatNotIncludedBody =
      'ArchiveMe does not include raw audio in private reports.';

  static const whatStaysPrivateHeading = 'What stays private';
  static const whatStaysPrivateBody =
      'Your entries are used to build your archive on this device.';

  static const yourControlsHeading = 'Your controls';

  static const correctTranscriptControl = 'Correct transcript';
  static const deleteArchiveControl = 'Delete archive';
  static const copyPrivateReportControl = 'Copy private report';
  static const sendBetaFeedbackControl = 'Send beta feedback';

  static const betaMeasurementHeading = 'Beta measurement';
  static const betaMeasurementBody =
      'Beta progress summary uses local counts only, not your words.';

  static const betaProgressSummaryControl = 'Beta progress summary';

  static const notEnoughReportEvidence =
      'Not enough evidence yet for a private report.';

  static const deleteArchiveDone = 'Local archive cleared.';

  static List<String> allVisibleStrings() => [
        title,
        whatStoresHeading,
        whatStoresBody,
        whatNotIncludedHeading,
        whatNotIncludedBody,
        whatStaysPrivateHeading,
        whatStaysPrivateBody,
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
