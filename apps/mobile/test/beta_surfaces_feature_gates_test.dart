import 'package:archiveme_mobile/core/config/beta_surfaces_feature_flags.dart';
import 'package:archiveme_mobile/core/config/v1_navigation_guard.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BetaSurfacesFeatureFlags', () {
    tearDown(() {
      BetaSurfacesFeatureFlags.debugOverride = null;
    });

    test('default off — beta surfaces disabled in production builds', () {
      expect(BetaSurfacesFeatureFlags.enableBetaSurfaces, isFalse);
      expect(BetaSurfacesFeatureFlags.thematicLenses, isFalse);
      expect(BetaSurfacesFeatureFlags.askArchive, isFalse);
      expect(BetaSurfacesFeatureFlags.liveConversation, isFalse);
      expect(BetaSurfacesFeatureFlags.imageEvidence, isFalse);
    });

    test('when enabled, surfaces unlock with sub-flags', () {
      BetaSurfacesFeatureFlags.debugOverride = true;
      expect(BetaSurfacesFeatureFlags.thematicLenses, isTrue);
      expect(BetaSurfacesFeatureFlags.askArchive, isTrue);
    });
  });

  group('V1NavigationGuard beta surface routing', () {
    tearDown(() {
      BetaSurfacesFeatureFlags.debugOverride = null;
    });

    test('ask-archive stays quarantined when beta surfaces off', () {
      expect(
        V1NavigationGuard.redirectFor(RouteCatalog.askArchive),
        V1NavigationGuard.archiveHome,
      );
      expect(V1NavigationGuard.isAllowed(RouteCatalog.askArchive), isFalse);
    });

    test('ask-archive stays quarantined even when beta surfaces on', () {
      BetaSurfacesFeatureFlags.debugOverride = true;
      expect(
        V1NavigationGuard.redirectFor(RouteCatalog.askArchive),
        V1NavigationGuard.archiveHome,
      );
      expect(V1NavigationGuard.isAllowed(RouteCatalog.askArchive), isFalse);
    });

    test('life-stage onboarding redirects away when beta off', () {
      expect(
        V1NavigationGuard.redirectFor(RouteCatalog.onboardingLifeStage),
        V1NavigationGuard.archiveHome,
      );
    });

    test('life-stage onboarding redirects away when beta surfaces on', () {
      BetaSurfacesFeatureFlags.debugOverride = true;
      expect(
        V1NavigationGuard.redirectFor(RouteCatalog.onboardingLifeStage),
        V1NavigationGuard.archiveHome,
      );
    });
  });
}