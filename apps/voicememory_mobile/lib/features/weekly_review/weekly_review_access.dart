import '../monetization/domain/access_policy_engine.dart';

/// The weekly review's only entitlement authority.
///
/// Generating a new review is a periodic-review generation and follows the
/// existing policy. Reading a review that was already generated is not, so an
/// expired subscription never blanks a review the user has already been shown.
abstract final class WeeklyReviewAccess {
  WeeklyReviewAccess._();

  static AccessDecision generation({
    required EntitlementSnapshot entitlement,
    UsageSnapshot usage = const UsageSnapshot(),
  }) => AccessPolicyEngine.decide(
    capability: CapabilityId.periodicReviewGeneration,
    entitlement: entitlement,
    usage: usage,
  );

  static AccessDecision reading({required EntitlementSnapshot entitlement}) =>
      AccessPolicyEngine.decide(
        capability: CapabilityId.readExistingGeneratedOutput,
        entitlement: entitlement,
      );
}
