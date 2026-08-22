import {
  flutterHasRoute,
  flutterHasScreenToken,
  flutterPathExists,
  readFlutter,
} from "@/lib/mobile/flutter-repo";
import type { MobileJourneyAudit, MobileJourneyStep, MobileJourneyStepId } from "@/types/mobile-first-class";

function step(
  partial: Omit<MobileJourneyStep, "id" | "label"> & { id: MobileJourneyStepId; label: string },
): MobileJourneyStep {
  return partial;
}

/** Static audit: full mobile journey reachable without web. */
export function buildMobileJourneyAudit(): MobileJourneyAudit {
  const router = readFlutter("lib/router/app_router.dart");
  const pubspec = readFlutter("pubspec.yaml");
  const pricing = readFlutter("lib/screens/pricing_screen.dart");
  const paywall = readFlutter("lib/billing/value_moment_paywall.dart");
  const billing = readFlutter("lib/billing/billing_service.dart");
  const protect = readFlutter("lib/widgets/protect_archive_banner.dart");
  const account = readFlutter("lib/screens/account_screen.dart");

  const hasFlutterProject =
    flutterPathExists("pubspec.yaml") &&
    flutterPathExists("ios/Runner/Info.plist") &&
    flutterPathExists("android/app/src/main/AndroidManifest.xml");

  const hasRevenueCat = pubspec.includes("purchases_flutter");
  const browserCheckout =
    hasRevenueCat
      ? false
      : pricing.includes("launchUrl") && pricing.includes("LaunchMode.externalApplication");
  const hasNativeRestore =
    hasRevenueCat &&
    router.includes("RestorePurchasesScreen") &&
    readFlutter("lib/billing/revenuecat_service.dart").includes("restorePurchases");

  const steps: MobileJourneyStep[] = [
    step({
      id: "install",
      label: "Install",
      reachableOnMobile: hasFlutterProject && pubspec.includes("name: archiveme_mobile"),
      requiresWeb: false,
      evidence: hasFlutterProject
        ? ["apps/mobile with iOS + Android targets"]
        : [],
      blockers: hasFlutterProject ? [] : ["Flutter app or platform targets missing"],
    }),
    step({
      id: "onboarding",
      label: "Onboarding",
      reachableOnMobile:
        flutterHasRoute("/onboarding") && router.includes("OnboardingScreen"),
      requiresWeb: false,
      evidence: flutterHasRoute("/onboarding") ? ["/onboarding → OnboardingScreen"] : [],
      blockers: flutterHasRoute("/onboarding") ? [] : ["No /onboarding route"],
    }),
    step({
      id: "record",
      label: "Record",
      reachableOnMobile:
        flutterHasRoute("/record") &&
        flutterHasScreenToken("RecordScreen", "lib/screens/record_screen.dart"),
      requiresWeb: false,
      evidence: ["/record tab in MainShell"],
      blockers: [],
    }),
    step({
      id: "archive_belief",
      label: "Archive belief",
      reachableOnMobile:
        flutterHasRoute("/archive-belief") &&
        flutterHasScreenToken("ArchiveBeliefScreen", "lib/screens/archive_belief_screen.dart"),
      requiresWeb: false,
      evidence: ["/archive-belief → ArchiveBeliefScreen (archive-first home)"],
      blockers: [],
    }),
    step({
      id: "archive_changes",
      label: "Archive changes",
      reachableOnMobile:
        flutterHasRoute("/discover") &&
        flutterHasScreenToken("DiscoverScreen", "lib/screens/discover_screen.dart"),
      requiresWeb: false,
      evidence: ["/discover → Changes tab"],
      blockers: [],
    }),
    step({
      id: "protect_archive",
      label: "Protect archive",
      reachableOnMobile:
        protect.includes("ProtectArchiveBanner") &&
        protect.includes("Protect archive") &&
        account.includes("sendAuthCode"),
      requiresWeb: false,
      evidence: ["ProtectArchiveBanner on record", "Account email auth"],
      blockers:
        protect.includes("ProtectArchiveBanner") && account.includes("sendAuthCode")
          ? []
          : ["Protect banner or in-app auth missing"],
    }),
    step({
      id: "paywall",
      label: "Paywall",
      reachableOnMobile:
        paywall.includes("ValueMomentPaywallLogic") &&
        (readFlutter("lib/screens/record_screen.dart").includes("ValueMomentPaywallCard") ||
          readFlutter("lib/widgets/value_moment_paywall.dart").includes("ValueMomentPaywallCard")),
      requiresWeb: false,
      evidence: ["value_moment_paywall.dart wired on record/archive surfaces"],
      blockers: [],
    }),
    step({
      id: "purchase",
      label: "Purchase",
      reachableOnMobile:
        (flutterHasRoute("/subscription") &&
          router.includes("MobileSubscriptionScreen")) ||
        (flutterHasRoute("/pricing") && hasRevenueCat),
      requiresWeb: browserCheckout,
      evidence: hasRevenueCat
        ? ["/subscription → RevenueCat native purchase"]
        : ["/pricing → requires native billing"],
      blockers: [],
    }),
    step({
      id: "restore",
      label: "Restore",
      reachableOnMobile: hasNativeRestore,
      requiresWeb: !hasNativeRestore && browserCheckout,
      evidence: hasNativeRestore
        ? ["Native restore purchases flow"]
        : billing.includes("EntitlementCache")
          ? ["Entitlement cache only — no restore UI"]
          : [],
      blockers: hasNativeRestore
        ? []
        : ["No RevenueCat / restore purchases in Flutter app"],
    }),
    step({
      id: "return",
      label: "Return",
      reachableOnMobile:
        router.includes("initialLocation: '/archive-belief'") &&
        router.includes("onboardingGate"),
      requiresWeb: false,
      evidence: ["Archive-first initial location after onboarding"],
      blockers: router.includes("initialLocation: '/archive-belief'")
        ? []
        : ["App not configured for archive-first return"],
    }),
  ];

  const failingStepIds = steps
    .filter((s) => !s.reachableOnMobile || s.requiresWeb)
    .map((s) => s.id);

  const completeWithoutWeb = failingStepIds.length === 0;

  return {
    generatedAt: new Date().toISOString(),
    steps,
    completeWithoutWeb,
    failingStepIds,
  };
}
