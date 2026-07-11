import 'release_blocker_priority_copy.dart';

/// Release blocker priority — which blocker to fix first during freeze.
abstract final class ReleaseBlockerPriority {
  ReleaseBlockerPriority._();

  static ReleaseBlockerPriorityResult build(ReleaseBlockerPriorityInput input) {
    if (!input.freezeActive) {
      return _result(
        decision: ReleaseBlockerPriorityDecision.resumeAfterFreeze,
        message: ReleaseBlockerPriorityCopy.freezeLine,
      );
    }
    if (input.hasSecuritySecretsBlocker) {
      return _result(
        decision: ReleaseBlockerPriorityDecision.fixSecuritySecretsFirst,
        message: ReleaseBlockerPriorityCopy.securityLine,
      );
    }
    if (input.hasCrash) {
      return _result(
        decision: ReleaseBlockerPriorityDecision.fixCrashFirst,
        message: ReleaseBlockerPriorityCopy.crashLine,
      );
    }
    if (input.blocksStoreReadiness) {
      return _result(
        decision: ReleaseBlockerPriorityDecision.fixStoreReadinessFirst,
        message: ReleaseBlockerPriorityCopy.storeReadinessLine,
      );
    }
    if (input.risksAppStoreRejection) {
      return _result(
        decision: ReleaseBlockerPriorityDecision.fixAppStoreRiskFirst,
        message: ReleaseBlockerPriorityCopy.storeReadinessLine,
      );
    }
    if (input.blocksPurchase) {
      return _result(
        decision: ReleaseBlockerPriorityDecision.fixPurchaseFirst,
        message: ReleaseBlockerPriorityCopy.purchaseLine,
      );
    }
    if (input.blocksRestore) {
      return _result(
        decision: ReleaseBlockerPriorityDecision.fixRestoreFirst,
        message: ReleaseBlockerPriorityCopy.restoreLine,
      );
    }
    if (input.blocksEntitlement) {
      return _result(
        decision: ReleaseBlockerPriorityDecision.fixEntitlementFirst,
        message: ReleaseBlockerPriorityCopy.entitlementLine,
      );
    }
    if (input.firstJourneyComprehensionWeak) {
      return _result(
        decision: ReleaseBlockerPriorityDecision.fixFirstJourneyFirst,
        message: ReleaseBlockerPriorityCopy.firstJourneyLine,
      );
    }
    if (input.criticalProofTrustWeak) {
      return _result(
        decision: ReleaseBlockerPriorityDecision.fixProofTrustFirst,
        message: ReleaseBlockerPriorityCopy.proofTrustLine,
      );
    }
    if (input.paidIntentSignalWeak) {
      return _result(
        decision: ReleaseBlockerPriorityDecision.validatePaidIntentFirst,
        message: ReleaseBlockerPriorityCopy.paidIntentLine,
      );
    }
    return _result(
      decision: ReleaseBlockerPriorityDecision.readyForPaidIntentBeta,
      message: ReleaseBlockerPriorityCopy.readyLine,
    );
  }

  static ReleaseBlockerPriorityReport report(ReleaseBlockerPriorityResult result) =>
      ReleaseBlockerPriorityReport(
        headline: ReleaseBlockerPriorityCopy.headline,
        body: ReleaseBlockerPriorityCopy.body,
        priorityLine: ReleaseBlockerPriorityCopy.priorityLine,
        securityLine: ReleaseBlockerPriorityCopy.securityLine,
        crashLine: ReleaseBlockerPriorityCopy.crashLine,
        storeReadinessLine: ReleaseBlockerPriorityCopy.storeReadinessLine,
        purchaseLine: ReleaseBlockerPriorityCopy.purchaseLine,
        restoreLine: ReleaseBlockerPriorityCopy.restoreLine,
        entitlementLine: ReleaseBlockerPriorityCopy.entitlementLine,
        firstJourneyLine: ReleaseBlockerPriorityCopy.firstJourneyLine,
        proofTrustLine: ReleaseBlockerPriorityCopy.proofTrustLine,
        paidIntentLine: ReleaseBlockerPriorityCopy.paidIntentLine,
        readyLine: ReleaseBlockerPriorityCopy.readyLine,
        freezeLine: ReleaseBlockerPriorityCopy.freezeLine,
        guardrail: ReleaseBlockerPriorityCopy.guardrail,
        result: result,
      );

  static ReleaseBlockerPriorityResult _result({
    required ReleaseBlockerPriorityDecision decision,
    required String message,
  }) =>
      ReleaseBlockerPriorityResult(decision: decision, message: message);
}

enum ReleaseBlockerPriorityDecision {
  fixSecuritySecretsFirst,
  fixCrashFirst,
  fixStoreReadinessFirst,
  fixAppStoreRiskFirst,
  fixPurchaseFirst,
  fixRestoreFirst,
  fixEntitlementFirst,
  fixFirstJourneyFirst,
  fixProofTrustFirst,
  validatePaidIntentFirst,
  readyForPaidIntentBeta,
  resumeAfterFreeze,
}

class ReleaseBlockerPriorityInput {
  const ReleaseBlockerPriorityInput({
    required this.freezeActive,
    required this.hasSecuritySecretsBlocker,
    required this.hasCrash,
    required this.blocksStoreReadiness,
    required this.risksAppStoreRejection,
    required this.blocksPurchase,
    required this.blocksRestore,
    required this.blocksEntitlement,
    required this.firstJourneyComprehensionWeak,
    required this.criticalProofTrustWeak,
    required this.paidIntentSignalWeak,
  });

  final bool freezeActive;
  final bool hasSecuritySecretsBlocker;
  final bool hasCrash;
  final bool blocksStoreReadiness;
  final bool risksAppStoreRejection;
  final bool blocksPurchase;
  final bool blocksRestore;
  final bool blocksEntitlement;
  final bool firstJourneyComprehensionWeak;
  final bool criticalProofTrustWeak;
  final bool paidIntentSignalWeak;
}

class ReleaseBlockerPriorityResult {
  const ReleaseBlockerPriorityResult({
    required this.decision,
    required this.message,
  });

  final ReleaseBlockerPriorityDecision decision;
  final String message;
}

class ReleaseBlockerPriorityReport {
  const ReleaseBlockerPriorityReport({
    required this.headline,
    required this.body,
    required this.priorityLine,
    required this.securityLine,
    required this.crashLine,
    required this.storeReadinessLine,
    required this.purchaseLine,
    required this.restoreLine,
    required this.entitlementLine,
    required this.firstJourneyLine,
    required this.proofTrustLine,
    required this.paidIntentLine,
    required this.readyLine,
    required this.freezeLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String priorityLine;
  final String securityLine;
  final String crashLine;
  final String storeReadinessLine;
  final String purchaseLine;
  final String restoreLine;
  final String entitlementLine;
  final String firstJourneyLine;
  final String proofTrustLine;
  final String paidIntentLine;
  final String readyLine;
  final String freezeLine;
  final String guardrail;
  final ReleaseBlockerPriorityResult result;
}
