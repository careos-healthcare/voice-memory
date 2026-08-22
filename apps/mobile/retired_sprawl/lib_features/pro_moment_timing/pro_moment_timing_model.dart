import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/features/proof_quality_response/proof_quality_response_model.dart';

enum ProMomentTimingSurface {
  recordReady,
  recordPostSave,
  archivePatterns,
  paywall,
}

extension ProMomentTimingSurfaceStorage on ProMomentTimingSurface {
  String get analyticsValue => switch (this) {
    ProMomentTimingSurface.recordReady => 'record_ready',
    ProMomentTimingSurface.recordPostSave => 'record_post_save',
    ProMomentTimingSurface.archivePatterns => 'archive_patterns',
    ProMomentTimingSurface.paywall => 'paywall',
  };
}

enum ProMomentTimingTrigger {
  timelineProofMoment,
  firstProofPayoff,
  betaTesterReport,
  monthlyPrivateReportPreview,
  usefulFeedback,
  correctionImprovedTimeline,
  betaProofLiftUnderValidProof,
  returnAfterProofStrengthened,
  freshReturnAfterCorrection,
  usefulProofConfidence,
  strongProofConfidence,
  solidStrongPatternWithSafeAnchors,
}

extension ProMomentTimingTriggerStorage on ProMomentTimingTrigger {
  String get analyticsValue => switch (this) {
    ProMomentTimingTrigger.timelineProofMoment => 'timeline_proof_moment',
    ProMomentTimingTrigger.firstProofPayoff => 'first_proof_payoff',
    ProMomentTimingTrigger.betaTesterReport => 'beta_tester_report',
    ProMomentTimingTrigger.monthlyPrivateReportPreview =>
      'monthly_private_report_preview',
    ProMomentTimingTrigger.usefulFeedback => 'useful_feedback',
    ProMomentTimingTrigger.correctionImprovedTimeline =>
      'correction_improved_timeline',
    ProMomentTimingTrigger.betaProofLiftUnderValidProof =>
      'beta_proof_lift_under_valid_proof',
    ProMomentTimingTrigger.returnAfterProofStrengthened =>
      'return_after_proof_strengthened',
    ProMomentTimingTrigger.freshReturnAfterCorrection =>
      'fresh_return_after_correction',
    ProMomentTimingTrigger.usefulProofConfidence => 'useful_proof_confidence',
    ProMomentTimingTrigger.strongProofConfidence => 'strong_proof_confidence',
    ProMomentTimingTrigger.solidStrongPatternWithSafeAnchors =>
      'solid_strong_pattern_with_safe_anchors',
  };
}

enum ProMomentTimingBlockedReason {
  beforeFirstSave,
  beforeFirstProof,
  recording,
  postSaveDegraded,
  feedbackTooVague,
  feedbackNotRelevant,
  whatChangedActive,
  patternReviewInboxActive,
  proSlotAlreadyUsed,
  noAllowedMoment,
}

extension ProMomentTimingBlockedReasonStorage on ProMomentTimingBlockedReason {
  String get analyticsValue => switch (this) {
    ProMomentTimingBlockedReason.beforeFirstSave => 'before_first_save',
    ProMomentTimingBlockedReason.beforeFirstProof => 'before_first_proof',
    ProMomentTimingBlockedReason.recording => 'recording',
    ProMomentTimingBlockedReason.postSaveDegraded => 'post_save_degraded',
    ProMomentTimingBlockedReason.feedbackTooVague => 'feedback_too_vague',
    ProMomentTimingBlockedReason.feedbackNotRelevant => 'feedback_not_relevant',
    ProMomentTimingBlockedReason.whatChangedActive => 'what_changed_active',
    ProMomentTimingBlockedReason.patternReviewInboxActive =>
      'pattern_review_inbox_active',
    ProMomentTimingBlockedReason.proSlotAlreadyUsed => 'pro_slot_already_used',
    ProMomentTimingBlockedReason.noAllowedMoment => 'no_allowed_moment',
  };
}

class ProMomentTimingContext {
  const ProMomentTimingContext({
    required this.surface,
    required this.source,
    required this.entryCount,
    this.isRecording = false,
    this.isZeroEntryState = false,
    this.isFirstRecordingState = false,
    this.isPostSaveDegradedState = false,
    this.isDegradedTranscriptState = false,
    this.hasFirstProof = false,
    this.hasTimelineProofVisible = false,
    this.hasFirstProofPayoffVisible = false,
    this.hasBetaTesterReportVisible = false,
    this.hasMonthlyPrivateReportPreviewVisible = false,
    this.hasCorrectionMemoryVisible = false,
    this.hasBetaProofLiftVisible = false,
    this.hasReturnAfterProofStrengthenedVisible = false,
    this.feedbackState = ProofQualityFeedbackState.none,
    this.whatChangedQuestionActive = false,
    this.patternReviewInboxHasActiveItems = false,
    this.proSlotAvailable = true,
    this.confidenceLevel,
    this.hasSafeAnchor = false,
    this.hasFreshReturnAfterCorrection = false,
    this.hasSolidStrongPatternWithSafeAnchors = false,
  });

  final ProMomentTimingSurface surface;
  final String source;
  final int entryCount;
  final bool isRecording;
  final bool isZeroEntryState;
  final bool isFirstRecordingState;
  final bool isPostSaveDegradedState;
  final bool isDegradedTranscriptState;
  final bool hasFirstProof;
  final bool hasTimelineProofVisible;
  final bool hasFirstProofPayoffVisible;
  final bool hasBetaTesterReportVisible;
  final bool hasMonthlyPrivateReportPreviewVisible;
  final bool hasCorrectionMemoryVisible;
  final bool hasBetaProofLiftVisible;
  final bool hasReturnAfterProofStrengthenedVisible;
  final ProofQualityFeedbackState feedbackState;
  final bool whatChangedQuestionActive;
  final bool patternReviewInboxHasActiveItems;
  final bool proSlotAvailable;
  final ProofConfidenceLevel? confidenceLevel;
  final bool hasSafeAnchor;
  final bool hasFreshReturnAfterCorrection;
  final bool hasSolidStrongPatternWithSafeAnchors;

  bool get hasTimelineProofSignal => hasTimelineProofVisible;

  ProMomentTimingContext copyWith({
    bool? hasTimelineProofVisible,
    bool? hasFirstProofPayoffVisible,
    bool? hasBetaTesterReportVisible,
    bool? hasMonthlyPrivateReportPreviewVisible,
    bool? hasCorrectionMemoryVisible,
    bool? hasBetaProofLiftVisible,
    bool? hasReturnAfterProofStrengthenedVisible,
    ProofQualityFeedbackState? feedbackState,
    bool? proSlotAvailable,
    ProofConfidenceLevel? confidenceLevel,
    bool? hasSafeAnchor,
    bool? hasFreshReturnAfterCorrection,
    bool? hasSolidStrongPatternWithSafeAnchors,
  }) {
    return ProMomentTimingContext(
      surface: surface,
      source: source,
      entryCount: entryCount,
      isRecording: isRecording,
      isZeroEntryState: isZeroEntryState,
      isFirstRecordingState: isFirstRecordingState,
      isPostSaveDegradedState: isPostSaveDegradedState,
      isDegradedTranscriptState: isDegradedTranscriptState,
      hasFirstProof: hasFirstProof,
      hasTimelineProofVisible:
          hasTimelineProofVisible ?? this.hasTimelineProofVisible,
      hasFirstProofPayoffVisible:
          hasFirstProofPayoffVisible ?? this.hasFirstProofPayoffVisible,
      hasBetaTesterReportVisible:
          hasBetaTesterReportVisible ?? this.hasBetaTesterReportVisible,
      hasMonthlyPrivateReportPreviewVisible:
          hasMonthlyPrivateReportPreviewVisible ??
          this.hasMonthlyPrivateReportPreviewVisible,
      hasCorrectionMemoryVisible:
          hasCorrectionMemoryVisible ?? this.hasCorrectionMemoryVisible,
      hasBetaProofLiftVisible:
          hasBetaProofLiftVisible ?? this.hasBetaProofLiftVisible,
      hasReturnAfterProofStrengthenedVisible:
          hasReturnAfterProofStrengthenedVisible ??
          this.hasReturnAfterProofStrengthenedVisible,
      feedbackState: feedbackState ?? this.feedbackState,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      proSlotAvailable: proSlotAvailable ?? this.proSlotAvailable,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      hasSafeAnchor: hasSafeAnchor ?? this.hasSafeAnchor,
      hasFreshReturnAfterCorrection:
          hasFreshReturnAfterCorrection ?? this.hasFreshReturnAfterCorrection,
      hasSolidStrongPatternWithSafeAnchors:
          hasSolidStrongPatternWithSafeAnchors ??
          this.hasSolidStrongPatternWithSafeAnchors,
    );
  }
}

class ProMomentTimingResult {
  const ProMomentTimingResult({
    required this.allowed,
    this.trigger,
    this.blockedReason,
    this.reason,
    this.hasTimelineProof = false,
  });

  const ProMomentTimingResult.allowed({
    required ProMomentTimingTrigger trigger,
    required String reason,
    bool hasTimelineProof = false,
  }) : this(
         allowed: true,
         trigger: trigger,
         reason: reason,
         hasTimelineProof: hasTimelineProof,
       );

  const ProMomentTimingResult.blocked({
    required ProMomentTimingBlockedReason blockedReason,
    required String reason,
    bool hasTimelineProof = false,
  }) : this(
         allowed: false,
         blockedReason: blockedReason,
         reason: reason,
         hasTimelineProof: hasTimelineProof,
       );

  final bool allowed;
  final ProMomentTimingTrigger? trigger;
  final ProMomentTimingBlockedReason? blockedReason;
  final String? reason;
  final bool hasTimelineProof;
}