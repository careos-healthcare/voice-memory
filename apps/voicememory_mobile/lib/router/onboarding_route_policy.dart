import 'route_catalog.dart';

/// The single pre-capture route policy for focused V1.
///
/// Legacy onboarding URLs remain compatibility aliases, but they resolve to
/// the same promise screen and never activate an alternative product loop.
abstract final class OnboardingRoutePolicy {
  OnboardingRoutePolicy._();

  static const legacyAliases = <String>{
    '/onboarding-intent',
    '/onboarding-loop',
  };

  static bool isPromiseRoute(String path) =>
      path == RouteCatalog.onboarding || legacyAliases.contains(path);

  static String? redirectBeforeCapture({
    required String path,
    required bool onboardingComplete,
    required bool screenshotMode,
    required bool trialMode,
    required bool isInstantCapture,
  }) {
    if (screenshotMode ||
        trialMode ||
        onboardingComplete ||
        isPromiseRoute(path) ||
        isInstantCapture) {
      return null;
    }
    return RouteCatalog.onboarding;
  }
}
