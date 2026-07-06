/// Display model for the Pro evidence value bridge card and sheet.
class ProEvidenceValueDisplay {
  const ProEvidenceValueDisplay({
    required this.title,
    required this.body,
    required this.cta,
    required this.secondary,
    required this.chatGptDifferentiationLine,
    required this.evidenceLine,
    required this.comparesMomentsLine,
    required this.sheetTitle,
    required this.freeSectionTitle,
    required this.freeBullets,
    required this.proSectionTitle,
    required this.proBullets,
    required this.sheetFooter,
    required this.exportReportsLive,
  });

  final String title;
  final String body;
  final String cta;
  final String secondary;
  final String chatGptDifferentiationLine;
  final String evidenceLine;
  final String comparesMomentsLine;
  final String sheetTitle;
  final String freeSectionTitle;
  final List<String> freeBullets;
  final String proSectionTitle;
  final List<String> proBullets;
  final String sheetFooter;
  final bool exportReportsLive;
}

/// Where the Pro evidence value bridge may appear.
enum ProEvidenceValueSurface {
  recordReady('record_ready'),
  recordPostSaveAfterPayoff('record_post_save_after_payoff'),
  privateReportPreview('private_report_preview'),
  archivePatterns('archive_patterns'),
  weeklyReviewPreview('weekly_review_preview');

  const ProEvidenceValueSurface(this.analyticsValue);

  final String analyticsValue;
}

/// Inputs for visibility — metadata only, no journal text.
class ProEvidenceValueContext {
  const ProEvidenceValueContext({
    required this.surface,
    required this.entryCount,
    required this.isPro,
    required this.dismissed,
    required this.firstProofPayoffSeen,
    required this.hasConfirmedRepeatEvidence,
    required this.privateReportPreviewVisible,
    required this.weeklyReviewPreviewVisible,
    required this.isZeroEntryState,
    required this.isFirstRecordingState,
    required this.isDegradedTranscriptState,
    required this.isPostSaveDegradedState,
    required this.firstProofTruthQuestionActive,
    required this.whatChangedQuestionActive,
    required this.patternReviewInboxHasActiveItems,
    required this.exportReportsLive,
  });

  final ProEvidenceValueSurface surface;
  final int entryCount;
  final bool isPro;
  final bool dismissed;
  final bool firstProofPayoffSeen;
  final bool hasConfirmedRepeatEvidence;
  final bool privateReportPreviewVisible;
  final bool weeklyReviewPreviewVisible;
  final bool isZeroEntryState;
  final bool isFirstRecordingState;
  final bool isDegradedTranscriptState;
  final bool isPostSaveDegradedState;
  final bool firstProofTruthQuestionActive;
  final bool whatChangedQuestionActive;
  final bool patternReviewInboxHasActiveItems;
  final bool exportReportsLive;
}
