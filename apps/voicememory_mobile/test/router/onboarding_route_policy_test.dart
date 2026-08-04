import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/router/onboarding_route_policy.dart';
import 'package:voicememory_mobile/router/route_catalog.dart';

void main() {
  test('every ordinary first-session route resolves to one promise', () {
    for (final path in [
      '/',
      RouteCatalog.recordHome,
      RouteCatalog.archiveHome,
      '/cold-start/seed',
      '/start',
      '/start/prove-enough',
    ]) {
      expect(
        OnboardingRoutePolicy.redirectBeforeCapture(
          path: path,
          onboardingComplete: false,
          screenshotMode: false,
          trialMode: false,
          isInstantCapture: false,
        ),
        RouteCatalog.onboarding,
        reason: '$path must not bypass the canonical promise',
      );
    }
  });

  test('legacy onboarding URLs are aliases for the canonical promise', () {
    expect(
      OnboardingRoutePolicy.isPromiseRoute(RouteCatalog.onboarding),
      isTrue,
    );
    expect(OnboardingRoutePolicy.isPromiseRoute('/onboarding-intent'), isTrue);
    expect(OnboardingRoutePolicy.isPromiseRoute('/onboarding-loop'), isTrue);
  });

  test('completed onboarding does not force context or Memory Graph', () {
    for (final path in [
      RouteCatalog.recordHome,
      RouteCatalog.quickTextCapture,
    ]) {
      expect(
        OnboardingRoutePolicy.redirectBeforeCapture(
          path: path,
          onboardingComplete: true,
          screenshotMode: false,
          trialMode: false,
          isInstantCapture: false,
        ),
        isNull,
      );
    }
  });

  test('explicit instant capture remains available before onboarding', () {
    expect(
      OnboardingRoutePolicy.redirectBeforeCapture(
        path: RouteCatalog.quickTextCapture,
        onboardingComplete: false,
        screenshotMode: false,
        trialMode: false,
        isInstantCapture: true,
      ),
      isNull,
    );
  });
}
