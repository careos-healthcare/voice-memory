/// Release evidence pack copy — proof of readiness, not another checklist layer.
abstract final class ReleaseEvidencePackCopy {
  ReleaseEvidencePackCopy._();

  static const headline = 'Release evidence pack';

  static const body =
      'One evidence pack that proves ArchiveMe is ready for TestFlight or '
      'submission. Proof only — not product work.';

  static const notReadyLine =
      'Missing evidence returns not ready. Collect proof before expanding scope.';

  static const testFlightLine =
      'All evidence is present. Ready for TestFlight while secrets rotation '
      'finishes.';

  static const submissionLine =
      'All evidence is present and production secrets are rotated. Ready for '
      'submission.';

  static const guardrail =
      'Release evidence pack is proof only. Do not alter product UI or purchase '
      'logic while collecting evidence.';

  static const cleanGitStatusLabel = 'Clean git status';
  static const versionBuildCapturedLabel = 'Version and build number captured';
  static const physicalIphoneSmokeTestLabel = 'Physical iPhone smoke test';
  static const physicalIpadSmokeTestLabel = 'Physical iPad smoke test';
  static const productionApiSmokeTestLabel = 'Production API smoke test';
  static const voiceSavePathLabel = 'Voice save path';
  static const typedSavePathLabel = 'Typed save path';
  static const firstProofPathLabel = 'First proof path';
  static const proPaywallRouteLabel = 'Pro paywall route';
  static const revenueCatProductLoadLabel = 'RevenueCat product load';
  static const sandboxPurchaseLabel = 'Sandbox purchase';
  static const restorePurchasesLabel = 'Restore purchases';
  static const entitlementPersistenceLabel = 'Entitlement persistence';
  static const supportUrlLabel = 'Support URL';
  static const privacyUrlLabel = 'Privacy URL';
  static const termsUrlLabel = 'Terms URL';
  static const screenshotsLabel = 'Screenshots';
  static const testFlightUploadedLabel = 'TestFlight uploaded';
  static const secretsRotatedLabel = 'Production secrets rotated';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield notReadyLine;
    yield testFlightLine;
    yield submissionLine;
    yield cleanGitStatusLabel;
    yield versionBuildCapturedLabel;
    yield physicalIphoneSmokeTestLabel;
    yield physicalIpadSmokeTestLabel;
    yield productionApiSmokeTestLabel;
    yield voiceSavePathLabel;
    yield typedSavePathLabel;
    yield firstProofPathLabel;
    yield proPaywallRouteLabel;
    yield revenueCatProductLoadLabel;
    yield sandboxPurchaseLabel;
    yield restorePurchasesLabel;
    yield entitlementPersistenceLabel;
    yield supportUrlLabel;
    yield privacyUrlLabel;
    yield termsUrlLabel;
    yield screenshotsLabel;
    yield testFlightUploadedLabel;
    yield secretsRotatedLabel;
  }
}