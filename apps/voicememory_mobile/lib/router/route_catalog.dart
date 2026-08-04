/// Canonical destinations for the V1 shell.
abstract final class RouteCatalog {
  static const recordHome = '/record';
  static const archiveHome = '/archive-belief';
  static const changesHome = '/belief-changes';
  static const accountHome = '/account';
  static const onboarding = '/onboarding';
  static const quickTextCapture = '/quick-capture';
  static const recordingRecovery = '/recording-recovery';

  static const primaryRoutes = [
    recordHome,
    archiveHome,
    changesHome,
    accountHome,
  ];
}
