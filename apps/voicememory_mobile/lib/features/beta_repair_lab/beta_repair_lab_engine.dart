import '../beta/archive_beta_mission_gate.dart';
import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../first_session_proof_repair/first_session_proof_repair_model.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import '../pro_understanding_lift/pro_understanding_lift_model.dart';
import 'beta_repair_lab_copy.dart';
import 'beta_repair_lab_model.dart';
import 'beta_repair_lab_store.dart';

/// Applies beta/testing-only repair overrides when a mode is explicitly selected.
abstract final class BetaRepairLabEngine {
  BetaRepairLabEngine._();

  static bool shouldShowLab({required bool betaMissionEnabled}) =>
      betaMissionEnabled && ArchiveBetaMissionGate.isEnabled;

  static bool isRepairActive(BetaRepairLabMode mode) =>
      BetaRepairLabStore.activeMode == mode;

  static BetaRepairLabState currentState() {
    final active = BetaRepairLabStore.activeMode;
    final buildActive = BetaRepairLabStore.isBuildOverrideActive;
    return BetaRepairLabState(
      mode: active,
      localMode: BetaRepairLabStore.localMode,
      activeModeLabel: BetaRepairLabCopy.modeLabel(active),
      buildOverrideActive: buildActive,
      buildOverrideLabel: BetaRepairLabStore.buildOverrideActiveLabel,
      warning: buildActive
          ? BetaRepairLabCopy.buildOverrideWarning
          : BetaRepairLabCopy.warning,
    );
  }

  static Iterable<BetaRepairLabModeInfo> allModeInfos() sync* {
    for (final mode in BetaRepairLabMode.values) {
      yield BetaRepairLabModeInfo(
        mode: mode,
        label: BetaRepairLabCopy.modeLabel(mode),
        fixes: BetaRepairLabCopy.modeFixes(mode),
        whenToUse: BetaRepairLabCopy.modeWhenToUse(mode),
        changes: BetaRepairLabCopy.modeChanges(mode),
        doNotTouch: BetaRepairLabCopy.modeDoNotTouch(mode),
      );
    }
  }

  static FirstSessionCaptureRepairResult? openingCaptureOverride({
    required FirstSessionCaptureRepairResult base,
    required bool betaMissionEnabled,
  }) {
    if (!shouldShowLab(betaMissionEnabled: betaMissionEnabled)) return null;
    if (!isRepairActive(BetaRepairLabMode.openingScreenSimplification)) {
      return null;
    }
    if (base.entryCount != 0 || !base.shouldShow) return null;
    return FirstSessionCaptureRepairResult(
      shouldShow: true,
      title: BetaRepairLabCopy.openingTitle,
      body: BetaRepairLabCopy.openingBody,
      primaryCta: BetaRepairLabCopy.openingPrimaryCta,
      secondaryCta: BetaRepairLabCopy.openingSecondaryCta,
      microcopy: BetaRepairLabCopy.openingMicrocopy,
      typedCapturePrompt: 'One moment from today was...',
      chips: [
        FirstSessionProofRepairChip(
          id: FirstSessionProofRepairChipId.keptCheckingAgain,
          text: BetaRepairLabCopy.chipCheckedAgain,
        ),
        FirstSessionProofRepairChip(
          id: FirstSessionProofRepairChipId.avoidedReplying,
          text: BetaRepairLabCopy.chipAvoidedIt,
        ),
        FirstSessionProofRepairChip(
          id: FirstSessionProofRepairChipId.wantedControl,
          text: BetaRepairLabCopy.chipWantedControl,
        ),
        FirstSessionProofRepairChip(
          id: FirstSessionProofRepairChipId.feltFamiliar,
          text: BetaRepairLabCopy.chipFeltFamiliar,
        ),
      ],
      entryCount: base.entryCount,
      source: base.source,
    );
  }

  static bool suppressFirstSessionLiftWhenOpeningRepairActive({
    required bool betaMissionEnabled,
    required bool showOpeningRepair,
  }) {
    if (!showOpeningRepair) return false;
    if (!shouldShowLab(betaMissionEnabled: betaMissionEnabled)) return false;
    return isRepairActive(BetaRepairLabMode.openingScreenSimplification);
  }

  static BetaRepairLabProofResult buildProof({
    required BetaRepairLabVisibilityInput input,
  }) {
    if (!shouldShowLab(betaMissionEnabled: input.betaMissionEnabled)) {
      return BetaRepairLabProofResult.hidden;
    }
    if (!isRepairActive(BetaRepairLabMode.proofSpecificityCaution)) {
      return BetaRepairLabProofResult.hidden;
    }
    if (!shouldShowProof(input: input)) {
      return BetaRepairLabProofResult.hidden;
    }
    final variant = _resolveProofVariant(input);
    return BetaRepairLabProofResult(
      shouldShow: true,
      variant: variant,
      title: variant == BetaRepairLabProofVariant.weak
          ? BetaRepairLabCopy.proofWeakTitle
          : BetaRepairLabCopy.proofStrongTitle,
      body: variant == BetaRepairLabProofVariant.weak
          ? BetaRepairLabCopy.proofWeakBody
          : BetaRepairLabCopy.proofStrongBody,
      feedbackPrompt: BetaRepairLabCopy.proofFeedbackPrompt,
      source: input.source,
      entryCount: input.entryCount,
    );
  }

  static bool shouldShowProof({required BetaRepairLabVisibilityInput input}) {
    if (!shouldShowLab(betaMissionEnabled: input.betaMissionEnabled)) {
      return false;
    }
    if (!isRepairActive(BetaRepairLabMode.proofSpecificityCaution)) {
      return false;
    }
    if (input.entryCount < 3) return false;
    if (!input.hasTimelineProofVisible && !input.hasConfirmedRepeat) {
      return false;
    }
    if (input.isRecording) return false;
    if (input.isDegradedTranscriptState) return false;
    if (input.whatChangedQuestionActive) return false;
    if (input.patternReviewInboxHasActiveItems) return false;
    return true;
  }

  static bool suppressProofFloorRescueWhenProofRepairActive({
    required bool betaMissionEnabled,
    required bool showProofRepair,
  }) {
    if (!showProofRepair) return false;
    if (!shouldShowLab(betaMissionEnabled: betaMissionEnabled)) return false;
    return isRepairActive(BetaRepairLabMode.proofSpecificityCaution);
  }

  static bool blocksProWhenProofRepairActive({
    required BetaRepairLabVisibilityInput input,
    required bool showProofRepair,
  }) {
    if (!showProofRepair) return false;
    if (!shouldShowLab(betaMissionEnabled: input.betaMissionEnabled)) {
      return false;
    }
    if (!isRepairActive(BetaRepairLabMode.proofSpecificityCaution)) {
      return false;
    }
    if (_resolveProofVariant(input) == BetaRepairLabProofVariant.weak) {
      return true;
    }
    return input.isNegativeFeedback;
  }

  static BetaRepairLabProPlacementResult buildProPlacement({
    required BetaRepairLabVisibilityInput input,
  }) {
    if (!shouldShowLab(betaMissionEnabled: input.betaMissionEnabled)) {
      return BetaRepairLabProPlacementResult.hidden;
    }
    if (!isRepairActive(BetaRepairLabMode.proPlacementAfterUsefulProof)) {
      return BetaRepairLabProPlacementResult.hidden;
    }
    if (!shouldShowProPlacement(input: input)) {
      return BetaRepairLabProPlacementResult.hidden;
    }
    return BetaRepairLabProPlacementResult(
      shouldShow: true,
      title: BetaRepairLabCopy.proPlacementTitle,
      body: BetaRepairLabCopy.proPlacementBody,
      primaryCta: BetaRepairLabCopy.proPlacementPrimaryCta,
      secondaryCta: BetaRepairLabCopy.proPlacementSecondaryCta,
      source: input.source,
      entryCount: input.entryCount,
    );
  }

  static bool shouldShowProPlacement({
    required BetaRepairLabVisibilityInput input,
  }) {
    if (!shouldShowLab(betaMissionEnabled: input.betaMissionEnabled)) {
      return false;
    }
    if (!isRepairActive(BetaRepairLabMode.proPlacementAfterUsefulProof)) {
      return false;
    }
    if (input.isPro) return false;
    if (input.entryCount < 3) return false;
    if (!input.hasTimelineProofVisible && !input.hasConfirmedRepeat) {
      return false;
    }
    if (!_isStrongUsefulProof(input)) return false;
    if (input.feedbackType == BetaProofFeedbackType.tooVague ||
        input.feedbackType == BetaProofFeedbackType.notRelevant) {
      return false;
    }
    if (input.isRecording) return false;
    if (input.isDegradedTranscriptState) return false;
    if (input.whatChangedQuestionActive) return false;
    if (input.patternReviewInboxHasActiveItems) return false;
    return true;
  }

  static bool blocksOtherProCardsWhenPlacementRepairActive({
    required bool betaMissionEnabled,
    required bool showProPlacement,
  }) {
    if (!showProPlacement) return false;
    if (!shouldShowLab(betaMissionEnabled: betaMissionEnabled)) return false;
    return isRepairActive(BetaRepairLabMode.proPlacementAfterUsefulProof);
  }

  static ProUnderstandingLiftResult? applyProExplanationCopy({
    required ProUnderstandingLiftResult base,
    required bool betaMissionEnabled,
  }) {
    if (!base.shouldShow) return null;
    if (!shouldShowLab(betaMissionEnabled: betaMissionEnabled)) return null;
    if (!isRepairActive(BetaRepairLabMode.proExplanation)) return null;
    return ProUnderstandingLiftResult(
      shouldShow: true,
      title: BetaRepairLabCopy.proExplanationTitle,
      body: BetaRepairLabCopy.proExplanationBody,
      bullets: [
        BetaRepairLabCopy.proExplanationBulletFree,
        BetaRepairLabCopy.proExplanationBulletPro,
        BetaRepairLabCopy.proExplanationBulletControl,
      ],
      supportLine: BetaRepairLabCopy.proExplanationSupport,
      primaryCta: BetaRepairLabCopy.proExplanationPrimaryCta,
      secondaryCta: base.secondaryCta,
      source: base.source,
      surface: base.surface,
      entryCount: base.entryCount,
      hasUsefulProof: base.hasUsefulProof,
      hasPaywallSeen: base.hasPaywallSeen,
    );
  }

  static bool isRepairLabOpeningCapture(
    FirstSessionCaptureRepairResult result,
  ) =>
      result.title == BetaRepairLabCopy.openingTitle &&
      result.primaryCta == BetaRepairLabCopy.openingPrimaryCta;

  static bool isRepairLabProExplanation(ProUnderstandingLiftResult result) =>
      result.title == BetaRepairLabCopy.proExplanationTitle &&
      result.primaryCta == BetaRepairLabCopy.proExplanationPrimaryCta;

  static String activeModeStatusLabel() =>
      'Active repair: ${BetaRepairLabCopy.modeLabel(BetaRepairLabStore.activeMode)}';

  static String? buildOverrideStatusLabel() =>
      BetaRepairLabStore.buildOverrideActiveLabel;

  static BetaRepairLabProofVariant _resolveProofVariant(
    BetaRepairLabVisibilityInput input,
  ) {
    if (_isStrongUsefulProof(input)) {
      return BetaRepairLabProofVariant.strong;
    }
    return BetaRepairLabProofVariant.weak;
  }

  static bool _isStrongUsefulProof(BetaRepairLabVisibilityInput input) {
    if (input.feedbackType == BetaProofFeedbackType.useful) return true;
    return input.confidenceLevel == ProofConfidenceLevel.useful ||
        input.confidenceLevel == ProofConfidenceLevel.strong ||
        input.confidenceLevel == ProofConfidenceLevel.freshReturn;
  }
}
