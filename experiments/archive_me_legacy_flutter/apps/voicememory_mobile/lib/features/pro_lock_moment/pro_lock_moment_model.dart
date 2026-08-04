/// Display model for the Pro lock moment — no journal content.
class ProLockMomentDisplay {
  const ProLockMomentDisplay({
    required this.title,
    required this.body,
    required this.paidReason,
    required this.chatDifferentiation,
    required this.cta,
    required this.secondary,
    required this.sheetTitle,
  });

  final String title;
  final String body;
  final String paidReason;
  final String chatDifferentiation;
  final String cta;
  final String secondary;
  final String sheetTitle;
}

class ProLockMomentContext {
  const ProLockMomentContext({
    required this.entryCount,
    required this.isPro,
    required this.dismissed,
    required this.hasFirstProof,
    required this.hasConfirmedRepeat,
    required this.isZeroEntryState,
    required this.isFirstRecordingState,
    required this.isDegradedTranscriptState,
    required this.isPostSaveDegradedState,
    required this.firstProofTruthQuestionActive,
    required this.whatChangedQuestionActive,
    required this.patternReviewInboxHasActiveItems,
    required this.proEvidenceValueVisible,
  });

  final int entryCount;
  final bool isPro;
  final bool dismissed;
  final bool hasFirstProof;
  final bool hasConfirmedRepeat;
  final bool isZeroEntryState;
  final bool isFirstRecordingState;
  final bool isDegradedTranscriptState;
  final bool isPostSaveDegradedState;
  final bool firstProofTruthQuestionActive;
  final bool whatChangedQuestionActive;
  final bool patternReviewInboxHasActiveItems;
  final bool proEvidenceValueVisible;
}
