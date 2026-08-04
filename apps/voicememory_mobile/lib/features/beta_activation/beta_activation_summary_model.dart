/// Highest activation milestone reached on this device.
enum BetaActivationStatus {
  notStarted,
  firstMomentSaved,
  almostAtFirstProof,
  firstProofReached,
  returnedAfterProof,
  weeklyReviewReached,
}

/// Extension counters not covered by [BetaActivationLoopCounts].
class BetaActivationSummaryExtension {
  const BetaActivationSummaryExtension({
    this.firstProofReached = 0,
    this.patternsOpened = 0,
    this.patternDetailsOpened = 0,
    this.weeklyReviewOpened = 0,
    this.returnDayFlowAnswered = 0,
    this.transcriptCorrected = 0,
    this.betaFeedbackOpened = 0,
    this.betaFeedbackSubmitted = 0,
    this.firstProofTruthYes = 0,
    this.firstProofTruthSortOf = 0,
    this.firstProofTruthNo = 0,
    this.firstProofActionWatchThisNext = 0,
    this.firstProofActionViewPatternDetails = 0,
    this.firstProofActionRenamePattern = 0,
    this.firstProofActionKeepRecording = 0,
    this.firstProofActionCorrectTranscript = 0,
    this.firstProofActionRemoveFromPattern = 0,
  });

  final int firstProofReached;
  final int patternsOpened;
  final int patternDetailsOpened;
  final int weeklyReviewOpened;
  final int returnDayFlowAnswered;
  final int transcriptCorrected;
  final int betaFeedbackOpened;
  final int betaFeedbackSubmitted;
  final int firstProofTruthYes;
  final int firstProofTruthSortOf;
  final int firstProofTruthNo;
  final int firstProofActionWatchThisNext;
  final int firstProofActionViewPatternDetails;
  final int firstProofActionRenamePattern;
  final int firstProofActionKeepRecording;
  final int firstProofActionCorrectTranscript;
  final int firstProofActionRemoveFromPattern;

  static const empty = BetaActivationSummaryExtension();

  BetaActivationSummaryExtension copyWithIncrement(String field) {
    switch (field) {
      case 'firstProofReached':
        return copyWith(firstProofReached: firstProofReached + 1);
      case 'patternsOpened':
        return copyWith(patternsOpened: patternsOpened + 1);
      case 'patternDetailsOpened':
        return copyWith(patternDetailsOpened: patternDetailsOpened + 1);
      case 'weeklyReviewOpened':
        return copyWith(weeklyReviewOpened: weeklyReviewOpened + 1);
      case 'returnDayFlowAnswered':
        return copyWith(returnDayFlowAnswered: returnDayFlowAnswered + 1);
      case 'transcriptCorrected':
        return copyWith(transcriptCorrected: transcriptCorrected + 1);
      case 'betaFeedbackOpened':
        return copyWith(betaFeedbackOpened: betaFeedbackOpened + 1);
      case 'betaFeedbackSubmitted':
        return copyWith(betaFeedbackSubmitted: betaFeedbackSubmitted + 1);
      case 'firstProofTruthYes':
        return copyWith(firstProofTruthYes: firstProofTruthYes + 1);
      case 'firstProofTruthSortOf':
        return copyWith(firstProofTruthSortOf: firstProofTruthSortOf + 1);
      case 'firstProofTruthNo':
        return copyWith(firstProofTruthNo: firstProofTruthNo + 1);
      case 'firstProofActionWatchThisNext':
        return copyWith(
          firstProofActionWatchThisNext: firstProofActionWatchThisNext + 1,
        );
      case 'firstProofActionViewPatternDetails':
        return copyWith(
          firstProofActionViewPatternDetails:
              firstProofActionViewPatternDetails + 1,
        );
      case 'firstProofActionRenamePattern':
        return copyWith(
          firstProofActionRenamePattern: firstProofActionRenamePattern + 1,
        );
      case 'firstProofActionKeepRecording':
        return copyWith(
          firstProofActionKeepRecording: firstProofActionKeepRecording + 1,
        );
      case 'firstProofActionCorrectTranscript':
        return copyWith(
          firstProofActionCorrectTranscript:
              firstProofActionCorrectTranscript + 1,
        );
      case 'firstProofActionRemoveFromPattern':
        return copyWith(
          firstProofActionRemoveFromPattern:
              firstProofActionRemoveFromPattern + 1,
        );
      default:
        return this;
    }
  }

  BetaActivationSummaryExtension copyWith({
    int? firstProofReached,
    int? patternsOpened,
    int? patternDetailsOpened,
    int? weeklyReviewOpened,
    int? returnDayFlowAnswered,
    int? transcriptCorrected,
    int? betaFeedbackOpened,
    int? betaFeedbackSubmitted,
    int? firstProofTruthYes,
    int? firstProofTruthSortOf,
    int? firstProofTruthNo,
    int? firstProofActionWatchThisNext,
    int? firstProofActionViewPatternDetails,
    int? firstProofActionRenamePattern,
    int? firstProofActionKeepRecording,
    int? firstProofActionCorrectTranscript,
    int? firstProofActionRemoveFromPattern,
  }) {
    return BetaActivationSummaryExtension(
      firstProofReached: firstProofReached ?? this.firstProofReached,
      patternsOpened: patternsOpened ?? this.patternsOpened,
      patternDetailsOpened: patternDetailsOpened ?? this.patternDetailsOpened,
      weeklyReviewOpened: weeklyReviewOpened ?? this.weeklyReviewOpened,
      returnDayFlowAnswered:
          returnDayFlowAnswered ?? this.returnDayFlowAnswered,
      transcriptCorrected: transcriptCorrected ?? this.transcriptCorrected,
      betaFeedbackOpened: betaFeedbackOpened ?? this.betaFeedbackOpened,
      betaFeedbackSubmitted:
          betaFeedbackSubmitted ?? this.betaFeedbackSubmitted,
      firstProofTruthYes: firstProofTruthYes ?? this.firstProofTruthYes,
      firstProofTruthSortOf:
          firstProofTruthSortOf ?? this.firstProofTruthSortOf,
      firstProofTruthNo: firstProofTruthNo ?? this.firstProofTruthNo,
      firstProofActionWatchThisNext:
          firstProofActionWatchThisNext ?? this.firstProofActionWatchThisNext,
      firstProofActionViewPatternDetails:
          firstProofActionViewPatternDetails ??
          this.firstProofActionViewPatternDetails,
      firstProofActionRenamePattern:
          firstProofActionRenamePattern ?? this.firstProofActionRenamePattern,
      firstProofActionKeepRecording:
          firstProofActionKeepRecording ?? this.firstProofActionKeepRecording,
      firstProofActionCorrectTranscript:
          firstProofActionCorrectTranscript ??
          this.firstProofActionCorrectTranscript,
      firstProofActionRemoveFromPattern:
          firstProofActionRemoveFromPattern ??
          this.firstProofActionRemoveFromPattern,
    );
  }

  Map<String, dynamic> toMap() => {
    'firstProofReached': firstProofReached,
    'patternsOpened': patternsOpened,
    'patternDetailsOpened': patternDetailsOpened,
    'weeklyReviewOpened': weeklyReviewOpened,
    'returnDayFlowAnswered': returnDayFlowAnswered,
    'transcriptCorrected': transcriptCorrected,
    'betaFeedbackOpened': betaFeedbackOpened,
    'betaFeedbackSubmitted': betaFeedbackSubmitted,
    'firstProofTruthYes': firstProofTruthYes,
    'firstProofTruthSortOf': firstProofTruthSortOf,
    'firstProofTruthNo': firstProofTruthNo,
    'firstProofActionWatchThisNext': firstProofActionWatchThisNext,
    'firstProofActionViewPatternDetails': firstProofActionViewPatternDetails,
    'firstProofActionRenamePattern': firstProofActionRenamePattern,
    'firstProofActionKeepRecording': firstProofActionKeepRecording,
    'firstProofActionCorrectTranscript': firstProofActionCorrectTranscript,
    'firstProofActionRemoveFromPattern': firstProofActionRemoveFromPattern,
  };

  factory BetaActivationSummaryExtension.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return empty;
    int n(String key) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return BetaActivationSummaryExtension(
      firstProofReached: n('firstProofReached'),
      patternsOpened: n('patternsOpened'),
      patternDetailsOpened: n('patternDetailsOpened'),
      weeklyReviewOpened: n('weeklyReviewOpened'),
      returnDayFlowAnswered: n('returnDayFlowAnswered'),
      transcriptCorrected: n('transcriptCorrected'),
      betaFeedbackOpened: n('betaFeedbackOpened'),
      betaFeedbackSubmitted: n('betaFeedbackSubmitted'),
      firstProofTruthYes: n('firstProofTruthYes'),
      firstProofTruthSortOf: n('firstProofTruthSortOf'),
      firstProofTruthNo: n('firstProofTruthNo'),
      firstProofActionWatchThisNext: n('firstProofActionWatchThisNext'),
      firstProofActionViewPatternDetails: n(
        'firstProofActionViewPatternDetails',
      ),
      firstProofActionRenamePattern: n('firstProofActionRenamePattern'),
      firstProofActionKeepRecording: n('firstProofActionKeepRecording'),
      firstProofActionCorrectTranscript: n('firstProofActionCorrectTranscript'),
      firstProofActionRemoveFromPattern: n('firstProofActionRemoveFromPattern'),
    );
  }
}

/// Read-only merged view for the beta progress summary sheet.
class BetaActivationSummary {
  const BetaActivationSummary({
    required this.appOpens,
    required this.recordScreenViews,
    required this.firstMomentSaved,
    required this.secondMomentSaved,
    required this.firstProofReached,
    required this.patternsOpened,
    required this.patternDetailsOpened,
    required this.weeklyReviewOpened,
    required this.returnDayFlowAnswered,
    required this.transcriptCorrected,
    required this.betaFeedbackOpened,
    required this.betaFeedbackSubmitted,
    required this.firstProofTruthYes,
    required this.firstProofTruthSortOf,
    required this.firstProofTruthNo,
    required this.firstProofActionWatchThisNext,
    required this.firstProofActionViewPatternDetails,
    required this.firstProofActionRenamePattern,
    required this.firstProofActionKeepRecording,
    required this.firstProofActionCorrectTranscript,
    required this.firstProofActionRemoveFromPattern,
    required this.proScreenOpened,
    required this.restorePurchasesTapped,
    required this.returnedAfterFirstProof,
    required this.status,
  });

  final int appOpens;
  final int recordScreenViews;
  final int firstMomentSaved;
  final int secondMomentSaved;
  final int firstProofReached;
  final int patternsOpened;
  final int patternDetailsOpened;
  final int weeklyReviewOpened;
  final int returnDayFlowAnswered;
  final int transcriptCorrected;
  final int betaFeedbackOpened;
  final int betaFeedbackSubmitted;
  final int firstProofTruthYes;
  final int firstProofTruthSortOf;
  final int firstProofTruthNo;
  final int firstProofActionWatchThisNext;
  final int firstProofActionViewPatternDetails;
  final int firstProofActionRenamePattern;
  final int firstProofActionKeepRecording;
  final int firstProofActionCorrectTranscript;
  final int firstProofActionRemoveFromPattern;
  final int proScreenOpened;
  final int restorePurchasesTapped;
  final int returnedAfterFirstProof;
  final BetaActivationStatus status;
}
