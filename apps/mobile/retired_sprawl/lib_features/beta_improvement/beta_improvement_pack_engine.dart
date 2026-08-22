import 'package:archiveme_mobile/features/beta_decision/beta_decision_model.dart';
import 'package:archiveme_mobile/features/beta_improvement/beta_improvement_model.dart';
import 'package:archiveme_mobile/features/beta_improvement/beta_improvement_recommendation_gate.dart';
import 'package:archiveme_mobile/features/beta_improvement/capture_friction_copy_fix.dart';
import 'package:archiveme_mobile/features/beta_improvement/pro_packaging_branch_engine.dart';
import 'package:archiveme_mobile/features/beta_improvement/pro_packaging_copy_fix.dart';
import 'package:archiveme_mobile/features/beta_improvement/pro_utility_boundary_model.dart';
import 'package:archiveme_mobile/features/beta_improvement/pro_utility_branch_engine.dart';
import 'package:archiveme_mobile/features/beta_improvement/pro_utility_copy_fix.dart';
import 'package:archiveme_mobile/features/beta_improvement/proof_emotional_clarity_engine.dart';
import 'package:archiveme_mobile/features/beta_improvement/proof_emotional_clarity_model.dart';
import 'package:archiveme_mobile/features/beta_improvement/proof_to_pro_path_engine.dart';
import 'package:archiveme_mobile/features/beta_improvement/proof_to_pro_path_model.dart';
import 'package:archiveme_mobile/features/beta_improvement/record_onboarding_copy_fix.dart';
import 'package:archiveme_mobile/features/beta_improvement/return_reason_copy_fix.dart';
import 'package:archiveme_mobile/features/first_session_proof_repair/first_session_proof_repair_model.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/features/v1_interface/progressive_evidence_state_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

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
  }) => BetaImprovementRecommendationGate.shouldApplyBranch(
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
  }) => ProofEmotionalClarityEngine.build(
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
  }) => emotionalClarity?.headline ?? fallback;

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
    if (ProUtilityBranchEngine.shouldShowBridge(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      outcomesOverride: outcomesOverride,
    )) {
      return ProUtilityCopyFix.proofBridge;
    }

    if (!ProofToProPathEngine.shouldShowProPackagingBridge(
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
  }) {
    final utilityTitle = ProUtilityBranchEngine.bridgeTitle(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      outcomesOverride: outcomesOverride,
    );
    if (utilityTitle != null) return utilityTitle;

    return ProPackagingBranchEngine.bridgeTitle(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      outcomesOverride: outcomesOverride,
    );
  }

  static String? proBridgeBody({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    final utilityBody = ProUtilityBranchEngine.bridgeBody(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      outcomesOverride: outcomesOverride,
    );
    if (utilityBody != null) return utilityBody;

    return ProPackagingBranchEngine.bridgeBody(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      outcomesOverride: outcomesOverride,
    );
  }

  static List<String> firstProofProBridgeLines({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    final utilityLines = ProUtilityBranchEngine.firstProofBridgeLines(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      outcomesOverride: outcomesOverride,
    );
    if (utilityLines.isNotEmpty) return utilityLines;

    return ProPackagingBranchEngine.firstProofBridgeLines(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      outcomesOverride: outcomesOverride,
    );
  }

  static ProUtilityBoundaryModel? proUtilityBoundary({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    final model = ProUtilityBranchEngine.build(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      outcomesOverride: outcomesOverride,
    );
    if (!model.shouldShowSection) return null;
    return model;
  }

  static List<ProUtilityRow>? proUtilityRows({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    final rows = ProUtilityBranchEngine.utilityRows(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      outcomesOverride: outcomesOverride,
    );
    if (rows.isEmpty) return null;
    return rows;
  }

  static String? proFreeLine() => ProofToProPathEngine.allowsProPackaging()
      ? ProPackagingCopyFix.freeLine
      : null;

  static String? proPaidLine() => ProofToProPathEngine.allowsProPackaging()
      ? ProPackagingCopyFix.proLine
      : null;

  static ProofToProPathModel proofToProPath({
    required int entryCount,
    required bool hasMeaningfulProof,
    bool proofClarityRenderable = false,
    bool firstProofPayoffVisible = false,
    List<BetaTesterOutcome>? outcomesOverride,
  }) => ProofToProPathEngine.build(
    entryCount: entryCount,
    hasMeaningfulProof: hasMeaningfulProof,
    proofClarityRenderable: proofClarityRenderable,
    firstProofPayoffVisible: firstProofPayoffVisible,
    outcomesOverride: outcomesOverride,
  );

  static String? paywallHeadline() =>
      ProPackagingBranchEngine.paywallHeadline();

  static String? paywallSubheadline() =>
      ProPackagingBranchEngine.paywallSubheadline();

  static List<String>? paywallBullets() =>
      ProPackagingBranchEngine.paywallBullets();

  static List<String>? proUtilityPreviews({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    final rows = proUtilityRows(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      outcomesOverride: outcomesOverride,
    );
    if (rows == null) return null;
    return rows.map((row) => '${row.title}: ${row.body}').toList();
  }

  static String progressiveZeroBody() =>
      BetaImprovementRecommendationGate.isBranchActive(
        BetaImprovementBranch.recordOnboardingCopy,
      )
      ? RecordOnboardingCopyFix.body
      : ProgressiveEvidenceStateCopy.zeroBody;
}