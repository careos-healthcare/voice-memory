import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/config/v1_feature_flags.dart';
import 'package:voicememory_mobile/core/config/v1_navigation_guard.dart';
import 'package:voicememory_mobile/router/route_catalog.dart';

/// Objective 1 (launch surface) coverage for the strict V1 router allowlist.
///
/// This is a behavioral contract test, not an implementation-placement test:
/// it asserts what the guard actually *does* (allow/redirect), not how its
/// internal sets are named or ordered.
void main() {
  setUp(() {
    expect(
      V1FeatureFlags.enableV1Only,
      isTrue,
      reason:
          'These tests assume the default-deny V1 allowlist is active; if this '
          'flips, the whole launch-surface contract this file protects changes.',
    );
  });

  group('V1NavigationGuard — launch allowlist', () {
    test('primary tab routes and root are allowed with no redirect', () {
      for (final path in ['/', ...RouteCatalog.primaryRoutes]) {
        expect(V1NavigationGuard.redirectFor(path), isNull, reason: path);
        expect(V1NavigationGuard.isAllowed(path), isTrue, reason: path);
      }
    });

    test('customer-ready support/legal/billing routes are allowed', () {
      for (final path in [
        '/settings',
        '/subscription',
        '/pricing',
        '/restore-purchases',
        '/delete-account',
        '/export',
        '/privacy',
        '/privacy-trust-centre',
        '/terms',
        '/security',
        '/support-feedback',
        '/onboarding',
      ]) {
        expect(V1NavigationGuard.redirectFor(path), isNull, reason: path);
      }
    });

    test('entry and account detail prefixes are allowed', () {
      expect(V1NavigationGuard.isAllowed('/entry/abc123'), isTrue);
      expect(V1NavigationGuard.isAllowed('/account/sign-in'), isTrue);
      expect(V1NavigationGuard.isAllowed('/account/create'), isTrue);
    });

    test(
      'explicitly quarantined non-launch surfaces redirect away, not through',
      () {
        for (final path in [
          '/pattern-map',
          '/pattern-profile',
          '/pattern-recognition',
          '/action-items',
          '/archive-review',
          '/weekly-archive-review',
          '/prove-enough/monthly-review',
          '/insight-quality',
          '/archive-timeline',
          '/ask-archive',
          '/archive-cleanup',
          '/moments',
          '/journal',
          '/archive-journey',
          '/archive-share',
          '/archive-deep-dive',
          '/weekly-story',
          '/archive-export',
          '/archive-packs',
          '/collections',
          '/pinned-evidence',
          '/yesterdays-snapshot',
          '/review-ritual',
          '/archive-calendar',
        ]) {
          expect(V1NavigationGuard.redirectFor(path), isNotNull, reason: path);
          expect(V1NavigationGuard.isAllowed(path), isFalse, reason: path);
        }
      },
    );

    test(
      'capacity-loop, weekly-report, archive-analyst and archive-evidence-trail '
      'are not V1-allowed (regression guard for a prior allowlist/quarantine '
      'mismatch — these are registered app_router.dart routes that must not '
      'leak into the launch surface just because they exist)',
      () {
        for (final path in [
          '/capacity-loop',
          '/weekly-report',
          '/archive-analyst',
          '/archive-evidence-trail',
          '/beta-feedback',
          '/testing-archiveme',
        ]) {
          expect(V1NavigationGuard.isAllowed(path), isFalse, reason: path);
        }
      },
    );

    test(
      'unknown/unlisted routes fall back to Archive, not a 404 or crash',
      () {
        expect(
          V1NavigationGuard.redirectFor('/some-nonexistent-experiment'),
          RouteCatalog.archiveHome,
        );
      },
    );

    test('record-adjacent capture routes fall back to Record, not Archive', () {
      expect(
        V1NavigationGuard.redirectFor('/pressure-check-in'),
        RouteCatalog.recordHome,
      );
      expect(
        V1NavigationGuard.redirectFor('/loop-mode'),
        RouteCatalog.recordHome,
      );
    });

    test('nav visibility mirrors route allowlisting', () {
      expect(
        V1NavigationGuard.isNavRouteVisible(RouteCatalog.archiveHome),
        isTrue,
      );
      expect(V1NavigationGuard.isNavRouteVisible('/capacity-loop'), isFalse);
    });
  });
}
