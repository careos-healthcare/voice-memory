enum ArchiveBackupBridgeSurface {
  settings('settings'),
  archivePatterns('archive_patterns');

  const ArchiveBackupBridgeSurface(this.analyticsValue);
  final String analyticsValue;
}

class ArchiveBackupBridgeContext {
  const ArchiveBackupBridgeContext({
    required this.surface,
    required this.entryCount,
    required this.isPro,
    required this.dismissed,
    required this.hasConfirmedRepeat,
    required this.hasReportPreview,
    required this.hasSeenProof,
    required this.isZeroEntryState,
    required this.isFirstRecordingState,
    required this.isDegradedTranscriptState,
    required this.isPostSaveDegradedState,
    required this.firstProofTruthQuestionActive,
    required this.whatChangedQuestionActive,
    required this.patternReviewInboxHasActiveItems,
  });

  final ArchiveBackupBridgeSurface surface;
  final int entryCount;
  final bool isPro;
  final bool dismissed;
  final bool hasConfirmedRepeat;
  final bool hasReportPreview;
  final bool hasSeenProof;
  final bool isZeroEntryState;
  final bool isFirstRecordingState;
  final bool isDegradedTranscriptState;
  final bool isPostSaveDegradedState;
  final bool firstProofTruthQuestionActive;
  final bool whatChangedQuestionActive;
  final bool patternReviewInboxHasActiveItems;

  bool get hasArchiveValue =>
      hasConfirmedRepeat ||
      hasReportPreview ||
      (entryCount >= 2 && hasSeenProof);
}

class ArchiveBackupBridgeDisplay {
  const ArchiveBackupBridgeDisplay({
    required this.title,
    required this.body,
    required this.plannedProAreas,
    required this.deviceBackupToday,
    required this.proPreservation,
    required this.cta,
    required this.secondary,
    required this.sheetTitle,
    required this.sheetIntro,
    required this.sheetLocalBackupLine,
    required this.sheetSeeProCta,
  });

  final String title;
  final String body;
  final String plannedProAreas;
  final String deviceBackupToday;
  final String proPreservation;
  final String cta;
  final String secondary;
  final String sheetTitle;
  final String sheetIntro;
  final String sheetLocalBackupLine;
  final String sheetSeeProCta;
}