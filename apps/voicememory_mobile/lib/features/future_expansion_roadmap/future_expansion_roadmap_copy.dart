/// Future expansion roadmap copy — capture ideas without V1 surfacing.
abstract final class FutureExpansionRoadmapCopy {
  FutureExpansionRoadmapCopy._();

  static const headline = 'Future expansion roadmap gate';

  static const body =
      'Capture expansion ideas without letting them enter V1 before release proof. '
      'Document only — no new live UI.';

  static const orderLine =
      'Ideas: loop packs, three-day proof challenge, private reports after proof, '
      'safe exports, referrals after proof, cross-device continuity, B2B work pressure, '
      'return-tomorrow ritual, contradiction change detection, safe sharing, Android after '
      'iOS proof, archive memory after V1, premium longer-trail tiers, partner-led niches.';

  static const prereqOrderLine =
      'Prerequisites: TestFlight uploaded, purchase works, restore works, entitlement '
      'persists, paid-intent beta complete, first proof success rate acceptable, no release '
      'blockers, no secrets production blocker for production launch.';

  static const guardrail =
      'Future expansion roadmap gate classifies ideas only. Expansion blocked before release '
      'proof. Ideas may be documented but not surfaced in V1. No new live UI. No pricing '
      'experiments before paid-intent beta.';

  static const expansionFrozenLine =
      'Expansion frozen until release proof is complete. Finish prerequisites before planning.';

  static const documentedOnlyLine =
      'Release proof is complete. Keep expansion documented and out of V1 surfaces.';

  static const postV1PlanningAllowedLine =
      'Release proof is complete. Post-V1 planning may begin for unlocked ideas only.';

  static const detailPass = 'Pass';
  static const detailPending = 'Pending';
  static const detailFail = 'Fail';

  static const detailBlockedBeforeReleaseProof = 'Blocked before release proof';
  static const detailDocumentedNotSurfaced = 'Documented, not surfaced in V1';
  static const detailReadyForPostV1Planning = 'Ready for post-V1 planning';

  static String labelFor(FutureExpansionIdeaId id) => switch (id) {
    FutureExpansionIdeaId.loopPacks => 'Loop packs',
    FutureExpansionIdeaId.threeDayProofChallenge => 'Three-day proof challenge',
    FutureExpansionIdeaId.privateReportsAfterProof =>
      'Private reports after proof',
    FutureExpansionIdeaId.safeExports => 'Safe exports',
    FutureExpansionIdeaId.referralsAfterProof => 'Referrals after proof',
    FutureExpansionIdeaId.crossDeviceContinuity => 'Cross-device continuity',
    FutureExpansionIdeaId.b2bWorkPressure => 'B2B work pressure',
    FutureExpansionIdeaId.returnTomorrowRitual => 'Return-tomorrow ritual',
    FutureExpansionIdeaId.contradictionChangeDetection =>
      'Contradiction change detection',
    FutureExpansionIdeaId.safeSharing => 'Safe sharing',
    FutureExpansionIdeaId.androidAfterIosProof => 'Android after iOS proof',
    FutureExpansionIdeaId.archiveMemoryAfterV1 => 'Archive memory after V1',
    FutureExpansionIdeaId.premiumLongerTrailTiers =>
      'Premium longer-trail tiers',
    FutureExpansionIdeaId.partnerLedNiches => 'Partner-led niches',
  };

  static String prereqLabelFor(FutureExpansionPrereqId id) => switch (id) {
    FutureExpansionPrereqId.testFlightUploaded => 'TestFlight uploaded',
    FutureExpansionPrereqId.purchaseWorks => 'Purchase works',
    FutureExpansionPrereqId.restoreWorks => 'Restore works',
    FutureExpansionPrereqId.entitlementPersists => 'Entitlement persists',
    FutureExpansionPrereqId.paidIntentBetaComplete =>
      'Paid-intent beta complete',
    FutureExpansionPrereqId.firstProofSuccessRateAcceptable =>
      'First proof success rate acceptable',
    FutureExpansionPrereqId.noReleaseBlockers => 'No release blockers',
    FutureExpansionPrereqId.noSecretsProductionBlockerForProductionLaunch =>
      'No secrets production blocker for production launch',
  };

  static String messageFor(FutureExpansionGateDecision decision) =>
      switch (decision) {
        FutureExpansionGateDecision.expansionFrozen => expansionFrozenLine,
        FutureExpansionGateDecision.documentedOnly => documentedOnlyLine,
        FutureExpansionGateDecision.postV1PlanningAllowed =>
          postV1PlanningAllowedLine,
      };

  static String recommendationFor(
    FutureExpansionGateDecision decision,
  ) => switch (decision) {
    FutureExpansionGateDecision.expansionFrozen =>
      'Complete release proof prerequisites before documenting expansion in product UI.',
    FutureExpansionGateDecision.documentedOnly =>
      'Keep expansion in docs and internal planning only. Do not add V1 surfaces.',
    FutureExpansionGateDecision.postV1PlanningAllowed =>
      'Plan post-V1 expansion branches one at a time. Keep V1 surfaces unchanged.',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield orderLine;
    yield prereqOrderLine;
    yield guardrail;
    yield expansionFrozenLine;
    yield documentedOnlyLine;
    yield postV1PlanningAllowedLine;
    yield detailPass;
    yield detailPending;
    yield detailFail;
    yield detailBlockedBeforeReleaseProof;
    yield detailDocumentedNotSurfaced;
    yield detailReadyForPostV1Planning;
    for (final id in FutureExpansionIdeaId.values) {
      yield labelFor(id);
    }
    for (final id in FutureExpansionPrereqId.values) {
      yield prereqLabelFor(id);
    }
    for (final decision in FutureExpansionGateDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum FutureExpansionIdeaId {
  loopPacks,
  threeDayProofChallenge,
  privateReportsAfterProof,
  safeExports,
  referralsAfterProof,
  crossDeviceContinuity,
  b2bWorkPressure,
  returnTomorrowRitual,
  contradictionChangeDetection,
  safeSharing,
  androidAfterIosProof,
  archiveMemoryAfterV1,
  premiumLongerTrailTiers,
  partnerLedNiches,
}

enum FutureExpansionPrereqId {
  testFlightUploaded,
  purchaseWorks,
  restoreWorks,
  entitlementPersists,
  paidIntentBetaComplete,
  firstProofSuccessRateAcceptable,
  noReleaseBlockers,
  noSecretsProductionBlockerForProductionLaunch,
}

enum FutureExpansionPrereqStatus { pass, pending, fail }

enum FutureExpansionIdeaStatus {
  blockedBeforeReleaseProof,
  documentedNotSurfaced,
  readyForPostV1Planning,
}

enum FutureExpansionGateDecision {
  expansionFrozen,
  documentedOnly,
  postV1PlanningAllowed,
}
