enum ProPreviewSurface { recordPostSave, archivePatterns, testing }

extension ProPreviewSurfaceAnalytics on ProPreviewSurface {
  String get analyticsValue => switch (this) {
    ProPreviewSurface.recordPostSave => 'record_post_save',
    ProPreviewSurface.archivePatterns => 'archive_patterns',
    ProPreviewSurface.testing => 'testing',
  };
}

enum ProPreviewRowId {
  fullPatternTimeline,
  whatReturned,
  whatChanged,
  whatYouCorrected,
  currentVsFading,
  monthlyPrivateReport,
  backupContinuity,
}

class ProPreviewRow {
  const ProPreviewRow({required this.id, required this.label});

  final ProPreviewRowId id;
  final String label;
}

class ProPreviewContext {
  const ProPreviewContext({
    required this.surface,
    required this.source,
    required this.entryCount,
    required this.isPro,
    required this.dismissed,
    required this.hasFirstProof,
    required this.hasTimelineProofVisible,
    required this.firstProofPayoffSeen,
    this.isZeroEntryState = false,
    this.isFirstRecordingState = false,
    this.isDegradedTranscriptState = false,
    this.isPostSaveDegradedState = false,
    this.firstProofTruthQuestionActive = false,
    this.whatChangedQuestionActive = false,
    this.patternReviewInboxHasActiveItems = false,
  });

  final ProPreviewSurface surface;
  final String source;
  final int entryCount;
  final bool isPro;
  final bool dismissed;
  final bool hasFirstProof;
  final bool hasTimelineProofVisible;
  final bool firstProofPayoffSeen;
  final bool isZeroEntryState;
  final bool isFirstRecordingState;
  final bool isDegradedTranscriptState;
  final bool isPostSaveDegradedState;
  final bool firstProofTruthQuestionActive;
  final bool whatChangedQuestionActive;
  final bool patternReviewInboxHasActiveItems;
}

class ProPreviewResult {
  const ProPreviewResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.previewRows,
    required this.cta,
    required this.secondary,
    required this.source,
    required this.surface,
    required this.entryCount,
    required this.hasTimelineProof,
    required this.hasFirstProof,
  });

  final bool shouldShow;
  final String title;
  final String body;
  final List<ProPreviewRow> previewRows;
  final String cta;
  final String secondary;
  final String source;
  final ProPreviewSurface surface;
  final int entryCount;
  final bool hasTimelineProof;
  final bool hasFirstProof;
}
