/// Canonical destinations for the V1 shell and deferred feature routes.
abstract final class RouteCatalog {
  static const recordHome = '/record';
  static const archiveHome = '/archive-belief';
  /// Legacy deep-link path — not a primary shell destination.
  static const changesHome = '/belief-changes';
  static const accountHome = '/account';

  static const List<String> primaryRoutes = [
    recordHome,
    archiveHome,
    accountHome,
  ];

  /// Beta / deferred surfaces — not on the V1 launch allowlist by default.
  static const askArchive = '/ask-archive';
  static const onboardingLifeStage = '/onboarding/life-stage';
  static const onboardingBacklogImport = '/onboarding/backlog-import';

  /// Caregiver monitoring (compile-time gated).
  static const caregiverHome = '/caregiver';
  static const caregiverConsent = '/caregiver/consent';

  /// Professional coach tier (beta + compile-time gated).
  static const coachHome = '/coach';
  static const coachClientConsent = '/coach/client-consent';
}