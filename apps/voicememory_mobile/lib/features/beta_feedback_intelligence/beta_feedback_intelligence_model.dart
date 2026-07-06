/// Safe answer buckets for beta feedback intelligence — no private content.
enum BetaChatGptDifferenceAnswer {
  yes,
  notSure,
  no,
}

enum BetaDifferentiatorAnswer {
  showedRepeats,
  showedChange,
  rememberedOlderMoments,
  didNotFeelDifferent,
  other,
}

enum BetaWouldPayAnswer {
  yes,
  maybe,
  no,
}

enum BetaMainConfusionBucket {
  firstRecording,
  firstProof,
  patterns,
  pro,
  differenceFromChatGpt,
  nothing,
}

enum BetaStrongestMomentBucket {
  firstProof,
  whatChanged,
  quietSignal,
  privateReport,
  proExplanation,
  nothingYet,
}

enum BetaFeedbackIntelligenceSurface {
  testingArchiveMe('testing_archiveme'),
  settingsBeta('settings_beta'),
  afterProEvidenceSheet('after_pro_evidence_sheet'),
  afterFirstProofPayoff('after_first_proof_payoff');

  const BetaFeedbackIntelligenceSurface(this.analyticsValue);
  final String analyticsValue;
}

/// Local milestone + feedback state — metadata only.
class BetaFeedbackIntelligenceState {
  const BetaFeedbackIntelligenceState({
    this.hasSavedFirstMoment = false,
    this.hasReachedFirstProof = false,
    this.hasSeenChatGptDifferentiation = false,
    this.hasSeenProEvidenceBridge = false,
    this.hasOpenedProEvidenceSheet = false,
    this.hasSubmittedBetaFeedback = false,
    this.chatGptDifferenceAnswer,
    this.differentiatorAnswer,
    this.wouldPayAnswer,
    this.mainConfusionBucket,
    this.strongestMomentBucket,
    this.submittedDateKey,
    this.updatedAt,
  });

  final bool hasSavedFirstMoment;
  final bool hasReachedFirstProof;
  final bool hasSeenChatGptDifferentiation;
  final bool hasSeenProEvidenceBridge;
  final bool hasOpenedProEvidenceSheet;
  final bool hasSubmittedBetaFeedback;
  final BetaChatGptDifferenceAnswer? chatGptDifferenceAnswer;
  final BetaDifferentiatorAnswer? differentiatorAnswer;
  final BetaWouldPayAnswer? wouldPayAnswer;
  final BetaMainConfusionBucket? mainConfusionBucket;
  final BetaStrongestMomentBucket? strongestMomentBucket;
  final String? submittedDateKey;
  final DateTime? updatedAt;

  bool? get testerUnderstoodArchiveMe => switch (chatGptDifferenceAnswer) {
        BetaChatGptDifferenceAnswer.yes => true,
        BetaChatGptDifferenceAnswer.notSure => null,
        BetaChatGptDifferenceAnswer.no => false,
        null => null,
      };

  BetaWouldPayAnswer? get testerWouldPay => wouldPayAnswer;
  BetaMainConfusionBucket? get testerMainConfusion => mainConfusionBucket;
  BetaStrongestMomentBucket? get testerMostValuableMoment =>
      strongestMomentBucket;
  BetaWouldPayAnswer? get testerPriceSignal => wouldPayAnswer;

  static const empty = BetaFeedbackIntelligenceState();

  bool get submittedForCurrentSession =>
      hasSubmittedBetaFeedback && submittedDateKey != null;

  BetaFeedbackIntelligenceState copyWith({
    bool? hasSavedFirstMoment,
    bool? hasReachedFirstProof,
    bool? hasSeenChatGptDifferentiation,
    bool? hasSeenProEvidenceBridge,
    bool? hasOpenedProEvidenceSheet,
    bool? hasSubmittedBetaFeedback,
    BetaChatGptDifferenceAnswer? chatGptDifferenceAnswer,
    bool clearChatGptDifferenceAnswer = false,
    BetaDifferentiatorAnswer? differentiatorAnswer,
    bool clearDifferentiatorAnswer = false,
    BetaWouldPayAnswer? wouldPayAnswer,
    bool clearWouldPayAnswer = false,
    BetaMainConfusionBucket? mainConfusionBucket,
    bool clearMainConfusionBucket = false,
    BetaStrongestMomentBucket? strongestMomentBucket,
    bool clearStrongestMomentBucket = false,
    String? submittedDateKey,
    bool clearSubmittedDateKey = false,
    DateTime? updatedAt,
  }) {
    return BetaFeedbackIntelligenceState(
      hasSavedFirstMoment: hasSavedFirstMoment ?? this.hasSavedFirstMoment,
      hasReachedFirstProof:
          hasReachedFirstProof ?? this.hasReachedFirstProof,
      hasSeenChatGptDifferentiation: hasSeenChatGptDifferentiation ??
          this.hasSeenChatGptDifferentiation,
      hasSeenProEvidenceBridge:
          hasSeenProEvidenceBridge ?? this.hasSeenProEvidenceBridge,
      hasOpenedProEvidenceSheet:
          hasOpenedProEvidenceSheet ?? this.hasOpenedProEvidenceSheet,
      hasSubmittedBetaFeedback:
          hasSubmittedBetaFeedback ?? this.hasSubmittedBetaFeedback,
      chatGptDifferenceAnswer: clearChatGptDifferenceAnswer
          ? null
          : (chatGptDifferenceAnswer ?? this.chatGptDifferenceAnswer),
      differentiatorAnswer: clearDifferentiatorAnswer
          ? null
          : (differentiatorAnswer ?? this.differentiatorAnswer),
      wouldPayAnswer: clearWouldPayAnswer
          ? null
          : (wouldPayAnswer ?? this.wouldPayAnswer),
      mainConfusionBucket: clearMainConfusionBucket
          ? null
          : (mainConfusionBucket ?? this.mainConfusionBucket),
      strongestMomentBucket: clearStrongestMomentBucket
          ? null
          : (strongestMomentBucket ?? this.strongestMomentBucket),
      submittedDateKey: clearSubmittedDateKey
          ? null
          : (submittedDateKey ?? this.submittedDateKey),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        if (hasSavedFirstMoment) 'hasSavedFirstMoment': true,
        if (hasReachedFirstProof) 'hasReachedFirstProof': true,
        if (hasSeenChatGptDifferentiation) 'hasSeenChatGptDifferentiation': true,
        if (hasSeenProEvidenceBridge) 'hasSeenProEvidenceBridge': true,
        if (hasOpenedProEvidenceSheet) 'hasOpenedProEvidenceSheet': true,
        if (hasSubmittedBetaFeedback) 'hasSubmittedBetaFeedback': true,
        if (chatGptDifferenceAnswer != null)
          'chatGptDifferenceAnswer': chatGptDifferenceAnswer!.name,
        if (differentiatorAnswer != null)
          'differentiatorAnswer': differentiatorAnswer!.name,
        if (wouldPayAnswer != null) 'wouldPayAnswer': wouldPayAnswer!.name,
        if (mainConfusionBucket != null)
          'mainConfusionBucket': mainConfusionBucket!.name,
        if (strongestMomentBucket != null)
          'strongestMomentBucket': strongestMomentBucket!.name,
        if (submittedDateKey != null) 'submittedDateKey': submittedDateKey,
        if (updatedAt != null)
          'updatedAt': updatedAt!.toUtc().toIso8601String(),
      };

  static BetaFeedbackIntelligenceState fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return empty;
    return BetaFeedbackIntelligenceState(
      hasSavedFirstMoment: json['hasSavedFirstMoment'] == true,
      hasReachedFirstProof: json['hasReachedFirstProof'] == true,
      hasSeenChatGptDifferentiation:
          json['hasSeenChatGptDifferentiation'] == true,
      hasSeenProEvidenceBridge: json['hasSeenProEvidenceBridge'] == true,
      hasOpenedProEvidenceSheet: json['hasOpenedProEvidenceSheet'] == true,
      hasSubmittedBetaFeedback: json['hasSubmittedBetaFeedback'] == true,
      chatGptDifferenceAnswer: _enumByName(
        json['chatGptDifferenceAnswer'],
        BetaChatGptDifferenceAnswer.values,
      ),
      differentiatorAnswer: _enumByName(
        json['differentiatorAnswer'],
        BetaDifferentiatorAnswer.values,
      ),
      wouldPayAnswer: _enumByName(
        json['wouldPayAnswer'],
        BetaWouldPayAnswer.values,
      ),
      mainConfusionBucket: _enumByName(
        json['mainConfusionBucket'],
        BetaMainConfusionBucket.values,
      ),
      strongestMomentBucket: _enumByName(
        json['strongestMomentBucket'],
        BetaStrongestMomentBucket.values,
      ),
      submittedDateKey: json['submittedDateKey'] is String
          ? json['submittedDateKey'] as String
          : null,
      updatedAt: json['updatedAt'] is String
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  static T? _enumByName<T extends Enum>(Object? raw, List<T> values) {
    if (raw is! String) return null;
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

class BetaFeedbackIntelligenceContext {
  const BetaFeedbackIntelligenceContext({
    required this.surface,
    required this.entryCount,
    required this.betaMissionEnabled,
    required this.submittedForSession,
    required this.firstProofPayoffSeen,
    required this.proEvidenceSheetOpenedThisSession,
    required this.isZeroEntryState,
    required this.isRecordingState,
    required this.isDegradedTranscriptState,
    required this.isPostSaveDegradedState,
    required this.firstProofTruthQuestionActive,
    required this.whatChangedQuestionActive,
    required this.patternReviewInboxHasActiveItems,
  });

  final BetaFeedbackIntelligenceSurface surface;
  final int entryCount;
  final bool betaMissionEnabled;
  final bool submittedForSession;
  final bool firstProofPayoffSeen;
  final bool proEvidenceSheetOpenedThisSession;
  final bool isZeroEntryState;
  final bool isRecordingState;
  final bool isDegradedTranscriptState;
  final bool isPostSaveDegradedState;
  final bool firstProofTruthQuestionActive;
  final bool whatChangedQuestionActive;
  final bool patternReviewInboxHasActiveItems;
}

class BetaFeedbackIntelligenceSummary {
  const BetaFeedbackIntelligenceSummary({
    required this.firstProofReachedLabel,
    required this.chatGptDifferenceLabel,
    required this.proValueLabel,
    required this.mainConfusionLabel,
    required this.strongestMomentLabel,
    required this.feedbackSubmittedLabel,
    required this.reachedItems,
    required this.stillToTestItems,
    required this.state,
  });

  final String firstProofReachedLabel;
  final String chatGptDifferenceLabel;
  final String proValueLabel;
  final String mainConfusionLabel;
  final String strongestMomentLabel;
  final String feedbackSubmittedLabel;
  final List<String> reachedItems;
  final List<String> stillToTestItems;
  final BetaFeedbackIntelligenceState state;
}
