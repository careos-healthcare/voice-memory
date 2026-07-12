import '../first_proof_success_beta/first_proof_success_beta_guard.dart';
import '../paid_intent_beta_proof/paid_intent_beta_proof.dart';
import '../release_fragility/release_fragility_audit.dart';
import '../release_fragility/release_fragility_copy.dart';
import '../secrets_rotation_gate/secrets_rotation_launch_gate.dart';
import '../secrets_rotation_gate/secrets_rotation_launch_gate_copy.dart';
import '../single_launch_checklist/single_launch_checklist.dart';
import 'future_expansion_roadmap_copy.dart';

/// Future expansion roadmap gate — capture ideas without V1 surfacing.
abstract final class FutureExpansionRoadmapGate {
  FutureExpansionRoadmapGate._();

  static const ideaCount = 14;
  static const prereqCount = 8;

  static const canonicalIdeaOrder = [
    FutureExpansionIdeaId.loopPacks,
    FutureExpansionIdeaId.threeDayProofChallenge,
    FutureExpansionIdeaId.privateReportsAfterProof,
    FutureExpansionIdeaId.safeExports,
    FutureExpansionIdeaId.referralsAfterProof,
    FutureExpansionIdeaId.crossDeviceContinuity,
    FutureExpansionIdeaId.b2bWorkPressure,
    FutureExpansionIdeaId.returnTomorrowRitual,
    FutureExpansionIdeaId.contradictionChangeDetection,
    FutureExpansionIdeaId.safeSharing,
    FutureExpansionIdeaId.androidAfterIosProof,
    FutureExpansionIdeaId.archiveMemoryAfterV1,
    FutureExpansionIdeaId.premiumLongerTrailTiers,
    FutureExpansionIdeaId.partnerLedNiches,
  ];

  static const canonicalPrereqOrder = [
    FutureExpansionPrereqId.testFlightUploaded,
    FutureExpansionPrereqId.purchaseWorks,
    FutureExpansionPrereqId.restoreWorks,
    FutureExpansionPrereqId.entitlementPersists,
    FutureExpansionPrereqId.paidIntentBetaComplete,
    FutureExpansionPrereqId.firstProofSuccessRateAcceptable,
    FutureExpansionPrereqId.noReleaseBlockers,
    FutureExpansionPrereqId.noSecretsProductionBlockerForProductionLaunch,
  ];

  static const documentedOnlyIdeaIds = {
    FutureExpansionIdeaId.threeDayProofChallenge,
    FutureExpansionIdeaId.crossDeviceContinuity,
    FutureExpansionIdeaId.premiumLongerTrailTiers,
  };

  static FutureExpansionRoadmapGateResult build(
    FutureExpansionRoadmapGateInput input,
  ) {
    final prereqs = _buildPrereqs(input);
    final releaseProofComplete = prereqs.every(
      (prereq) => prereq.status == FutureExpansionPrereqStatus.pass,
    );
    final ideas = _buildIdeas(input, releaseProofComplete: releaseProofComplete);
    final decision = _resolveDecision(
      prereqs: prereqs,
      ideas: ideas,
      releaseProofComplete: releaseProofComplete,
    );
    return FutureExpansionRoadmapGateResult(
      decision: decision,
      message: FutureExpansionRoadmapCopy.messageFor(decision),
      recommendation: FutureExpansionRoadmapCopy.recommendationFor(decision),
      prereqs: prereqs,
      prereqOrder: canonicalPrereqOrder,
      ideas: ideas,
      ideaOrder: canonicalIdeaOrder,
      releaseProofComplete: releaseProofComplete,
      pricingExperimentsBlocked: !(input.paidIntentBetaComplete ?? false),
      earliestPrereqGap: prereqs
          .where((prereq) => prereq.status != FutureExpansionPrereqStatus.pass)
          .map((prereq) => prereq.id)
          .firstOrNull,
      readyIdeaCount: ideas
          .where(
            (idea) =>
                idea.status == FutureExpansionIdeaStatus.readyForPostV1Planning,
          )
          .length,
      documentedIdeaCount: ideas
          .where(
            (idea) =>
                idea.status == FutureExpansionIdeaStatus.documentedNotSurfaced,
          )
          .length,
      blockedIdeaCount: ideas
          .where(
            (idea) =>
                idea.status ==
                FutureExpansionIdeaStatus.blockedBeforeReleaseProof,
          )
          .length,
    );
  }

  static FutureExpansionRoadmapGateReport report(
    FutureExpansionRoadmapGateResult result,
  ) =>
      FutureExpansionRoadmapGateReport(
        headline: FutureExpansionRoadmapCopy.headline,
        body: FutureExpansionRoadmapCopy.body,
        orderLine: FutureExpansionRoadmapCopy.orderLine,
        prereqOrderLine: FutureExpansionRoadmapCopy.prereqOrderLine,
        guardrail: FutureExpansionRoadmapCopy.guardrail,
        result: result,
      );

  static FutureExpansionRoadmapGateInput composeInput({
    bool? testFlightUploaded,
    bool? purchaseWorks,
    bool? restoreWorks,
    bool? entitlementPersists,
    bool? paidIntentBetaComplete,
    bool? firstProofSuccessRateAcceptable,
    bool? noReleaseBlockers,
    bool? noSecretsProductionBlockerForProductionLaunch,
    SingleLaunchChecklistInput? launchChecklist,
    ReleaseFragilityAuditResult? releaseFragility,
    FirstProofSuccessBetaResult? firstProofSuccessBeta,
    SecretsRotationLaunchGateResult? secretsRotation,
    PaidIntentBetaProofResult? paidIntentBeta,
  }) =>
      FutureExpansionRoadmapGateInput(
        testFlightUploaded: testFlightUploaded ??
            launchChecklist?.testFlightUploaded,
        purchaseWorks:
            purchaseWorks ?? launchChecklist?.sandboxPurchaseWorks,
        restoreWorks: restoreWorks ?? launchChecklist?.restoreWorks,
        entitlementPersists:
            entitlementPersists ?? launchChecklist?.entitlementPersists,
        paidIntentBetaComplete: paidIntentBetaComplete ??
            launchChecklist?.paidIntentBetaComplete ??
            _paidIntentBetaCompleteFrom(paidIntentBeta),
        firstProofSuccessRateAcceptable: firstProofSuccessRateAcceptable ??
            _firstProofSuccessAcceptableFrom(firstProofSuccessBeta),
        noReleaseBlockers: noReleaseBlockers ??
            _noReleaseBlockersFrom(releaseFragility),
        noSecretsProductionBlockerForProductionLaunch:
            noSecretsProductionBlockerForProductionLaunch ??
                _noSecretsProductionBlockerFrom(secretsRotation),
      );

  static FutureExpansionRoadmapGateInput fromRepoSignals({
    required String futureExpansionRoadmapDocSource,
    required String gateCopySource,
    bool? testFlightUploaded,
    bool? purchaseWorks,
    bool? restoreWorks,
    bool? entitlementPersists,
    bool? paidIntentBetaComplete,
    bool? firstProofSuccessRateAcceptable,
    bool? noReleaseBlockers,
    bool? noSecretsProductionBlockerForProductionLaunch,
  }) =>
      FutureExpansionRoadmapGateInput(
        testFlightUploaded: testFlightUploaded,
        purchaseWorks: purchaseWorks,
        restoreWorks: restoreWorks,
        entitlementPersists: entitlementPersists,
        paidIntentBetaComplete: paidIntentBetaComplete,
        firstProofSuccessRateAcceptable: firstProofSuccessRateAcceptable,
        noReleaseBlockers: noReleaseBlockers,
        noSecretsProductionBlockerForProductionLaunch:
            noSecretsProductionBlockerForProductionLaunch,
        roadmapDocListsIdeas: detectRoadmapDocListsIdeas(
          futureExpansionRoadmapDocSource,
        ),
        guardrailPresentInCopy: detectGuardrailPresentInCopy(gateCopySource),
      );

  static bool detectRoadmapDocListsIdeas(String docSource) {
    const markers = [
      'loop packs',
      'three-day proof challenge',
      'cross-device continuity',
      'premium longer-trail tiers',
      'partner-led niches',
    ];
    final lower = docSource.toLowerCase();
    return markers.every(lower.contains);
  }

  static bool detectGuardrailPresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return lower.contains('no new live ui') &&
        lower.contains('experiments before paid-intent beta');
  }

  static bool? _paidIntentBetaCompleteFrom(PaidIntentBetaProofResult? result) {
    if (result == null) return null;
    return result.paidIntentSignalPromising;
  }

  static bool? _firstProofSuccessAcceptableFrom(
    FirstProofSuccessBetaResult? result,
  ) {
    if (result == null) return null;
    return result.proofWorking;
  }

  static bool? _noReleaseBlockersFrom(ReleaseFragilityAuditResult? result) {
    if (result == null) return null;
    return result.decision != ReleaseFragilityDecision.releaseBlocked;
  }

  static bool? _noSecretsProductionBlockerFrom(
    SecretsRotationLaunchGateResult? result,
  ) {
    if (result == null) return null;
    return result.status ==
        SecretsRotationLaunchGateStatus.readyForProductionSubmission;
  }

  static List<FutureExpansionPrereq> _buildPrereqs(
    FutureExpansionRoadmapGateInput input,
  ) =>
      [
        _prereq(
          id: FutureExpansionPrereqId.testFlightUploaded,
          value: input.testFlightUploaded,
        ),
        _prereq(
          id: FutureExpansionPrereqId.purchaseWorks,
          value: input.purchaseWorks,
        ),
        _prereq(
          id: FutureExpansionPrereqId.restoreWorks,
          value: input.restoreWorks,
        ),
        _prereq(
          id: FutureExpansionPrereqId.entitlementPersists,
          value: input.entitlementPersists,
        ),
        _prereq(
          id: FutureExpansionPrereqId.paidIntentBetaComplete,
          value: input.paidIntentBetaComplete,
        ),
        _prereq(
          id: FutureExpansionPrereqId.firstProofSuccessRateAcceptable,
          value: input.firstProofSuccessRateAcceptable,
        ),
        _prereq(
          id: FutureExpansionPrereqId.noReleaseBlockers,
          value: input.noReleaseBlockers,
        ),
        _prereq(
          id: FutureExpansionPrereqId.noSecretsProductionBlockerForProductionLaunch,
          value: input.noSecretsProductionBlockerForProductionLaunch,
        ),
      ];

  static List<FutureExpansionIdea> _buildIdeas(
    FutureExpansionRoadmapGateInput input, {
    required bool releaseProofComplete,
  }) =>
      canonicalIdeaOrder
          .map(
            (id) => _idea(
              id: id,
              status: _statusForIdea(
                id: id,
                input: input,
                releaseProofComplete: releaseProofComplete,
              ),
            ),
          )
          .toList();

  static FutureExpansionIdeaStatus _statusForIdea({
    required FutureExpansionIdeaId id,
    required FutureExpansionRoadmapGateInput input,
    required bool releaseProofComplete,
  }) {
    if (!releaseProofComplete) {
      return FutureExpansionIdeaStatus.blockedBeforeReleaseProof;
    }
    if (documentedOnlyIdeaIds.contains(id)) {
      return FutureExpansionIdeaStatus.documentedNotSurfaced;
    }
    if (id == FutureExpansionIdeaId.premiumLongerTrailTiers &&
        !(input.paidIntentBetaComplete ?? false)) {
      return FutureExpansionIdeaStatus.documentedNotSurfaced;
    }
    return FutureExpansionIdeaStatus.readyForPostV1Planning;
  }

  static FutureExpansionGateDecision _resolveDecision({
    required List<FutureExpansionPrereq> prereqs,
    required List<FutureExpansionIdea> ideas,
    required bool releaseProofComplete,
  }) {
    if (!releaseProofComplete) {
      return FutureExpansionGateDecision.expansionFrozen;
    }
    final hasReadyIdeas = ideas.any(
      (idea) => idea.status == FutureExpansionIdeaStatus.readyForPostV1Planning,
    );
    if (hasReadyIdeas) {
      return FutureExpansionGateDecision.postV1PlanningAllowed;
    }
    return FutureExpansionGateDecision.documentedOnly;
  }

  static FutureExpansionPrereqStatus _statusFor(bool? value) => switch (value) {
        true => FutureExpansionPrereqStatus.pass,
        false => FutureExpansionPrereqStatus.fail,
        null => FutureExpansionPrereqStatus.pending,
      };

  static FutureExpansionPrereq _prereq({
    required FutureExpansionPrereqId id,
    required bool? value,
  }) {
    final status = _statusFor(value);
    return FutureExpansionPrereq(
      id: id,
      label: FutureExpansionRoadmapCopy.prereqLabelFor(id),
      status: status,
      detailLabel: switch (status) {
        FutureExpansionPrereqStatus.pass => FutureExpansionRoadmapCopy.detailPass,
        FutureExpansionPrereqStatus.pending =>
          FutureExpansionRoadmapCopy.detailPending,
        FutureExpansionPrereqStatus.fail => FutureExpansionRoadmapCopy.detailFail,
      },
    );
  }

  static FutureExpansionIdea _idea({
    required FutureExpansionIdeaId id,
    required FutureExpansionIdeaStatus status,
  }) =>
      FutureExpansionIdea(
        id: id,
        label: FutureExpansionRoadmapCopy.labelFor(id),
        status: status,
        detailLabel: switch (status) {
          FutureExpansionIdeaStatus.blockedBeforeReleaseProof =>
            FutureExpansionRoadmapCopy.detailBlockedBeforeReleaseProof,
          FutureExpansionIdeaStatus.documentedNotSurfaced =>
            FutureExpansionRoadmapCopy.detailDocumentedNotSurfaced,
          FutureExpansionIdeaStatus.readyForPostV1Planning =>
            FutureExpansionRoadmapCopy.detailReadyForPostV1Planning,
        },
      );
}

class FutureExpansionRoadmapGateInput {
  const FutureExpansionRoadmapGateInput({
    this.testFlightUploaded,
    this.purchaseWorks,
    this.restoreWorks,
    this.entitlementPersists,
    this.paidIntentBetaComplete,
    this.firstProofSuccessRateAcceptable,
    this.noReleaseBlockers,
    this.noSecretsProductionBlockerForProductionLaunch,
    this.roadmapDocListsIdeas = true,
    this.guardrailPresentInCopy = true,
  });

  final bool? testFlightUploaded;
  final bool? purchaseWorks;
  final bool? restoreWorks;
  final bool? entitlementPersists;
  final bool? paidIntentBetaComplete;
  final bool? firstProofSuccessRateAcceptable;
  final bool? noReleaseBlockers;
  final bool? noSecretsProductionBlockerForProductionLaunch;
  final bool roadmapDocListsIdeas;
  final bool guardrailPresentInCopy;
}

class FutureExpansionPrereq {
  const FutureExpansionPrereq({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final FutureExpansionPrereqId id;
  final String label;
  final FutureExpansionPrereqStatus status;
  final String detailLabel;
}

class FutureExpansionIdea {
  const FutureExpansionIdea({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final FutureExpansionIdeaId id;
  final String label;
  final FutureExpansionIdeaStatus status;
  final String detailLabel;
}

class FutureExpansionRoadmapGateResult {
  const FutureExpansionRoadmapGateResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.prereqs,
    required this.prereqOrder,
    required this.ideas,
    required this.ideaOrder,
    required this.releaseProofComplete,
    required this.pricingExperimentsBlocked,
    required this.earliestPrereqGap,
    required this.readyIdeaCount,
    required this.documentedIdeaCount,
    required this.blockedIdeaCount,
  });

  final FutureExpansionGateDecision decision;
  final String message;
  final String recommendation;
  final List<FutureExpansionPrereq> prereqs;
  final List<FutureExpansionPrereqId> prereqOrder;
  final List<FutureExpansionIdea> ideas;
  final List<FutureExpansionIdeaId> ideaOrder;
  final bool releaseProofComplete;
  final bool pricingExperimentsBlocked;
  final FutureExpansionPrereqId? earliestPrereqGap;
  final int readyIdeaCount;
  final int documentedIdeaCount;
  final int blockedIdeaCount;
}

class FutureExpansionRoadmapGateReport {
  const FutureExpansionRoadmapGateReport({
    required this.headline,
    required this.body,
    required this.orderLine,
    required this.prereqOrderLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String orderLine;
  final String prereqOrderLine;
  final String guardrail;
  final FutureExpansionRoadmapGateResult result;
}
