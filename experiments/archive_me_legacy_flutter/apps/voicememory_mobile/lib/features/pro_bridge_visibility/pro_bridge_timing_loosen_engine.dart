import '../../models/journal_entry.dart';
import '../evidence_anchors/evidence_anchor_engine.dart';
import '../evidence_anchors/evidence_anchor_model.dart';
import '../pattern_match_quality/pattern_match_quality_engine.dart';
import '../pattern_match_quality/pattern_match_quality_model.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_engine.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import '../proof_quality_response/proof_quality_response_model.dart';
import '../pro_moment_timing/pro_moment_timing_model.dart';
import 'pro_bridge_timing_loosen_analytics.dart';
import 'pro_bridge_visibility_model.dart';

/// Loosens Pro bridge timing after useful proof without showing before value.
abstract final class ProBridgeTimingLoosenEngine {
  ProBridgeTimingLoosenEngine._();

  static const minEntryCount = 3;
  static const solidPatternMinEntryCount = 4;

  static ProBridgeTimingLoosenResult evaluate({
    required ProBridgeTimingLoosenInput input,
    bool emitBlockedAnalytics = false,
  }) {
    final blocked = _resolveBlockedReason(input);
    if (blocked != null) {
      if (emitBlockedAnalytics) {
        ProBridgeTimingLoosenAnalytics.blocked(
          source: input.source,
          surface: input.surface.analyticsValue,
          entryCount: input.entryCount,
          blockedReason: blocked.analyticsValue,
          confidenceLevel: input.confidenceLevel?.analyticsValue,
          hasSafeAnchor: input.hasSafeAnchor,
        );
      }
      return ProBridgeTimingLoosenResult.blocked(
        blockedReason: blocked,
        confidenceLevel: input.confidenceLevel,
        hasSafeAnchor: input.hasSafeAnchor,
      );
    }

    final trigger = _resolveAllowedTrigger(input);
    if (trigger == null) {
      if (emitBlockedAnalytics) {
        ProBridgeTimingLoosenAnalytics.blocked(
          source: input.source,
          surface: input.surface.analyticsValue,
          entryCount: input.entryCount,
          blockedReason:
              ProBridgeTimingLoosenBlockedReason.noAllowedMoment.analyticsValue,
          confidenceLevel: input.confidenceLevel?.analyticsValue,
          hasSafeAnchor: input.hasSafeAnchor,
        );
      }
      return ProBridgeTimingLoosenResult.blocked(
        blockedReason: ProBridgeTimingLoosenBlockedReason.noAllowedMoment,
        confidenceLevel: input.confidenceLevel,
        hasSafeAnchor: input.hasSafeAnchor,
      );
    }

    return ProBridgeTimingLoosenResult.allowed(
      trigger: trigger,
      confidenceLevel: input.confidenceLevel,
      hasSafeAnchor: input.hasSafeAnchor,
    );
  }

  static ProBridgeTimingLoosenInput fromVisibilityInput(
    ProBridgeVisibilityInput input,
  ) => ProBridgeTimingLoosenInput(
    surface: input.surface,
    source: input.source,
    entryCount: input.entryCount,
    isRecording: input.isRecording,
    isZeroEntryState: input.isZeroEntryState,
    isFirstRecordingState: input.isFirstRecordingState,
    isPostSaveDegradedState: input.isPostSaveDegradedState,
    isDegradedTranscriptState: input.isDegradedTranscriptState,
    hasFirstProof: input.hasFirstProof,
    hasTimelineProofVisible: input.hasTimelineProofVisible,
    hasFirstProofPayoffVisible: input.hasFirstProofPayoffVisible,
    hasBetaTesterReportVisible: input.hasBetaTesterReportVisible,
    hasMonthlyPrivateReportPreviewVisible:
        input.hasMonthlyPrivateReportPreviewVisible,
    hasCorrectionMemoryVisible: input.hasCorrectionMemoryVisible,
    hasBetaProofLiftVisible: input.hasBetaProofLiftVisible,
    hasReturnAfterProofStrengthenedVisible:
        input.hasReturnAfterProofStrengthenedVisible,
    feedbackState: input.feedbackState,
    whatChangedQuestionActive: input.whatChangedQuestionActive,
    patternReviewInboxHasActiveItems: input.patternReviewInboxHasActiveItems,
    proSlotAvailable: input.proSlotAvailable,
    confidenceLevel: input.confidenceLevel,
    hasSafeAnchor: input.hasSafeAnchor,
    hasFreshReturnAfterCorrection: input.hasFreshReturnAfterCorrection,
    hasSolidStrongPatternWithSafeAnchors:
        input.hasSolidStrongPatternWithSafeAnchors,
  );

  static ProBridgeTimingLoosenInput fromTimingContext(
    ProMomentTimingContext context,
  ) => ProBridgeTimingLoosenInput(
    surface: _surfaceFromTiming(context.surface),
    source: context.source,
    entryCount: context.entryCount,
    isRecording: context.isRecording,
    isZeroEntryState: context.isZeroEntryState,
    isFirstRecordingState: context.isFirstRecordingState,
    isPostSaveDegradedState: context.isPostSaveDegradedState,
    isDegradedTranscriptState: context.isDegradedTranscriptState,
    hasFirstProof: context.hasFirstProof,
    hasTimelineProofVisible: context.hasTimelineProofVisible,
    hasFirstProofPayoffVisible: context.hasFirstProofPayoffVisible,
    hasBetaTesterReportVisible: context.hasBetaTesterReportVisible,
    hasMonthlyPrivateReportPreviewVisible:
        context.hasMonthlyPrivateReportPreviewVisible,
    hasCorrectionMemoryVisible: context.hasCorrectionMemoryVisible,
    hasBetaProofLiftVisible: context.hasBetaProofLiftVisible,
    hasReturnAfterProofStrengthenedVisible:
        context.hasReturnAfterProofStrengthenedVisible,
    feedbackState: context.feedbackState,
    whatChangedQuestionActive: context.whatChangedQuestionActive,
    patternReviewInboxHasActiveItems: context.patternReviewInboxHasActiveItems,
    proSlotAvailable: context.proSlotAvailable,
    confidenceLevel: context.confidenceLevel,
    hasSafeAnchor: context.hasSafeAnchor,
    hasFreshReturnAfterCorrection: context.hasFreshReturnAfterCorrection,
    hasSolidStrongPatternWithSafeAnchors:
        context.hasSolidStrongPatternWithSafeAnchors,
  );

  static ProBridgeTimingLoosenSignals resolveSignals({
    required List<JournalEntry> entries,
    required String source,
    required bool beliefSurfaceVisible,
    List<String> beliefEvidencePhrases = const [],
  }) {
    if (entries.length < minEntryCount) {
      return const ProBridgeTimingLoosenSignals(
        hasSafeAnchor: false,
        hasFreshReturnAfterCorrection: false,
        hasSolidStrongPatternWithSafeAnchors: false,
      );
    }

    final anchorExtraction = EvidenceAnchorEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      source: source,
    );
    final matchQuality = PatternMatchQualityEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      source: source,
      beliefEvidencePhrases: beliefEvidencePhrases,
    );
    final calibration = ProofConfidenceCalibrationEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      source: source,
      beliefEvidencePhrases: beliefEvidencePhrases,
      patternMatchQuality: matchQuality,
      anchorExtraction: anchorExtraction,
    );
    final hasSafeAnchor =
        calibration.hasSafeAnchor || anchorExtraction.hasSafeAnchor;
    final hasFreshReturnAfterCorrection =
        calibration.hasFreshReturn ||
        calibration.level == ProofConfidenceLevel.freshReturn ||
        anchorExtraction.anchors.any(
          (anchor) => anchor.type == EvidenceAnchorType.freshReturn,
        );
    final hasSolidStrongPatternWithSafeAnchors =
        entries.length >= solidPatternMinEntryCount &&
        hasSafeAnchor &&
        (matchQuality.confidenceBand == PatternMatchConfidenceBand.solid ||
            matchQuality.confidenceBand == PatternMatchConfidenceBand.strong);

    return ProBridgeTimingLoosenSignals(
      confidenceLevel: calibration.level,
      hasSafeAnchor: hasSafeAnchor,
      hasFreshReturnAfterCorrection: hasFreshReturnAfterCorrection,
      hasSolidStrongPatternWithSafeAnchors:
          hasSolidStrongPatternWithSafeAnchors,
    );
  }

  static ProBridgeVisibilityInput enrichVisibilityInput({
    required ProBridgeVisibilityInput base,
    required List<JournalEntry> entries,
    required bool beliefSurfaceVisible,
    List<String> beliefEvidencePhrases = const [],
    bool? hasBetaProofLiftVisible,
    bool? hasReturnAfterProofStrengthenedVisible,
  }) {
    final signals = resolveSignals(
      entries: entries,
      source: base.source,
      beliefSurfaceVisible: beliefSurfaceVisible,
      beliefEvidencePhrases: beliefEvidencePhrases,
    );
    return ProBridgeVisibilityInput(
      surface: base.surface,
      source: base.source,
      entryCount: base.entryCount,
      isPro: base.isPro,
      postProofProBridgeEnabled: base.postProofProBridgeEnabled,
      hasFirstProof: base.hasFirstProof,
      isRecording: base.isRecording,
      isZeroEntryState: base.isZeroEntryState,
      isFirstRecordingState: base.isFirstRecordingState,
      isPostSaveDegradedState: base.isPostSaveDegradedState,
      isDegradedTranscriptState: base.isDegradedTranscriptState,
      hasTimelineProofVisible: base.hasTimelineProofVisible,
      hasFirstProofPayoffVisible: base.hasFirstProofPayoffVisible,
      hasBetaTesterReportVisible: base.hasBetaTesterReportVisible,
      hasCorrectionMemoryVisible: base.hasCorrectionMemoryVisible,
      hasMonthlyPrivateReportPreviewVisible:
          base.hasMonthlyPrivateReportPreviewVisible,
      hasBetaProofLiftVisible:
          hasBetaProofLiftVisible ?? base.hasBetaProofLiftVisible,
      hasReturnAfterProofStrengthenedVisible:
          hasReturnAfterProofStrengthenedVisible ??
          base.hasReturnAfterProofStrengthenedVisible,
      feedbackState: base.feedbackState,
      whatChangedQuestionActive: base.whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: base.patternReviewInboxHasActiveItems,
      proSlotAvailable: base.proSlotAvailable,
      compact: base.compact,
      confidenceLevel: signals.confidenceLevel,
      hasSafeAnchor: signals.hasSafeAnchor,
      hasFreshReturnAfterCorrection: signals.hasFreshReturnAfterCorrection,
      hasSolidStrongPatternWithSafeAnchors:
          signals.hasSolidStrongPatternWithSafeAnchors,
      hasSeenFirstRepeat: base.hasSeenFirstRepeat,
      hasOpenedEvidenceTrail: base.hasOpenedEvidenceTrail,
    );
  }

  static ProMomentTimingTrigger? resolveTriggerForContext(
    ProMomentTimingContext context,
  ) => _resolveAllowedTrigger(fromTimingContext(context));

  static ProBridgeTimingLoosenBlockedReason? _resolveBlockedReason(
    ProBridgeTimingLoosenInput input,
  ) {
    if (input.isZeroEntryState || input.entryCount <= 0) {
      return ProBridgeTimingLoosenBlockedReason.beforeFirstSave;
    }
    if (input.isFirstRecordingState) {
      return ProBridgeTimingLoosenBlockedReason.beforeFirstSave;
    }
    if (input.entryCount < minEntryCount) {
      return ProBridgeTimingLoosenBlockedReason.beforeFirstProof;
    }
    if (!input.hasFirstProof) {
      return ProBridgeTimingLoosenBlockedReason.beforeFirstProof;
    }
    if (input.isRecording) {
      return ProBridgeTimingLoosenBlockedReason.recording;
    }
    if (input.isPostSaveDegradedState || input.isDegradedTranscriptState) {
      return ProBridgeTimingLoosenBlockedReason.postSaveDegraded;
    }
    if (input.feedbackState == ProofQualityFeedbackState.tooVague) {
      return ProBridgeTimingLoosenBlockedReason.feedbackTooVague;
    }
    if (input.feedbackState == ProofQualityFeedbackState.notRelevant) {
      return ProBridgeTimingLoosenBlockedReason.feedbackNotRelevant;
    }
    if (input.whatChangedQuestionActive) {
      return ProBridgeTimingLoosenBlockedReason.whatChangedActive;
    }
    if (input.patternReviewInboxHasActiveItems) {
      return ProBridgeTimingLoosenBlockedReason.patternReviewInboxActive;
    }
    if (!input.proSlotAvailable) {
      return ProBridgeTimingLoosenBlockedReason.proSlotAlreadyUsed;
    }
    return null;
  }

  static ProMomentTimingTrigger? _resolveAllowedTrigger(
    ProBridgeTimingLoosenInput input,
  ) {
    if (input.hasTimelineProofVisible) {
      return ProMomentTimingTrigger.timelineProofMoment;
    }
    if (input.hasFirstProofPayoffVisible) {
      return ProMomentTimingTrigger.firstProofPayoff;
    }
    if (input.hasBetaTesterReportVisible) {
      return ProMomentTimingTrigger.betaTesterReport;
    }
    if (input.hasMonthlyPrivateReportPreviewVisible) {
      return ProMomentTimingTrigger.monthlyPrivateReportPreview;
    }
    if (input.feedbackState == ProofQualityFeedbackState.useful) {
      return ProMomentTimingTrigger.usefulFeedback;
    }
    if (input.hasCorrectionMemoryVisible) {
      return ProMomentTimingTrigger.correctionImprovedTimeline;
    }
    if (input.hasBetaProofLiftVisible && _hasValidProofConfidence(input)) {
      return ProMomentTimingTrigger.betaProofLiftUnderValidProof;
    }
    if (input.hasReturnAfterProofStrengthenedVisible) {
      return ProMomentTimingTrigger.returnAfterProofStrengthened;
    }
    if (input.hasFreshReturnAfterCorrection) {
      return ProMomentTimingTrigger.freshReturnAfterCorrection;
    }
    if (input.confidenceLevel == ProofConfidenceLevel.strong &&
        _hasValidProofConfidence(input)) {
      return ProMomentTimingTrigger.strongProofConfidence;
    }
    if (input.confidenceLevel == ProofConfidenceLevel.useful ||
        input.confidenceLevel == ProofConfidenceLevel.freshReturn) {
      return ProMomentTimingTrigger.usefulProofConfidence;
    }
    if (input.hasSolidStrongPatternWithSafeAnchors) {
      return ProMomentTimingTrigger.solidStrongPatternWithSafeAnchors;
    }
    return null;
  }

  static bool _hasValidProofConfidence(ProBridgeTimingLoosenInput input) =>
      input.confidenceLevel == ProofConfidenceLevel.useful ||
      input.confidenceLevel == ProofConfidenceLevel.strong ||
      input.confidenceLevel == ProofConfidenceLevel.freshReturn;

  static ProBridgeVisibilitySurface _surfaceFromTiming(
    ProMomentTimingSurface surface,
  ) => switch (surface) {
    ProMomentTimingSurface.recordReady =>
      ProBridgeVisibilitySurface.recordReady,
    ProMomentTimingSurface.recordPostSave =>
      ProBridgeVisibilitySurface.recordPostSaveAfterPayoff,
    ProMomentTimingSurface.archivePatterns =>
      ProBridgeVisibilitySurface.archivePatterns,
    ProMomentTimingSurface.paywall => ProBridgeVisibilitySurface.recordReady,
  };
}

class ProBridgeTimingLoosenSignals {
  const ProBridgeTimingLoosenSignals({
    this.confidenceLevel,
    this.hasSafeAnchor = false,
    this.hasFreshReturnAfterCorrection = false,
    this.hasSolidStrongPatternWithSafeAnchors = false,
  });

  final ProofConfidenceLevel? confidenceLevel;
  final bool hasSafeAnchor;
  final bool hasFreshReturnAfterCorrection;
  final bool hasSolidStrongPatternWithSafeAnchors;
}

class ProBridgeTimingLoosenInput {
  const ProBridgeTimingLoosenInput({
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

  final ProBridgeVisibilitySurface surface;
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
}

enum ProBridgeTimingLoosenBlockedReason {
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

extension ProBridgeTimingLoosenBlockedReasonAnalytics
    on ProBridgeTimingLoosenBlockedReason {
  String get analyticsValue => switch (this) {
    ProBridgeTimingLoosenBlockedReason.beforeFirstSave => 'before_first_save',
    ProBridgeTimingLoosenBlockedReason.beforeFirstProof => 'before_first_proof',
    ProBridgeTimingLoosenBlockedReason.recording => 'recording',
    ProBridgeTimingLoosenBlockedReason.postSaveDegraded => 'post_save_degraded',
    ProBridgeTimingLoosenBlockedReason.feedbackTooVague => 'feedback_too_vague',
    ProBridgeTimingLoosenBlockedReason.feedbackNotRelevant =>
      'feedback_not_relevant',
    ProBridgeTimingLoosenBlockedReason.whatChangedActive =>
      'what_changed_active',
    ProBridgeTimingLoosenBlockedReason.patternReviewInboxActive =>
      'pattern_review_inbox_active',
    ProBridgeTimingLoosenBlockedReason.proSlotAlreadyUsed =>
      'pro_slot_already_used',
    ProBridgeTimingLoosenBlockedReason.noAllowedMoment => 'no_allowed_moment',
  };
}

class ProBridgeTimingLoosenResult {
  const ProBridgeTimingLoosenResult({
    required this.allowed,
    this.trigger,
    this.blockedReason,
    this.confidenceLevel,
    this.hasSafeAnchor = false,
  });

  factory ProBridgeTimingLoosenResult.allowed({
    required ProMomentTimingTrigger trigger,
    ProofConfidenceLevel? confidenceLevel,
    bool hasSafeAnchor = false,
  }) => ProBridgeTimingLoosenResult(
    allowed: true,
    trigger: trigger,
    confidenceLevel: confidenceLevel,
    hasSafeAnchor: hasSafeAnchor,
  );

  factory ProBridgeTimingLoosenResult.blocked({
    required ProBridgeTimingLoosenBlockedReason blockedReason,
    ProofConfidenceLevel? confidenceLevel,
    bool hasSafeAnchor = false,
  }) => ProBridgeTimingLoosenResult(
    allowed: false,
    blockedReason: blockedReason,
    confidenceLevel: confidenceLevel,
    hasSafeAnchor: hasSafeAnchor,
  );

  final bool allowed;
  final ProMomentTimingTrigger? trigger;
  final ProBridgeTimingLoosenBlockedReason? blockedReason;
  final ProofConfidenceLevel? confidenceLevel;
  final bool hasSafeAnchor;
}
