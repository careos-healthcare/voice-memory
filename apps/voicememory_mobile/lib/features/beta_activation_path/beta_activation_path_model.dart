enum BetaActivationPathStage {
  firstSave,
  secondSave,
  thirdSave,
  proofCheck,
  valueMoment,
  proReview,
  paidMomentReached,
}

extension BetaActivationPathStageAnalytics on BetaActivationPathStage {
  String get analyticsValue => switch (this) {
        BetaActivationPathStage.firstSave => 'first_save',
        BetaActivationPathStage.secondSave => 'second_save',
        BetaActivationPathStage.thirdSave => 'third_save',
        BetaActivationPathStage.proofCheck => 'proof_check',
        BetaActivationPathStage.valueMoment => 'value_moment',
        BetaActivationPathStage.proReview => 'pro_review',
        BetaActivationPathStage.paidMomentReached => 'paid_moment_reached',
      };
}

enum BetaActivationPathSlot {
  guidance,
  revenue,
  hidden,
}

enum BetaActivationPathActionType {
  saveFirstMoment,
  saveAnotherMoment,
  saveOneMoreMoment,
  viewTimelineProof,
  seeWhatProKeeps,
  reviewProValue,
  notNow,
  notToday,
}

extension BetaActivationPathActionTypeAnalytics on BetaActivationPathActionType {
  String get analyticsValue => switch (this) {
        BetaActivationPathActionType.saveFirstMoment => 'save_first_moment',
        BetaActivationPathActionType.saveAnotherMoment => 'save_another_moment',
        BetaActivationPathActionType.saveOneMoreMoment => 'save_one_more_moment',
        BetaActivationPathActionType.viewTimelineProof => 'view_timeline_proof',
        BetaActivationPathActionType.seeWhatProKeeps => 'see_what_pro_keeps',
        BetaActivationPathActionType.reviewProValue => 'review_pro_value',
        BetaActivationPathActionType.notNow => 'not_now',
        BetaActivationPathActionType.notToday => 'not_today',
      };
}

class BetaActivationPathContext {
  const BetaActivationPathContext({
    required this.source,
    required this.entryCount,
    required this.betaMissionEnabled,
    required this.dismissedForToday,
    required this.hasUsefulProof,
    required this.hasTimelineProof,
    required this.hasPaywallSeen,
    required this.hasPurchaseCtaTapped,
    required this.strongerProCardVisible,
    required this.isReady,
    required this.isRecording,
    required this.isPostSave,
    required this.isDegradedTranscriptState,
    required this.isPostSaveDegradedState,
    required this.whatChangedQuestionActive,
    required this.patternReviewInboxHasActiveItems,
    required this.isPermissionBlocked,
  });

  final String source;
  final int entryCount;
  final bool betaMissionEnabled;
  final bool dismissedForToday;
  final bool hasUsefulProof;
  final bool hasTimelineProof;
  final bool hasPaywallSeen;
  final bool hasPurchaseCtaTapped;
  final bool strongerProCardVisible;
  final bool isReady;
  final bool isRecording;
  final bool isPostSave;
  final bool isDegradedTranscriptState;
  final bool isPostSaveDegradedState;
  final bool whatChangedQuestionActive;
  final bool patternReviewInboxHasActiveItems;
  final bool isPermissionBlocked;
}

class BetaActivationPathResult {
  const BetaActivationPathResult({
    required this.shouldShow,
    required this.stage,
    required this.slot,
    required this.title,
    required this.body,
    required this.primaryCta,
    required this.secondaryCta,
    required this.primaryActionType,
    required this.secondaryActionType,
    required this.source,
    required this.entryCount,
    required this.hasUsefulProof,
    required this.hasTimelineProof,
    required this.hasPaywallSeen,
    required this.diagnosis,
  });

  final bool shouldShow;
  final BetaActivationPathStage stage;
  final BetaActivationPathSlot slot;
  final String title;
  final String body;
  final String primaryCta;
  final String secondaryCta;
  final BetaActivationPathActionType primaryActionType;
  final BetaActivationPathActionType secondaryActionType;
  final String source;
  final int entryCount;
  final bool hasUsefulProof;
  final bool hasTimelineProof;
  final bool hasPaywallSeen;
  final String diagnosis;
}
