import '../../models/journal_entry.dart';
import '../first_session_proof_repair/first_session_proof_repair_model.dart';
import '../beta_decision/beta_decision_model.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import '../v1_interface/progressive_evidence_state_copy.dart';
import 'beta_improvement_model.dart';
import 'beta_improvement_recommendation_gate.dart';
import 'capture_friction_copy_fix.dart';
import 'proof_emotional_clarity_engine.dart';
import 'proof_emotional_clarity_model.dart';
import 'pro_packaging_branch_engine.dart';
import 'pro_packaging_copy_fix.dart';
import 'pro_utility_copy_fix.dart';
import 'record_onboarding_copy_fix.dart';
import 'return_reason_copy_fix.dart';

/// Applies gated beta improvement copy — one branch at a time.
abstract final class BetaImprovementPackEngine {
  BetaImprovementPackEngine._();

  static String recordTitle({
    required int entryCount,
    required String fallback,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (!BetaImprovementRecommendationGate.shouldApplyBranch(
      branch: BetaImprovementBranch.recordOnboardingCopy,
      entryCount: entryCount,
      hasMeaningfulProof: false,
      outcomesOverride: outcomesOverride,
    )) {
      return fallback;
    }
    return RecordOnboardingCopyFix.title;
  }

  static String recordBody({
    required int entryCount,
    required String fallback,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (!BetaImprovementRecommendationGate.shouldApplyBranch(
      branch: BetaImprovementBranch.recordOnboardingCopy,
      entryCount: entryCount,
      hasMeaningfulProof: false,
      outcomesOverride: outcomesOverride,
    )) {
      return fallback;
    }
    return RecordOnboardingCopyFix.body;
  }

  static String? recordLowEvidenceClarifier({
    required int entryCount,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (!BetaImprovementRecommendationGate.shouldApplyBranch(
      branch: BetaImprovementBranch.recordOnboardingCopy,
      entryCount: entryCount,
      hasMeaningfulProof: false,
      outcomesOverride: outcomesOverride,
    )) {
      return null;
    }
    return RecordOnboardingCopyFix.lowEvidenceClarifier;
  }

  static String? recordNotDiaryLine({
    required int entryCount,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (!BetaImprovementRecommendationGate.shouldApplyBranch(
      branch: BetaImprovementBranch.recordOnboardingCopy,
      entryCount: entryCount,
      hasMeaningfulProof: false,
      outcomesOverride: outcomesOverride,
    )) {
      return null;
    }
    return RecordOnboardingCopyFix.notADiaryLine;
  }

  static bool preferTypedCaptureFirst({
    required int entryCount,
    List<BetaTesterOutcome>? outcomesOverride,
  }) =>
      BetaImprovementRecommendationGate.shouldApplyBranch(
        branch: BetaImprovementBranch.captureFriction,
        entryCount: entryCount,
        hasMeaningfulProof: false,
        outcomesOverride: outcomesOverride,
      );

  static String typedCapturePrompt({required String fallback}) =>
      preferTypedCaptureFirst(entryCount: 0)
          ? CaptureFrictionCopyFix.typedCapturePrompt
          : fallback;

  static String typeInsteadLabel({required String fallback}) =>
      preferTypedCaptureFirst(entryCount: 0)
          ? CaptureFrictionCopyFix.typeInsteadLabel
          : fallback;

  static FirstSessionCaptureRepairResult? applyCaptureRepair({
    required FirstSessionCaptureRepairResult base,
  }) {
    if (!base.shouldShow || base.entryCount != 0) return null;
    if (!BetaImprovementRecommendationGate.shouldApplyBranch(
      branch: BetaImprovementBranch.captureFriction,
      entryCount: base.entryCount,
      hasMeaningfulProof: false,
    )) {
      return null;
    }
    return FirstSessionCaptureRepairResult(
      shouldShow: true,
      title: RecordOnboardingCopyFix.title,
      body: CaptureFrictionCopyFix.typedCapturePrompt,
      primaryCta: CaptureFrictionCopyFix.typeFirstPrimaryCta,
      secondaryCta: CaptureFrictionCopyFix.typeFirstSecondaryCta,
      microcopy: RecordOnboardingCopyFix.notADiaryLine,
      typedCapturePrompt: CaptureFrictionCopyFix.typedCapturePrompt,
      chips: CaptureFrictionCopyFix.compactChips(),
      entryCount: base.entryCount,
      source: base.source,
    );
  }

  static String postSaveReturnCue({
    required int entryCount,
    required String fallback,
  }) {
    if (!BetaImprovementRecommendationGate.shouldApplyBranch(
      branch: BetaImprovementBranch.returnReason,
      entryCount: entryCount,
      hasMeaningfulProof: false,
    )) {
      return fallback;
    }
    return ReturnReasonCopyFix.postSaveReturnCue;
  }

  static List<String>? returnThreeDayPlan({required int entryCount}) {
    if (!BetaImprovementRecommendationGate.shouldApplyBranch(
      branch: BetaImprovementBranch.returnReason,
      entryCount: entryCount,
      hasMeaningfulProof: false,
    )) {
      return null;
    }
    return ReturnReasonCopyFix.threeDayPlan;
  }

  static String? returnOptionalFraming({required int entryCount}) {
    if (!BetaImprovementRecommendationGate.shouldApplyBranch(
      branch: BetaImprovementBranch.returnReason,
      entryCount: entryCount,
      hasMeaningfulProof: false,
    )) {
      return null;
    }
    return '${ReturnReasonCopyFix.optionalFraming} ${ReturnReasonCopyFix.noStreakFraming}';
  }

  static ProofEmotionalClarityDisplay? proofEmotionalClarityDisplay({
    required List<JournalEntry> entries,
    required ProofConfidenceCalibrationResult calibration,
    required bool hasStrongEvidence,
    String? groundedPhrase,
    List<String>? snippetQuotes,
    List<BetaTesterOutcome>? outcomesOverride,
  }) =>
      ProofEmotionalClarityEngine.build(
        entries: entries,
        calibration: calibration,
        hasStrongEvidence: hasStrongEvidence,
        groundedPhrase: groundedPhrase,
        snippetQuotes: snippetQuotes,
        outcomesOverride: outcomesOverride,
      );

  static String firstProofHeadline({
    required int entryCount,
    required bool hasStrongEvidence,
    required String fallback,
    ProofEmotionalClarityDisplay? emotionalClarity,
  }) =>
      emotionalClarity?.headline ?? fallback;

  static String? firstProofWhyMattersLine({
    required int entryCount,
    required bool hasStrongEvidence,
    ProofEmotionalClarityDisplay? emotionalClarity,
  }) {
    if (emotionalClarity != null) {
      return emotionalClarity.whyItMightMatterBody ??
          emotionalClarity.subheadline;
    }
    return null;
  }

  static String? proBridgeLine({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (!BetaImprovementRecommendationGate.shouldApplyBranch(
      branch: BetaImprovementBranch.proPackaging,
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      outcomesOverride: outcomesOverride,
    )) {
      return null;
    }
    return ProPackagingCopyFix.proofBridge;
  }

  static String? proBridgeTitle({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
  }) =>
      ProPackagingBranchEngine.bridgeTitle(
        entryCount: entryCount,
        hasMeaningfulProof: hasMeaningfulProof,
        outcomesOverride: outcomesOverride,
      );

  static String? proBridgeBody({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
  }) =>
      ProPackagingBranchEngine.bridgeBody(
        entryCount: entryCount,
        hasMeaningfulProof: hasMeaningfulProof,
        outcomesOverride: outcomesOverride,
      );

  static List<String> firstProofProBridgeLines({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
  }) =>
      ProPackagingBranchEngine.firstProofBridgeLines(
        entryCount: entryCount,
        hasMeaningfulProof: hasMeaningfulProof,
        outcomesOverride: outcomesOverride,
      );

  static String? proFreeLine() =>
      BetaImprovementRecommendationGate.isBranchActive(
        BetaImprovementBranch.proPackaging,
      )
          ? ProPackagingCopyFix.freeLine
          : null;

  static String? proPaidLine() =>
      BetaImprovementRecommendationGate.isBranchActive(
        BetaImprovementBranch.proPackaging,
      )
          ? ProPackagingCopyFix.proLine
          : null;

  static String? paywallHeadline() => ProPackagingBranchEngine.paywallHeadline();

  static String? paywallSubheadline() =>
      ProPackagingBranchEngine.paywallSubheadline();

  static List<String>? paywallBullets() =>
      ProPackagingBranchEngine.paywallBullets();

  static List<String>? proUtilityPreviews({
    required int entryCount,
    required bool hasMeaningfulProof,
  }) {
    if (!BetaImprovementRecommendationGate.shouldApplyBranch(
      branch: BetaImprovementBranch.proUtility,
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
    )) {
      return null;
    }
    return [
      ProUtilityCopyFix.historyPreview,
      ProUtilityCopyFix.exportPreview,
      '${ProUtilityCopyFix.reportPreview} ${ProUtilityCopyFix.plannedSuffix}',
    ];
  }

  static String progressiveZeroBody() =>
      BetaImprovementRecommendationGate.isBranchActive(
        BetaImprovementBranch.recordOnboardingCopy,
      )
          ? RecordOnboardingCopyFix.body
          : ProgressiveEvidenceStateCopy.zeroBody;
}
