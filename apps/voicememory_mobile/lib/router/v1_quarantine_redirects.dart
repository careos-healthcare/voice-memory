import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/config/v1_navigation_guard.dart';
import 'route_catalog.dart';

/// Redirect-only routes for quarantined non-V1 paths.
///
/// Keeps deep links and legacy URLs stable without importing lab screens into
/// the production router graph when [V1FeatureFlags.enableV1Only] is true.
abstract final class V1QuarantineRedirects {
  V1QuarantineRedirects._();

  /// Paths that must never mount a screen in the V1 production graph.
  static const exactPaths = [
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
    '/weekly-archive-review',
    '/insight-quality',
    '/live-voice',
  ];

  static const parameterizedPaths = [
    '/archive-packs/:id',
    '/collections/:id',
    '/archive-tool/:tool',
    '/archive-explanation/:id',
  ];

  static String redirectTarget(String path) =>
      V1NavigationGuard.redirectFor(path) ?? RouteCatalog.archiveHome;

  static GoRoute redirectRoute({
    required String path,
    required GlobalKey<NavigatorState> parentNavigatorKey,
  }) {
    return GoRoute(
      path: path,
      parentNavigatorKey: parentNavigatorKey,
      redirect: (context, state) => redirectTarget(state.uri.path),
    );
  }

  static List<GoRoute> routes({
    required GlobalKey<NavigatorState> rootNavigatorKey,
  }) {
    return [
      for (final path in exactPaths)
        redirectRoute(path: path, parentNavigatorKey: rootNavigatorKey),
      for (final path in parameterizedPaths)
        redirectRoute(path: path, parentNavigatorKey: rootNavigatorKey),
    ];
  }
}
