import 'package:archiveme_mobile/core/config/professional_coach_feature_flags.dart';
import 'package:archiveme_mobile/core/config/v1_navigation_guard.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    ProfessionalCoachFeatureFlags.debugOverride = null;
  });

  test('coach routes stay quarantined when professional coach flag is off', () {
    ProfessionalCoachFeatureFlags.debugOverride = false;

    expect(V1NavigationGuard.isAllowed(RouteCatalog.coachHome), isFalse);
    expect(V1NavigationGuard.isAllowed(RouteCatalog.coachClientConsent), isFalse);
    expect(
      V1NavigationGuard.redirectFor(RouteCatalog.coachHome),
      V1NavigationGuard.archiveHome,
    );
  });

  test('coach routes stay quarantined when professional coach flag is on', () {
    ProfessionalCoachFeatureFlags.debugOverride = true;

    expect(V1NavigationGuard.isAllowed(RouteCatalog.coachHome), isFalse);
    expect(V1NavigationGuard.isAllowed(RouteCatalog.coachClientConsent), isFalse);
    expect(
      V1NavigationGuard.redirectFor(RouteCatalog.coachHome),
      V1NavigationGuard.archiveHome,
    );
  });
}