import 'package:archiveme_mobile/router/route_catalog.dart';
///
/// [V1NavigationGuard], [V1RouteInventory], validators, and route tests must
/// derive allow/quarantine lists from here — do not duplicate string paths.
abstract final class V1RouteRegistry {
  V1RouteRegistry._();

  // Canonical paths referenced by active UI.
  static const exportPath = '/export';
  static const deleteAccountPath = '/delete-account';
  static const privacyPath = '/privacy';
  static const privacyTrustCentrePath = '/privacy-trust-centre';
  static const termsPath = '/terms';
  static const securityPath = '/security';
  static const privacySecurityPath = '/privacy-security';
  static const settingsPath = '/settings';
  static const supportFeedbackPath = '/support-feedback';
  static const subscriptionPath = '/subscription';
  static const pricingPath = '/pricing';
  static const restorePurchasesPath = '/restore-purchases';
  static const onboardingPath = '/onboarding';
  static const quickCapturePath = '/quick-capture';
  static const beliefEvidencePath = '/belief-evidence';
  static const beliefDetailPath = '/belief-detail';
  static const accountCreatePath = '/account/create';
  static const accountSignInPath = '/account/sign-in';
  static const guestDataMigrationPath = '/account/guest-data-migration';

  static const primaryShellPaths = RouteCatalog.primaryRoutes;

  static const supportingPaths = [
    onboardingPath,
    RouteCatalog.changesHome,
    '${RouteCatalog.archiveHome}/changes',
    '/entry/:id',
    beliefEvidencePath,
    beliefDetailPath,
    quickCapturePath,
    settingsPath,
    securityPath,
    privacySecurityPath,
    privacyPath,
    privacyTrustCentrePath,
    termsPath,
    '/about',
    exportPath,
    deleteAccountPath,
    supportFeedbackPath,
    accountCreatePath,
    accountSignInPath,
    guestDataMigrationPath,
  ];

  static const paidPaths = <String>[];

  static const additionalExactPaths = [
    '/',
    '/onboarding-intent',
    '/onboarding-loop',
  ];

  static const prefixPaths = [
    '/entry/',
    '/account/',
    '/sample-archive/context/',
    '/archive-evidence-map/context/',
    '/onboarding/',
  ];

  /// Deep-link and legacy paths that redirect — never valid active CTA targets.
  static const quarantinedExactPaths = [
    '/start/capacity-yes',
    '/start/prove-enough',
    '/start/generic',
    '/loop-mode',
    '/prove-enough/evidence-trail',
    '/prove-enough/monthly-review',
    '/weekly-story',
    '/archive-journey',
    '/archive-share',
    '/archive-analyst',
    '/archive-deep-dive',
    '/archive-evidence-trail',
    '/pressure-check-in',
    '/pressure-insights',
    '/journal',
    '/pinned-evidence',
    '/archive-packs',
    '/details',
    '/action-items',
    '/collections',
    '/moments',
    '/pattern-profile',
    '/archive-cleanup',
    '/pattern-map',
    '/archive-timeline',
    '/archive-review',
    '/ask-archive',
    '/moment-detail',
    '/updates',
    '/archive-export',
    '/signal-detail',
    '/signal-evidence',
    '/signal-journey',
    '/signal-review',
    '/restore-production-verify',
    '/sample-archive',
    '/beta-feedback',
    '/first-week-path',
    '/daily-archive-exercise',
    '/archive-clarity-progress',
    '/todays-one-question',
    '/then-vs-now',
    '/capacity-loop',
    '/capacity-weekly-review',
    '/capacity-boundary-response',
    '/quick-yes-capture',
    '/capacity-beta-mission',
    '/capacity-beta-signals',
    '/archive-calendar',
    '/review-ritual',
    '/yesterdays-snapshot',
    '/weekly-report',
    '/milestone-share-cards',
    '/beta-outcomes',
    '/beta-invite-pack',
    '/help-reviewer-guide',
    '/testing-archiveme',
    '/pro-preview',
    '/pro-interest',
    '/developer-diagnostics',
    '/first-pattern-quality',
    '/trial-control',
    '/native-push-verify',
    '/revenuecat-verify',
    '/offline-sync-verify',
    '/subscription-review-preview',
    '/pricing',
    '/subscription',
    '/restore-purchases',
    '/weekly-archive-review',
    '/insight-quality',
    '/live-voice',
    '/pattern-recognition',
    '/archive-share',
    '/blind-spots',
  ];

  static const parameterizedQuarantinePaths = [
    '/archive-packs/:id',
    '/collections/:id',
    '/archive-tool/:tool',
    '/archive-explanation/:id',
  ];

  static Set<String> get exactAllowlistedPaths => {
    ...additionalExactPaths,
    ...primaryShellPaths,
    ...supportingPaths,
    ...paidPaths,
  };

  static Set<String> get allQuarantinedPaths => {
    ...quarantinedExactPaths,
    ...parameterizedQuarantinePaths,
  };

  static int get allowlistedRouteCount => exactAllowlistedPaths.length;

  /// Canonical redirect when a quarantined export alias is opened.
  static String canonicalRedirectFor(String path) {
    if (path == '/archive-export') return exportPath;
    return RouteCatalog.archiveHome;
  }
}
