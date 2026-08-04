import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/config/v1_feature_flags.dart';
import 'package:voicememory_mobile/core/config/v1_navigation_guard.dart';
import 'package:voicememory_mobile/config/production_navigation.dart';
import 'package:voicememory_mobile/product/archive_me_v1_product_contract.dart';

void main() {
  group('V1FeatureFlags', () {
    test('enableV1Only forces non-core flags off', () {
      expect(V1FeatureFlags.enableV1Only, isTrue);
      expect(V1FeatureFlags.enableThoughtMap, isFalse);
      expect(V1FeatureFlags.enableAnalyst, isFalse);
      expect(V1FeatureFlags.enableActionItems, isFalse);
      expect(V1FeatureFlags.enableWidgets, isFalse);
      expect(V1FeatureFlags.enableCustomReports, isFalse);
    });
  });

  group('V1NavigationGuard', () {
    test('allows core V1 routes', () {
      for (final path in [
        '/record',
        '/quick-capture',
        '/archive-belief',
        '/belief-changes',
        '/account',
        '/settings',
        '/subscription',
        '/pricing',
        '/recording-recovery',
        '/entry/abc123',
      ]) {
        expect(V1NavigationGuard.redirectFor(path), isNull, reason: path);
        expect(V1NavigationGuard.isNavRouteVisible(path), isTrue, reason: path);
      }
    });

    test('redirects non-core feature routes to archive home', () {
      for (final path in V1NavigationGuard.blockedFeatureRoutes) {
        final expected = path == '/live-voice'
            ? V1NavigationGuard.recordHome
            : V1NavigationGuard.archiveHome;
        expect(V1NavigationGuard.redirectFor(path), expected, reason: path);
        expect(
          ProductionNavigation.isNavRouteVisible(path),
          isFalse,
          reason: path,
        );
      }
    });

    test('contract has exactly four primary routes and defers experiments', () {
      expect(ArchiveMeV1ProductContract.primaryRoutes, [
        '/record',
        '/archive-belief',
        '/belief-changes',
        '/account',
      ]);
      for (final route in [
        '/life-os',
        '/life-os/graph',
        '/archive-tools',
        '/self-discovery',
        '/weekly-report',
        '/live-voice',
      ]) {
        expect(
          ArchiveMeV1ProductContract.isConsumerRouteAllowed(route),
          isFalse,
          reason: route,
        );
      }
      expect(
        ArchiveMeV1ProductContract.shouldInitializeAtStartup(
          ArchiveMeV1StartupService.localLlamaReconciliation,
        ),
        isFalse,
      );
      expect(
        ArchiveMeV1ProductContract.shouldInitializeAtStartup(
          ArchiveMeV1StartupService.transcriptionQueue,
        ),
        isTrue,
      );
    });

    test('redirects blocked capture-adjacent routes to record home', () {
      expect(
        V1NavigationGuard.redirectFor('/pressure-check-in'),
        V1NavigationGuard.recordHome,
      );
    });

    test('redirects developer-only routes blocked by V1 guard', () {
      expect(
        V1NavigationGuard.redirectFor('/developer-diagnostics'),
        V1NavigationGuard.archiveHome,
      );
      expect(
        ProductionNavigation.redirectAwayFromIncomplete('/pattern-map'),
        V1NavigationGuard.archiveHome,
      );
    });
  });
}
