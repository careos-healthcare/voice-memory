import '../../models/journal_entry.dart';
import '../beta/archive_beta_mission_gate.dart';
import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../beta_proof_feedback/beta_proof_feedback_store.dart';
import '../first_session_proof_repair/first_session_proof_repair_engine.dart';
import '../pattern_match_quality/pattern_match_quality_engine.dart';
import '../pattern_match_quality/pattern_match_quality_model.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import '../revenue_readiness/revenue_readiness_dashboard_v2_model.dart';
import 'proof_floor_rescue_copy.dart';
import 'proof_floor_rescue_model.dart';

/// Controls cautious proof display and Pro blocking when proof is below floor.
abstract final class ProofFloorRescueEngine {
  ProofFloorRescueEngine._();

  static const usefulProofConcernThreshold =
      FirstSessionProofRepairEngine.usefulProofConcernThreshold;

  static ProofFloorRescueResult build({required ProofFloorRescueInput input}) {
    final state = resolveState(input);
    if (state == null) {
      return ProofFloorRescueResult.hidden;
    }
    return ProofFloorRescueResult(
      shouldShow: true,
      state: state,
      title: _titleFor(state),
      body: _bodyFor(state),
      primaryCta: _primaryCtaFor(state),
      secondaryCta: _secondaryCtaFor(state),
      showFeedbackOptions: state == ProofFloorRescueState.needsSpecificFeedback,
      source: input.source,
      entryCount: input.entryCount,
      confidenceLevel: input.confidenceLevel,
      surface: input.surface,
    );
  }

  static bool shouldShowCard({required ProofFloorRescueInput input}) {
    if (!ArchiveBetaMissionGate.isEnabled) return false;
    if (input.entryCount < 3) return false;
    if (!input.hasTimelineProofVisible && !input.hasConfirmedRepeat) {
      return false;
    }
    if (input.isRecording) return false;
    if (input.isDegradedTranscriptState) return false;
    if (input.whatChangedQuestionActive) return false;
    if (input.patternReviewInboxHasActiveItems) return false;
    return resolveState(input) != null;
  }

  static ProofFloorRescueState? resolveState(ProofFloorRescueInput input) {
    final feedback = input.latestFeedbackType;
    if (feedback == BetaProofFeedbackType.notRelevant) {
      return ProofFloorRescueState.suppressThread;
    }
    if (feedback == BetaProofFeedbackType.tooVague ||
        feedback == BetaProofFeedbackType.alreadyKnew) {
      return ProofFloorRescueState.sharpenNextReturn;
    }
    if (_shouldWaitForClearerEvidence(input)) {
      return ProofFloorRescueState.waitForClearerEvidence;
    }
    if (_proofExists(input) &&
        !input.feedbackAnsweredToday &&
        _isProofFloorAtRisk(input)) {
      return ProofFloorRescueState.needsSpecificFeedback;
    }
    return null;
  }

  static bool blocksProMonetization(ProofFloorRescueInput input) {
    if (!ArchiveBetaMissionGate.isEnabled) return false;
    if (input.isPro) return false;
    if (input.entryCount < 3) return false;
    if (isProofSafeForMonetization(input)) return false;
    return _isProofFloorAtRisk(input);
  }

  static bool shouldSuppressStrongProofPayoff(ProofFloorRescueInput input) {
    if (!ArchiveBetaMissionGate.isEnabled) return false;
    if (isProofSafeForMonetization(input)) return false;
    return _isProofFloorAtRisk(input);
  }

  static bool isProofSafeForMonetization(ProofFloorRescueInput input) =>
      _isStrongUsefulProof(input);

  static ProofFloorRescueRepairFocus? resolveRepairFocus(
    RevenueReadinessDashboardV2Input input,
  ) {
    if (input.usefulCount < usefulProofConcernThreshold) {
      return const ProofFloorRescueRepairFocus(
        focus: ProofFloorRescueRepairFocusId.protectProofFloor,
        title: ProofFloorRescueCopy.dashboardFocusTitle,
        body: ProofFloorRescueCopy.dashboardFocusBody,
        label: ProofFloorRescueCopy.dashboardFocusLabel,
      );
    }
    return null;
  }

  static bool resolveHasLowMatchQuality({
    required List<JournalEntry> entries,
    required bool beliefSurfaceVisible,
    required String source,
    List<String> beliefEvidencePhrases = const [],
  }) {
    final result = PatternMatchQualityEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      source: source,
      beliefEvidencePhrases: beliefEvidencePhrases,
    );
    if (!result.shouldResolve) return true;
    return result.confidenceBand == PatternMatchConfidenceBand.weak ||
        result.confidenceBand == PatternMatchConfidenceBand.emerging;
  }

  static ProofFloorRescueInput inputFromStore({
    required int entryCount,
    required String source,
    required bool isPro,
    required bool hasTimelineProofVisible,
    required bool hasConfirmedRepeat,
    required ProofConfidenceLevel confidenceLevel,
    required bool hasSafeAnchor,
    required bool hasLowMatchQuality,
    required bool isRecording,
    required bool isDegradedTranscriptState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    BetaProofFeedbackSurface surface =
        BetaProofFeedbackSurface.timelineProofMoment,
  }) {
    final counts = FirstSessionProofRepairEngine.feedbackCountsFromStore();
    final record = BetaProofFeedbackStore.recordFor(surface);
    return ProofFloorRescueInput(
      entryCount: entryCount,
      source: source,
      isPro: isPro,
      hasTimelineProofVisible: hasTimelineProofVisible,
      hasConfirmedRepeat: hasConfirmedRepeat,
      confidenceLevel: confidenceLevel,
      hasSafeAnchor: hasSafeAnchor,
      hasLowMatchQuality: hasLowMatchQuality,
      usefulFeedbackCount: counts.useful,
      latestFeedbackType: record.feedbackType,
      feedbackAnsweredToday: BetaProofFeedbackStore.isAnsweredToday(surface),
      isRecording: isRecording,
      isDegradedTranscriptState: isDegradedTranscriptState,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      surface: surface,
    );
  }

  static String proBlockStatusLabel({required bool blocked}) => blocked
      ? ProofFloorRescueCopy.statusProBlocked
      : ProofFloorRescueCopy.statusProAllowed;

  static String proofSafeStatusLabel({required bool safe}) => safe
      ? ProofFloorRescueCopy.statusProofSafe
      : ProofFloorRescueCopy.statusProofNotSafe;

  static String stateStatusLabel(ProofFloorRescueState? state) =>
      state == null ? 'inactive' : ProofFloorRescueCopy.stateLabel(state);

  static bool _proofExists(ProofFloorRescueInput input) =>
      input.hasTimelineProofVisible || input.hasConfirmedRepeat;

  static bool _shouldWaitForClearerEvidence(ProofFloorRescueInput input) {
    if (!_isProofFloorAtRisk(input)) return false;
    return _isWeakConfidence(input.confidenceLevel) ||
        !input.hasSafeAnchor ||
        input.hasLowMatchQuality;
  }

  static bool _isProofFloorAtRisk(ProofFloorRescueInput input) {
    if (input.usefulFeedbackCount < usefulProofConcernThreshold) return true;
    if (_isWeakConfidence(input.confidenceLevel)) return true;
    if (_isNegativeFeedback(input.latestFeedbackType)) return true;
    return false;
  }

  static bool _isStrongUsefulProof(ProofFloorRescueInput input) {
    return input.latestFeedbackType == BetaProofFeedbackType.useful &&
        _isProofLevel(input.confidenceLevel) &&
        input.hasSafeAnchor &&
        !input.hasLowMatchQuality &&
        input.usefulFeedbackCount >= 1;
  }

  static bool _isProofLevel(ProofConfidenceLevel level) =>
      level == ProofConfidenceLevel.useful ||
      level == ProofConfidenceLevel.strong ||
      level == ProofConfidenceLevel.freshReturn;

  static bool _isWeakConfidence(ProofConfidenceLevel level) =>
      level == ProofConfidenceLevel.watchOnly ||
      level == ProofConfidenceLevel.emerging;

  static bool _isNegativeFeedback(BetaProofFeedbackType? type) =>
      type == BetaProofFeedbackType.tooVague ||
      type == BetaProofFeedbackType.notRelevant;

  static String _titleFor(ProofFloorRescueState state) => switch (state) {
    ProofFloorRescueState.waitForClearerEvidence =>
      ProofFloorRescueCopy.waitTitle,
    ProofFloorRescueState.needsSpecificFeedback =>
      ProofFloorRescueCopy.feedbackTitle,
    ProofFloorRescueState.sharpenNextReturn =>
      ProofFloorRescueCopy.sharpenTitle,
    ProofFloorRescueState.suppressThread => ProofFloorRescueCopy.suppressTitle,
  };

  static String _bodyFor(ProofFloorRescueState state) => switch (state) {
    ProofFloorRescueState.waitForClearerEvidence =>
      ProofFloorRescueCopy.waitBody,
    ProofFloorRescueState.needsSpecificFeedback =>
      ProofFloorRescueCopy.feedbackBody,
    ProofFloorRescueState.sharpenNextReturn => ProofFloorRescueCopy.sharpenBody,
    ProofFloorRescueState.suppressThread => ProofFloorRescueCopy.suppressBody,
  };

  static String _primaryCtaFor(ProofFloorRescueState state) => switch (state) {
    ProofFloorRescueState.waitForClearerEvidence =>
      ProofFloorRescueCopy.waitPrimaryCta,
    ProofFloorRescueState.needsSpecificFeedback => '',
    ProofFloorRescueState.sharpenNextReturn =>
      ProofFloorRescueCopy.sharpenPrimaryCta,
    ProofFloorRescueState.suppressThread =>
      ProofFloorRescueCopy.suppressPrimaryCta,
  };

  static String? _secondaryCtaFor(ProofFloorRescueState state) =>
      switch (state) {
        ProofFloorRescueState.waitForClearerEvidence =>
          ProofFloorRescueCopy.waitSecondaryCta,
        ProofFloorRescueState.needsSpecificFeedback => null,
        ProofFloorRescueState.sharpenNextReturn =>
          ProofFloorRescueCopy.sharpenSecondaryCta,
        ProofFloorRescueState.suppressThread => null,
      };
}
