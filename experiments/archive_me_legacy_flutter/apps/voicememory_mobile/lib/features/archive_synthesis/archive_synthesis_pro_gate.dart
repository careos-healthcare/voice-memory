import '../../billing/archive_paywall_copy.dart';
import '../../config/app_config.dart';
import '../../subscriptions/domain/subscription_models.dart';
import '../monetization/domain/access_policy_engine.dart';
import '../archive_analyst/archive_analyst_gate.dart';
import '../archive_v1/archive_v1_models.dart';
import 'archive_synthesis_trigger.dart';

/// GPT-5 archive synthesis requires a Pro subscription.
abstract class ArchiveSynthesisProGate {
  ArchiveSynthesisProGate._();

  static const String upgradeHeadline = ArchivePaywallCopy.headline;
  static const String upgradeCta = ArchivePaywallCopy.primaryCta;

  static bool hasProEntitlement(SubscriptionState? subscriptionState) =>
      AccessPolicyEngine.decide(
        capability: CapabilityId.deepArchiveSynthesis,
        entitlement: subscriptionState == null
            ? const EntitlementSnapshot.unknown()
            : EntitlementSnapshot.fromSubscriptionState(subscriptionState),
        usage: const UsageSnapshot.serverAuthoritative(),
      ).allowed;

  /// Pro users with synthesis flag on may call GPT-5 APIs.
  static bool canAccessArchiveIntelligence(
    SubscriptionState? subscriptionState,
  ) {
    if (!AppConfig.enableGpt5ArchiveSynthesis) return false;
    return hasProEntitlement(subscriptionState);
  }

  /// Show upgrade teaser only after free archive value (≥50 eligible reflections).
  static bool shouldShowUpgradeTeaser(ArchiveV1View view) {
    if (!AppConfig.enableGpt5ArchiveSynthesis) return false;
    final eligible = ArchiveAnalystGate.eligibleCount(view.eligibleEntries);
    return eligible >= ArchiveSynthesisTrigger.minEligible;
  }

  static bool isProOnlySurface(ArchiveIntelligenceSurface surface) {
    return switch (surface) {
      ArchiveIntelligenceSurface.monthlyReview ||
      ArchiveIntelligenceSurface.historian ||
      ArchiveIntelligenceSurface.milestoneReview ||
      ArchiveIntelligenceSurface.narrativeDeepDive => true,
      _ => false,
    };
  }

  static bool isFreeArchiveSurface(ArchiveIntelligenceSurface surface) =>
      !isProOnlySurface(surface);
}

enum ArchiveIntelligenceSurface {
  theory,
  lifecycle,
  changeFeed,
  contradictions,
  surprises,
  evidenceTrail,
  standardDeepDive,
  monthlyReview,
  historian,
  milestoneReview,
  narrativeDeepDive,
}
