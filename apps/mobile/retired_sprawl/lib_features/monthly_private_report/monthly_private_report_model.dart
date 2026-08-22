enum MonthlyPrivateReportSectionType {
  whatKeptReturning,
  whatChanged,
  whatHelped,
  whatWentQuiet,
  evidence,
}

class MonthlyPrivateReportSection {
  const MonthlyPrivateReportSection({
    required this.type,
    required this.heading,
    this.lines = const [],
    this.bullets = const [],
  });

  final MonthlyPrivateReportSectionType type;
  final String heading;
  final List<String> lines;
  final List<String> bullets;

  bool get hasContent =>
      lines.any((line) => line.trim().isNotEmpty) ||
      bullets.any((bullet) => bullet.trim().isNotEmpty);
}

class MonthlyPrivateReportPreview {
  const MonthlyPrivateReportPreview({
    required this.sections,
    required this.hasConfirmedRepeat,
    required this.hasChangeSignal,
    required this.hasHelpedSignal,
    required this.hasQuietSignal,
  });

  final List<MonthlyPrivateReportSection> sections;
  final bool hasConfirmedRepeat;
  final bool hasChangeSignal;
  final bool hasHelpedSignal;
  final bool hasQuietSignal;

  bool get hasSufficientEvidence => sections.isNotEmpty;
}

enum MonthlyPrivateReportSurface {
  archivePatterns('archive_patterns'),
  weeklyReviewPreview('weekly_review_preview'),
  recordPostSaveAfterProof('record_post_save_after_proof');

  const MonthlyPrivateReportSurface(this.analyticsValue);
  final String analyticsValue;
}

class MonthlyPrivateReportContext {
  const MonthlyPrivateReportContext({
    required this.surface,
    required this.entryCount,
    required this.isPro,
    required this.dismissed,
    required this.hasConfirmedRepeat,
    required this.preview,
    required this.isZeroEntryState,
    required this.isFirstRecordingState,
    required this.isDegradedTranscriptState,
    required this.isPostSaveDegradedState,
    required this.firstProofTruthQuestionActive,
    required this.whatChangedQuestionActive,
    required this.patternReviewInboxHasActiveItems,
    required this.proLockMomentVisible,
    required this.proEvidenceValueVisible,
  });

  final MonthlyPrivateReportSurface surface;
  final int entryCount;
  final bool isPro;
  final bool dismissed;
  final bool hasConfirmedRepeat;
  final MonthlyPrivateReportPreview? preview;
  final bool isZeroEntryState;
  final bool isFirstRecordingState;
  final bool isDegradedTranscriptState;
  final bool isPostSaveDegradedState;
  final bool firstProofTruthQuestionActive;
  final bool whatChangedQuestionActive;
  final bool patternReviewInboxHasActiveItems;
  final bool proLockMomentVisible;
  final bool proEvidenceValueVisible;
}

class MonthlyPrivateReportDisplay {
  const MonthlyPrivateReportDisplay({
    required this.title,
    required this.body,
    required this.proReason,
    required this.chatDifferentiation,
    required this.cta,
    required this.secondary,
    required this.sheetTitle,
    required this.sheetIntro,
    required this.proValueLine,
    required this.sheetSeeProCta,
  });

  final String title;
  final String body;
  final String proReason;
  final String chatDifferentiation;
  final String cta;
  final String secondary;
  final String sheetTitle;
  final String sheetIntro;
  final String proValueLine;
  final String sheetSeeProCta;
}