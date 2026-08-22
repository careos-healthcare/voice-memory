import 'package:archiveme_mobile/billing/archive_paywall_copy.dart';
import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/features/archive_analyst/archive_analyst_gate.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_trigger.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:archiveme_mobile/models/entitlement.dart';

/// GPT-5 archive synthesis requires RevenueCat `pro` entitlement.
abstract class ArchiveSynthesisProGate {
  ArchiveSynthesisProGate._();

  static const String upgradeHeadline = ArchivePaywallCopy.headline;
  static const String upgradeCta = ArchivePaywallCopy.primaryCta;

  /// RevenueCat `pro` entitlement (independent of synthesis feature flag).
  static bool hasProEntitlement(PremiumEntitlements? entitlements) =>
      entitlements?.isPro == true;

  /// Pro users with synthesis flag on may call GPT-5 APIs.
  static bool canAccessArchiveIntelligence(PremiumEntitlements? entitlements) {
    if (!AppConfig.enableGpt5ArchiveSynthesis) return false;
    return hasProEntitlement(entitlements);
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