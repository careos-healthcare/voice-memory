import 'access_policy_engine.dart';

/// Commercial decisions for the focused observation/comparison loop.
///
/// Evidence sufficiency chooses the capability. [AccessPolicyEngine] remains
/// the sole authority that decides whether generation is allowed.
abstract final class FocusedReturnAccessPolicy {
  FocusedReturnAccessPolicy._();

  static AccessDecision readExisting({
    required EntitlementSnapshot entitlement,
  }) => AccessPolicyEngine.decide(
    capability: CapabilityId.readExistingGeneratedOutput,
    entitlement: entitlement,
  );

  static AccessDecision generate({
    required int distinctMomentCount,
    required EntitlementSnapshot entitlement,
    required UsageSnapshot usage,
    ProductValueState productValue = const ProductValueState(),
  }) => AccessPolicyEngine.decide(
    capability: generationCapability(distinctMomentCount),
    entitlement: entitlement,
    usage: usage,
    productValue: productValue,
  );

  static CapabilityId generationCapability(int distinctMomentCount) {
    if (distinctMomentCount <= 1) {
      return CapabilityId.firstEvidenceObservation;
    }
    if (distinctMomentCount == 2) {
      return CapabilityId.firstEarlyComparison;
    }
    return CapabilityId.ongoingComparisons;
  }
}
