import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:archiveme_mobile/config/production_navigation.dart';
import 'package:archiveme_mobile/config/release_config.dart';
import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/features/activation/archive_evidence_map.dart';
import 'package:archiveme_mobile/features/activation/belief_evidence_trail.dart';
import 'package:archiveme_mobile/features/activation/capture_context_tags.dart';
import 'package:archiveme_mobile/features/activation/insight_quality_dashboard.dart';
import 'package:archiveme_mobile/features/activation/weekly_archive_review.dart';
import 'package:archiveme_mobile/router/developer_route_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(DeveloperSettingsGate.resetForTest);

  group('release config', () {
    test('screenshot mode disabled unless define is set', () {
      expect(ScreenshotMode.enabled, isFalse);
      expect(ReleaseConfig.screenshotCaptureActive, isFalse);
    });
  });

  group('legacy consumer redirects', () {
    test('Timeline Search Discover redirect to Patterns home', () {
      expect(DeveloperRouteGuard.redirectFor('/timeline'), '/archive-belief');
      expect(DeveloperRouteGuard.redirectFor('/search'), '/archive-belief');
      expect(DeveloperRouteGuard.redirectFor('/discover'), '/archive-belief');
      expect(
        DeveloperRouteGuard.redirectFor('/discover-changes'),
        '/archive-belief',
      );
    });
  });

  group('developer routes', () {
    test('locked developer routes redirect to Patterns home', () {
      DeveloperSettingsGate.resetForTest();
      for (final path in [
        '/developer-diagnostics',
        '/first-pattern-quality',
        '/revenuecat-verify',
        '/restore-production-verify',
        '/native-push-verify',
        '/offline-sync-verify',
        '/archive-analyst',
        '/archive-deep-dive',
        '/archive-share',
        '/archive-evidence-trail',
        '/archive-journey',
        '/weekly-story',
        '/updates',
        '/blind-spots',
        '/journal',
        '/archive-tool/debug',
        '/archive-explanation/test-id',
        '/discover-yourself/chapter/ch-1',
        '/subscription-review-preview',
        '/trial-control',
      ]) {
        expect(
          DeveloperRouteGuard.redirectFor(path),
          '/archive-belief',
          reason: path,
        );
        expect(
          ReleaseConfig.developerRouteAccessible(path),
          isFalse,
          reason: path,
        );
      }
    });

    test('consumer pushed routes stay reachable when locked', () {
      DeveloperSettingsGate.resetForTest();
      expect(DeveloperRouteGuard.redirectFor('/discover-yourself'), isNull);
      expect(DeveloperRouteGuard.redirectFor('/belief-changes'), isNull);
      expect(
        DeveloperRouteGuard.redirectFor(BeliefEvidenceNavigation.route),
        isNull,
      );
      expect(
        DeveloperRouteGuard.redirectFor(WeeklyArchiveReviewNavigation.route),
        isNull,
      );
      expect(
        DeveloperRouteGuard.redirectFor(InsightQualityNavigation.route),
        isNull,
      );
      expect(
        DeveloperRouteGuard.redirectFor(
          ArchiveEvidenceMapNavigation.contextPath(CaptureContextTagIds.work),
        ),
        isNull,
      );
      expect(DeveloperRouteGuard.redirectFor('/belief-detail'), isNull);
      expect(DeveloperRouteGuard.redirectFor('/subscription'), isNull);
      expect(DeveloperRouteGuard.redirectFor('/settings'), isNull);
    });

    test('key moments routes stay reachable when locked', () {
      DeveloperSettingsGate.resetForTest();
      expect(DeveloperRouteGuard.redirectFor('/moments'), isNull);
      expect(DeveloperRouteGuard.redirectFor('/moment-detail'), isNull);
    });

    test('pattern map route stays reachable when locked', () {
      DeveloperSettingsGate.resetForTest();
      expect(DeveloperRouteGuard.redirectFor('/pattern-map'), isNull);
    });

    test('pattern profile route stays reachable when locked', () {
      DeveloperSettingsGate.resetForTest();
      expect(DeveloperRouteGuard.redirectFor('/pattern-profile'), isNull);
    });

    test('archive timeline route stays reachable when locked', () {
      DeveloperSettingsGate.resetForTest();
      expect(DeveloperRouteGuard.redirectFor('/archive-timeline'), isNull);
    });

    test('ask archive route stays reachable when locked', () {
      DeveloperSettingsGate.resetForTest();
      expect(DeveloperRouteGuard.redirectFor('/ask-archive'), isNull);
    });

    test('archive cleanup route stays reachable when locked', () {
      DeveloperSettingsGate.resetForTest();
      expect(DeveloperRouteGuard.redirectFor('/archive-cleanup'), isNull);
    });

    test('unlocked developer routes are not redirected', () {
      DeveloperSettingsGate.applyLoadedUnlock(true);
      expect(DeveloperRouteGuard.redirectFor('/developer-diagnostics'), isNull);
      expect(DeveloperRouteGuard.redirectFor('/trial-control'), isNull);
      expect(ReleaseConfig.developerRouteAccessible('/trial-control'), isTrue);
      expect(DeveloperRouteGuard.redirectFor('/first-pattern-quality'), isNull);
      expect(DeveloperRouteGuard.redirectFor('/revenuecat-verify'), isNull);
      expect(DeveloperRouteGuard.redirectFor('/journal'), isNull);
      expect(DeveloperRouteGuard.redirectFor('/weekly-story'), isNull);
    });

    test('debug routes hidden from production nav when locked', () {
      DeveloperSettingsGate.resetForTest();
      expect(ProductionNavigation.isNavRouteVisible('/trial-control'), isFalse);
    });
  });
}