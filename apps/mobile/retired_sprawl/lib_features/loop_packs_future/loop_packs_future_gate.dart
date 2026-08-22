import 'package:archiveme_mobile/features/loop_packs_future/loop_packs_future_copy.dart';
import 'package:archiveme_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:archiveme_mobile/features/single_launch_checklist/single_launch_checklist.dart';

/// Loop packs future gate — acquisition angles without V1 UI.
abstract final class LoopPacksFutureGate {
  LoopPacksFutureGate._();

  static const packCount = 6;
  static const prereqCount = 2;

  static const List<LoopPackFutureId> canonicalPackOrder = [
    LoopPackFutureId.sayingYesNoCapacity,
    LoopPackFutureId.tryingToProveEnough,
    LoopPackFutureId.relationshipReplay,
    LoopPackFutureId.avoidingDirectConversations,
    LoopPackFutureId.repeatingSameHabit,
    LoopPackFutureId.feelingBehindWhenStopping,
  ];

  static const List<LoopPackFuturePrereqId> canonicalPrereqOrder = [
    LoopPackFuturePrereqId.testFlightUploaded,
    LoopPackFuturePrereqId.paidIntentBetaComplete,
  ];

  static const Map<LoopPackFutureId, String> audienceWedgeIdByPack = {
    LoopPackFutureId.sayingYesNoCapacity: 'sayingYesNoCapacity',
    LoopPackFutureId.tryingToProveEnough: 'proveEnough',
    LoopPackFutureId.relationshipReplay: 'relationshipReplay',
    LoopPackFutureId.avoidingDirectConversations: 'avoidingDirectConversations',
    LoopPackFutureId.repeatingSameHabit: 'repeatingHabit',
    LoopPackFutureId.feelingBehindWhenStopping: 'feelingBehindWhenStop',
  };

  static LoopPacksFutureGateResult build(LoopPacksFutureGateInput input) {
    final prereqs = _buildPrereqs(input);
    final betaProofComplete = prereqs.every(
      (prereq) => prereq.status == LoopPackFuturePrereqStatus.pass,
    );
    final packs = _buildPacks(betaProofComplete: betaProofComplete);
    final decision = betaProofComplete
        ? LoopPacksFutureGateDecision.packsDocumentedOnly
        : LoopPacksFutureGateDecision.packsFrozen;
    return LoopPacksFutureGateResult(
      decision: decision,
      message: LoopPacksFutureCopy.messageFor(decision),
      recommendation: LoopPacksFutureCopy.recommendationFor(decision),
      prereqs: prereqs,
      prereqOrder: canonicalPrereqOrder,
      packs: packs,
      packOrder: canonicalPackOrder,
      betaProofComplete: betaProofComplete,
      v1SurfacingBlocked: true,
      onboardingUiBlocked: true,
      paywallBenefitsBlocked: true,
      earliestPrereqGap: prereqs
          .where((prereq) => prereq.status != LoopPackFuturePrereqStatus.pass)
          .map((prereq) => prereq.id)
          .firstOrNull,
      documentedPackCount: packs
          .where(
            (pack) =>
                pack.status == LoopPackFutureStatus.futureAcquisitionDocumented,
          )
          .length,
      blockedPackCount: packs
          .where(
            (pack) =>
                pack.status == LoopPackFutureStatus.blockedBeforeBetaProof,
          )
          .length,
    );
  }

  static LoopPacksFutureGateReport report(LoopPacksFutureGateResult result) =>
      LoopPacksFutureGateReport(
        headline: LoopPacksFutureCopy.headline,
        body: LoopPacksFutureCopy.body,
        orderLine: LoopPacksFutureCopy.orderLine,
        prereqOrderLine: LoopPacksFutureCopy.prereqOrderLine,
        guardrail: LoopPacksFutureCopy.guardrail,
        result: result,
      );

  static LoopPacksFutureGateInput composeInput({
    bool? testFlightUploaded,
    bool? paidIntentBetaComplete,
    SingleLaunchChecklistInput? launchChecklist,
    PaidIntentBetaProofResult? paidIntentBeta,
  }) => LoopPacksFutureGateInput(
    testFlightUploaded:
        testFlightUploaded ?? launchChecklist?.testFlightUploaded,
    paidIntentBetaComplete:
        paidIntentBetaComplete ??
        launchChecklist?.paidIntentBetaComplete ??
        _paidIntentBetaCompleteFrom(paidIntentBeta),
  );

  static LoopPacksFutureGateInput fromRepoSignals({
    required String loopPacksFutureDocSource,
    required String gateCopySource,
    required String audienceWedgeModelSource,
    bool? testFlightUploaded,
    bool? paidIntentBetaComplete,
  }) => LoopPacksFutureGateInput(
    testFlightUploaded: testFlightUploaded,
    paidIntentBetaComplete: paidIntentBetaComplete,
    roadmapDocListsPacks: detectRoadmapDocListsPacks(loopPacksFutureDocSource),
    guardrailPresentInCopy: detectGuardrailPresentInCopy(gateCopySource),
    audienceWedgeIdsAligned: detectAudienceWedgeIdsAligned(
      audienceWedgeModelSource,
    ),
  );

  static bool detectRoadmapDocListsPacks(String docSource) {
    const markers = [
      'saying yes with no capacity',
      'trying to prove enough',
      'relationship replay',
      'avoiding direct conversations',
      'repeating the same habit',
      'feeling behind when stopping',
    ];
    final lower = docSource.toLowerCase();
    return markers.every(lower.contains);
  }

  static bool detectGuardrailPresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return lower.contains('do not add new onboarding') &&
        lower.contains('do not add paywall benefits') &&
        lower.contains('clinical framing');
  }

  static bool detectAudienceWedgeIdsAligned(String audienceWedgeModelSource) {
    for (final wedgeId in audienceWedgeIdByPack.values) {
      if (!audienceWedgeModelSource.contains(wedgeId)) {
        return false;
      }
    }
    return true;
  }

  static bool? _paidIntentBetaCompleteFrom(PaidIntentBetaProofResult? result) {
    if (result == null) return null;
    return result.paidIntentSignalPromising;
  }

  static List<LoopPackFuturePrereq> _buildPrereqs(
    LoopPacksFutureGateInput input,
  ) => [
    _prereq(
      id: LoopPackFuturePrereqId.testFlightUploaded,
      value: input.testFlightUploaded,
    ),
    _prereq(
      id: LoopPackFuturePrereqId.paidIntentBetaComplete,
      value: input.paidIntentBetaComplete,
    ),
  ];

  static List<LoopPackFuture> _buildPacks({required bool betaProofComplete}) =>
      canonicalPackOrder
          .map(
            (id) => LoopPackFuture(
              id: id,
              label: LoopPacksFutureCopy.labelFor(id),
              positioning: LoopPacksFutureCopy.positioningFor(id),
              status: betaProofComplete
                  ? LoopPackFutureStatus.futureAcquisitionDocumented
                  : LoopPackFutureStatus.blockedBeforeBetaProof,
              detailLabel: betaProofComplete
                  ? LoopPacksFutureCopy.detailFutureAcquisitionDocumented
                  : LoopPacksFutureCopy.detailBlockedBeforeBetaProof,
              audienceWedgeId: audienceWedgeIdByPack[id]!,
            ),
          )
          .toList();

  static LoopPackFuturePrereqStatus _statusFor(bool? value) => switch (value) {
    true => LoopPackFuturePrereqStatus.pass,
    false => LoopPackFuturePrereqStatus.fail,
    null => LoopPackFuturePrereqStatus.pending,
  };

  static LoopPackFuturePrereq _prereq({
    required LoopPackFuturePrereqId id,
    required bool? value,
  }) {
    final status = _statusFor(value);
    return LoopPackFuturePrereq(
      id: id,
      label: LoopPacksFutureCopy.prereqLabelFor(id),
      status: status,
      detailLabel: switch (status) {
        LoopPackFuturePrereqStatus.pass => LoopPacksFutureCopy.detailPass,
        LoopPackFuturePrereqStatus.pending => LoopPacksFutureCopy.detailPending,
        LoopPackFuturePrereqStatus.fail => LoopPacksFutureCopy.detailFail,
      },
    );
  }
}

class LoopPacksFutureGateInput {
  const LoopPacksFutureGateInput({
    this.testFlightUploaded,
    this.paidIntentBetaComplete,
    this.roadmapDocListsPacks = true,
    this.guardrailPresentInCopy = true,
    this.audienceWedgeIdsAligned = true,
  });

  final bool? testFlightUploaded;
  final bool? paidIntentBetaComplete;
  final bool roadmapDocListsPacks;
  final bool guardrailPresentInCopy;
  final bool audienceWedgeIdsAligned;
}

class LoopPackFuturePrereq {
  const LoopPackFuturePrereq({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final LoopPackFuturePrereqId id;
  final String label;
  final LoopPackFuturePrereqStatus status;
  final String detailLabel;
}

class LoopPackFuture {
  const LoopPackFuture({
    required this.id,
    required this.label,
    required this.positioning,
    required this.status,
    required this.detailLabel,
    required this.audienceWedgeId,
  });

  final LoopPackFutureId id;
  final String label;
  final String positioning;
  final LoopPackFutureStatus status;
  final String detailLabel;
  final String audienceWedgeId;
}

class LoopPacksFutureGateResult {
  const LoopPacksFutureGateResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.prereqs,
    required this.prereqOrder,
    required this.packs,
    required this.packOrder,
    required this.betaProofComplete,
    required this.v1SurfacingBlocked,
    required this.onboardingUiBlocked,
    required this.paywallBenefitsBlocked,
    required this.earliestPrereqGap,
    required this.documentedPackCount,
    required this.blockedPackCount,
  });

  final LoopPacksFutureGateDecision decision;
  final String message;
  final String recommendation;
  final List<LoopPackFuturePrereq> prereqs;
  final List<LoopPackFuturePrereqId> prereqOrder;
  final List<LoopPackFuture> packs;
  final List<LoopPackFutureId> packOrder;
  final bool betaProofComplete;
  final bool v1SurfacingBlocked;
  final bool onboardingUiBlocked;
  final bool paywallBenefitsBlocked;
  final LoopPackFuturePrereqId? earliestPrereqGap;
  final int documentedPackCount;
  final int blockedPackCount;
}

class LoopPacksFutureGateReport {
  const LoopPacksFutureGateReport({
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
  final LoopPacksFutureGateResult result;
}