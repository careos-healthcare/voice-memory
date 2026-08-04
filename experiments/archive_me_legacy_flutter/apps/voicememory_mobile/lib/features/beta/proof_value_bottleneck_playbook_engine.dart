import 'beta_activation_loop_counts.dart';
import 'proof_of_value_copy.dart';
import 'proof_of_value_engine.dart';
import 'proof_of_value_model.dart';
import 'proof_value_bottleneck_playbook_copy.dart';
import 'proof_value_bottleneck_playbook_model.dart';

/// Maps Proof of Value recommendations to a constrained fix playbook.
abstract final class ProofValueBottleneckPlaybookEngine {
  ProofValueBottleneckPlaybookEngine._();

  static ProofValueBottleneckPlaybookReport build({
    required ProofOfValueReport proofReport,
  }) {
    final id = _idForRecommendation(proofReport.recommendation);
    final entry = _entryFor(id);

    return ProofValueBottleneckPlaybookReport(
      title: ProofValueBottleneckPlaybookCopy.cardTitle,
      subtitle: ProofValueBottleneckPlaybookCopy.cardSubtitle,
      activeRecommendation: proofReport.recommendation,
      entry: entry,
    );
  }

  static ProofValueBottleneckPlaybookReport fromBetaCounts({
    BetaActivationLoopCounts? betaCounts,
    int? totalTesters,
    int? coreValueYes,
    int? coreValueNotYet,
    int? coreValueGeneric,
    int? proofFeltSpecific,
    int? proofUsefulCount,
    int? wouldKeepUsing,
    int? wouldPay,
    String? localCoreValueAnswerLabel,
  }) {
    final proofReport = ProofOfValueEngine.build(
      input: ProofOfValueEngine.fromBetaCounts(
        betaCounts: betaCounts,
        totalTesters: totalTesters,
        coreValueYes: coreValueYes,
        coreValueNotYet: coreValueNotYet,
        coreValueGeneric: coreValueGeneric,
        proofFeltSpecific: proofFeltSpecific,
        proofUsefulCount: proofUsefulCount,
        wouldKeepUsing: wouldKeepUsing,
        wouldPay: wouldPay,
        localCoreValueAnswerLabel: localCoreValueAnswerLabel,
      ),
    );
    return build(proofReport: proofReport);
  }

  static ProofValueBottleneckPlaybookId _idForRecommendation(
    String recommendation,
  ) => switch (recommendation) {
    ProofOfValueCopy.recommendationRunMoreTesters =>
      ProofValueBottleneckPlaybookId.runMoreTesters,
    ProofOfValueCopy.recommendationFixFirstUse =>
      ProofValueBottleneckPlaybookId.fixFirstUse,
    ProofOfValueCopy.recommendationFixReturnLoop =>
      ProofValueBottleneckPlaybookId.fixReturnLoop,
    ProofOfValueCopy.recommendationFixFirstProof =>
      ProofValueBottleneckPlaybookId.fixFirstProof,
    ProofOfValueCopy.recommendationFixEvidence =>
      ProofValueBottleneckPlaybookId.fixEvidence,
    ProofOfValueCopy.recommendationStrengthenRetention =>
      ProofValueBottleneckPlaybookId.strengthenRetention,
    ProofOfValueCopy.recommendationStrengthenPro =>
      ProofValueBottleneckPlaybookId.strengthenPro,
    ProofOfValueCopy.recommendationWidenBeta =>
      ProofValueBottleneckPlaybookId.widenBeta,
    _ => ProofValueBottleneckPlaybookId.runMoreTesters,
  };

  static ProofValueBottleneckPlaybookEntry _entryFor(
    ProofValueBottleneckPlaybookId id,
  ) => switch (id) {
    ProofValueBottleneckPlaybookId.runMoreTesters =>
      ProofValueBottleneckPlaybookEntry(
        id: id,
        summaryLine: ProofOfValueCopy.recommendationRunMoreTesters,
        meaning: ProofValueBottleneckPlaybookCopy.runMoreTestersMeaning,
        fixArea: ProofValueBottleneckPlaybookCopy.runMoreTestersFixArea,
        inspectSurfaces: const [
          ProofValueBottleneckPlaybookCopy
              .runMoreTestersInspectBetaReportExport,
          ProofValueBottleneckPlaybookCopy.runMoreTestersInspectProofOfValue,
          ProofValueBottleneckPlaybookCopy
              .runMoreTestersInspectActivationDropoff,
        ],
        guardrail: ProofValueBottleneckPlaybookCopy.runMoreTestersGuardrail,
        suggestedTestFiles: const [
          ProofValueBottleneckPlaybookCopy
              .runMoreTestersTestReleaseCandidateSmoke,
          ProofValueBottleneckPlaybookCopy.runMoreTestersTestBetaReportExport,
          ProofValueBottleneckPlaybookCopy.runMoreTestersTestProofOfValue,
        ],
      ),
    ProofValueBottleneckPlaybookId.fixFirstUse =>
      ProofValueBottleneckPlaybookEntry(
        id: id,
        summaryLine: ProofOfValueCopy.recommendationFixFirstUse,
        meaning: ProofValueBottleneckPlaybookCopy.fixFirstUseMeaning,
        fixArea: ProofValueBottleneckPlaybookCopy.fixFirstUseFixArea,
        inspectSurfaces: const [
          ProofValueBottleneckPlaybookCopy.fixFirstUseInspectRecordCapture,
          ProofValueBottleneckPlaybookCopy.fixFirstUseInspectJourneyExplainer,
          ProofValueBottleneckPlaybookCopy.fixFirstUseInspectSaveCta,
          ProofValueBottleneckPlaybookCopy.fixFirstUseInspectMicCopy,
          ProofValueBottleneckPlaybookCopy.fixFirstUseInspectEmptyState,
        ],
        guardrail: ProofValueBottleneckPlaybookCopy.fixFirstUseGuardrail,
        suggestedTestFiles: const [
          ProofValueBottleneckPlaybookCopy.fixFirstUseTestRecordFraming,
          ProofValueBottleneckPlaybookCopy.fixFirstUseTestJourneyExplainer,
          ProofValueBottleneckPlaybookCopy.fixFirstUseTestTrustReliability,
        ],
      ),
    ProofValueBottleneckPlaybookId.fixReturnLoop =>
      ProofValueBottleneckPlaybookEntry(
        id: id,
        summaryLine: ProofOfValueCopy.recommendationFixReturnLoop,
        meaning: ProofValueBottleneckPlaybookCopy.fixReturnLoopMeaning,
        fixArea: ProofValueBottleneckPlaybookCopy.fixReturnLoopFixArea,
        inspectSurfaces: const [
          ProofValueBottleneckPlaybookCopy.fixReturnLoopInspectPostSaveHandoff,
          ProofValueBottleneckPlaybookCopy.fixReturnLoopInspectEarlyRepeat,
          ProofValueBottleneckPlaybookCopy
              .fixReturnLoopInspectTesterMissionEntry1,
          ProofValueBottleneckPlaybookCopy.fixReturnLoopInspectFirstWeekLoop,
        ],
        guardrail: ProofValueBottleneckPlaybookCopy.fixReturnLoopGuardrail,
        suggestedTestFiles: const [
          ProofValueBottleneckPlaybookCopy.fixReturnLoopTestEarlyRepeat,
          ProofValueBottleneckPlaybookCopy.fixReturnLoopTestTesterMission,
          ProofValueBottleneckPlaybookCopy.fixReturnLoopTestFirstWeekLoop,
          ProofValueBottleneckPlaybookCopy.fixReturnLoopTestRecordFraming,
        ],
      ),
    ProofValueBottleneckPlaybookId.fixFirstProof =>
      ProofValueBottleneckPlaybookEntry(
        id: id,
        summaryLine: ProofOfValueCopy.recommendationFixFirstProof,
        meaning: ProofValueBottleneckPlaybookCopy.fixFirstProofMeaning,
        fixArea: ProofValueBottleneckPlaybookCopy.fixFirstProofFixArea,
        inspectSurfaces: const [
          ProofValueBottleneckPlaybookCopy.fixFirstProofInspectTesterMission,
          ProofValueBottleneckPlaybookCopy.fixFirstProofInspectEntryProgress,
          ProofValueBottleneckPlaybookCopy.fixFirstProofInspectConfirmedRepeat,
          ProofValueBottleneckPlaybookCopy.fixFirstProofInspectFirstProofGates,
        ],
        guardrail: ProofValueBottleneckPlaybookCopy.fixFirstProofGuardrail,
        suggestedTestFiles: const [
          ProofValueBottleneckPlaybookCopy.fixFirstProofTestFirstThreeSession,
          ProofValueBottleneckPlaybookCopy
              .fixFirstProofTestConfirmedRepeatPhrase,
          ProofValueBottleneckPlaybookCopy.fixFirstProofTestTesterMission,
          ProofValueBottleneckPlaybookCopy.fixFirstProofTestProofCopyDedup,
        ],
      ),
    ProofValueBottleneckPlaybookId.fixEvidence =>
      ProofValueBottleneckPlaybookEntry(
        id: id,
        summaryLine: ProofOfValueCopy.recommendationFixEvidence,
        meaning: ProofValueBottleneckPlaybookCopy.fixEvidenceMeaning,
        fixArea: ProofValueBottleneckPlaybookCopy.fixEvidenceFixArea,
        inspectSurfaces: const [
          ProofValueBottleneckPlaybookCopy.fixEvidenceInspectPhraseEngine,
          ProofValueBottleneckPlaybookCopy.fixEvidenceInspectFirstProofCopy,
          ProofValueBottleneckPlaybookCopy.fixEvidenceInspectCurrentBelief,
          ProofValueBottleneckPlaybookCopy.fixEvidenceInspectBeliefChips,
        ],
        guardrail: ProofValueBottleneckPlaybookCopy.fixEvidenceGuardrail,
        suggestedTestFiles: const [
          ProofValueBottleneckPlaybookCopy.fixEvidenceTestConfirmedRepeatPhrase,
          ProofValueBottleneckPlaybookCopy.fixEvidenceTestFirstThreeSession,
          ProofValueBottleneckPlaybookCopy.fixEvidenceTestCurrentBelief,
          ProofValueBottleneckPlaybookCopy.fixEvidenceTestProofCopyDedup,
        ],
      ),
    ProofValueBottleneckPlaybookId.strengthenRetention =>
      ProofValueBottleneckPlaybookEntry(
        id: id,
        summaryLine: ProofOfValueCopy.recommendationStrengthenRetention,
        meaning: ProofValueBottleneckPlaybookCopy.strengthenRetentionMeaning,
        fixArea: ProofValueBottleneckPlaybookCopy.strengthenRetentionFixArea,
        inspectSurfaces: const [
          ProofValueBottleneckPlaybookCopy.strengthenRetentionInspectTimeline,
          ProofValueBottleneckPlaybookCopy
              .strengthenRetentionInspectWhatChanged,
          ProofValueBottleneckPlaybookCopy
              .strengthenRetentionInspectWeeklyReview,
          ProofValueBottleneckPlaybookCopy
              .strengthenRetentionInspectPrivateReport,
          ProofValueBottleneckPlaybookCopy
              .strengthenRetentionInspectFirstWeekLoop,
        ],
        guardrail:
            ProofValueBottleneckPlaybookCopy.strengthenRetentionGuardrail,
        suggestedTestFiles: const [
          ProofValueBottleneckPlaybookCopy.strengthenRetentionTestTimelineCard,
          ProofValueBottleneckPlaybookCopy.strengthenRetentionTestWhatChanged,
          ProofValueBottleneckPlaybookCopy.strengthenRetentionTestWeeklyReview,
          ProofValueBottleneckPlaybookCopy.strengthenRetentionTestPrivateReport,
        ],
      ),
    ProofValueBottleneckPlaybookId.strengthenPro =>
      ProofValueBottleneckPlaybookEntry(
        id: id,
        summaryLine: ProofOfValueCopy.recommendationStrengthenPro,
        meaning: ProofValueBottleneckPlaybookCopy.strengthenProMeaning,
        fixArea: ProofValueBottleneckPlaybookCopy.strengthenProFixArea,
        inspectSurfaces: const [
          ProofValueBottleneckPlaybookCopy.strengthenProInspectProBridge,
          ProofValueBottleneckPlaybookCopy
              .strengthenProInspectPrivateReportPreview,
          ProofValueBottleneckPlaybookCopy.strengthenProInspectWeeklyPro,
          ProofValueBottleneckPlaybookCopy.strengthenProInspectPaywallEntry,
          ProofValueBottleneckPlaybookCopy
              .strengthenProInspectRestoreVisibility,
        ],
        guardrail: ProofValueBottleneckPlaybookCopy.strengthenProGuardrail,
        suggestedTestFiles: const [
          ProofValueBottleneckPlaybookCopy.strengthenProTestFullArchiveHistory,
          ProofValueBottleneckPlaybookCopy.strengthenProTestPaywallTiming,
          ProofValueBottleneckPlaybookCopy.strengthenProTestPrivateReport,
          ProofValueBottleneckPlaybookCopy
              .strengthenProTestReleaseCandidateSmoke,
        ],
      ),
    ProofValueBottleneckPlaybookId.widenBeta =>
      ProofValueBottleneckPlaybookEntry(
        id: id,
        summaryLine: ProofOfValueCopy.recommendationWidenBeta,
        meaning: ProofValueBottleneckPlaybookCopy.widenBetaMeaning,
        fixArea: ProofValueBottleneckPlaybookCopy.widenBetaFixArea,
        inspectSurfaces: const [
          ProofValueBottleneckPlaybookCopy.widenBetaInspectBetaReportExport,
          ProofValueBottleneckPlaybookCopy.widenBetaInspectSmokeChecklist,
          ProofValueBottleneckPlaybookCopy.widenBetaInspectProofOfValue,
        ],
        guardrail: ProofValueBottleneckPlaybookCopy.widenBetaGuardrail,
        suggestedTestFiles: const [
          ProofValueBottleneckPlaybookCopy.widenBetaTestReleaseCandidateSmoke,
          ProofValueBottleneckPlaybookCopy.widenBetaTestBetaReportExport,
          ProofValueBottleneckPlaybookCopy.widenBetaTestProofOfValue,
        ],
      ),
  };
}
