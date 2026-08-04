import '../private_report/private_report_copy.dart';

/// Copy for the Privacy & Trust Centre — factual, no unsupported claims.
abstract final class PrivacyTrustCopy {
  PrivacyTrustCopy._();

  static const title = 'Privacy & your archive';

  static const whatStoresHeading = 'What ArchiveMe stores';
  static const whatStoresBody =
      'Your saved moments, archive signals, coarse local paywall and '
      'suggestion events, and aggregate activation and retention counters.';

  static const whatNotIncludedHeading = 'What is not included';
  static const whatNotIncludedBody =
      'Behavioral logs contain coarse event categories, timestamps for '
      'paywall and suggestion events, and aggregate counters—not journal text '
      'or audio content.';

  static const whatStaysPrivateHeading = 'What stays private';
  static const whatStaysPrivateBody =
      'Your entries are used to build your archive on this device. Behavioral '
      'logs are shared only when you choose to export them and can be cleared.';

  static const yourControlsHeading = 'Your controls';

  static const correctTranscriptControl = 'Correct transcript';
  static const deleteArchiveControl = 'Delete archive';
  static const copyPrivateReportControl = 'Copy private report';
  static const exportBehavioralLogsControl = 'Export behavioral logs';
  static const exportBehavioralLogsDescription =
      'Optional JSON with coarse paywall and suggestion events plus aggregate '
      'activation and retention counts. Journal and audio content are not '
      'included.';
  static const clearBehavioralLogsControl = 'Clear behavioral logs';
  static const clearBehavioralLogsDescription =
      'Remove local interaction logs and aggregate behavioral counters without '
      'changing your journal.';
  static const sendBetaFeedbackControl = 'Send beta feedback';

  static const clearBehavioralLogsTitle = 'Clear behavioral logs?';
  static const clearBehavioralLogsBody =
      'This removes coarse interaction events and aggregate activation and '
      'retention counters stored on this device. Your journal entries and '
      'audio are unaffected.';
  static const clearBehavioralLogsConfirm = 'Clear logs';
  static const behavioralLogsExported = 'Behavioral logs ready to share.';
  static const behavioralLogsEmpty = 'There are no behavioral logs to export.';
  static const behavioralLogsExportFailed =
      'Behavioral logs could not be exported. Try again.';
  static const behavioralLogsCleared = 'Behavioral logs cleared.';
  static const behavioralLogsClearFailed =
      'Behavioral logs could not be cleared. Try again.';

  static const betaMeasurementHeading = 'Beta measurement';
  static const betaMeasurementBody =
      'Beta progress summary uses local counts only, not your words.';

  static const betaProgressSummaryControl = 'Beta progress summary';

  static const notEnoughReportEvidence = PrivateReportCopy.insufficientEvidence;

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
    exportBehavioralLogsControl,
    exportBehavioralLogsDescription,
    clearBehavioralLogsControl,
    clearBehavioralLogsDescription,
    sendBetaFeedbackControl,
    betaMeasurementHeading,
    betaMeasurementBody,
    betaProgressSummaryControl,
    notEnoughReportEvidence,
    deleteArchiveDone,
    clearBehavioralLogsTitle,
    clearBehavioralLogsBody,
    clearBehavioralLogsConfirm,
    behavioralLogsExported,
    behavioralLogsEmpty,
    behavioralLogsExportFailed,
    behavioralLogsCleared,
    behavioralLogsClearFailed,
  ];
}
