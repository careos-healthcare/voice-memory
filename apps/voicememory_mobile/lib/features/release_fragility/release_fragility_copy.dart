/// Release fragility audit copy — operational risks that survive green tests.
abstract final class ReleaseFragilityCopy {
  ReleaseFragilityCopy._();

  static const headline = 'Release fragility audit';

  static const body =
      'Identify operational risks that can break release even when tests pass. '
      'Audit only — no product changes.';

  static const orderLine =
      'Risks: signing, bundle id, display name, iOS deployment target, RevenueCat '
      'key, App Store products, entitlement id, restore path, support URL, privacy '
      'URL, terms URL, widget extension, production API, secrets, screenshots, '
      'TestFlight upload, stale product copy.';

  static const guardrail =
      'Release fragility audit reports risks only. No product changes. CI can '
      'report fragility without mutating release configuration.';

  static const lowRiskLine =
      'Low operational fragility. Repo signals and manual checks look stable.';

  static const manualCheckNeededLine =
      'Manual release checks still pending. Do not submit until evidence is recorded.';

  static const releaseBlockedLine =
      'Release blocked by operational fragility. Fix the earliest risk before submission.';

  static const detailLowRisk = 'Low risk';
  static const detailManualCheck = 'Manual check needed';
  static const detailReleaseBlocked = 'Release blocked';

  static String labelFor(ReleaseFragilityRiskId id) => switch (id) {
    ReleaseFragilityRiskId.signing => 'Signing',
    ReleaseFragilityRiskId.bundleId => 'Bundle id',
    ReleaseFragilityRiskId.displayName => 'Display name',
    ReleaseFragilityRiskId.iosDeploymentTarget => 'iOS deployment target',
    ReleaseFragilityRiskId.revenueCatKey => 'RevenueCat key',
    ReleaseFragilityRiskId.appStoreProducts => 'App Store products',
    ReleaseFragilityRiskId.entitlementId => 'Entitlement id',
    ReleaseFragilityRiskId.restorePath => 'Restore path',
    ReleaseFragilityRiskId.supportUrl => 'Support URL',
    ReleaseFragilityRiskId.privacyUrl => 'Privacy URL',
    ReleaseFragilityRiskId.termsUrl => 'Terms URL',
    ReleaseFragilityRiskId.widgetExtension => 'Widget extension',
    ReleaseFragilityRiskId.productionApi => 'Production API',
    ReleaseFragilityRiskId.secrets => 'Secrets',
    ReleaseFragilityRiskId.screenshots => 'Screenshots',
    ReleaseFragilityRiskId.testFlightUpload => 'TestFlight upload',
    ReleaseFragilityRiskId.staleProductCopy => 'Stale product copy',
  };

  static String messageFor(ReleaseFragilityDecision decision) =>
      switch (decision) {
        ReleaseFragilityDecision.lowRisk => lowRiskLine,
        ReleaseFragilityDecision.manualCheckNeeded => manualCheckNeededLine,
        ReleaseFragilityDecision.releaseBlocked => releaseBlockedLine,
      };

  static String recommendationFor(
    ReleaseFragilityDecision decision,
  ) => switch (decision) {
    ReleaseFragilityDecision.lowRisk =>
      'Continue release prep. Keep manual evidence updated as checks complete.',
    ReleaseFragilityDecision.manualCheckNeeded =>
      'Complete pending manual release evidence before App Store submission.',
    ReleaseFragilityDecision.releaseBlocked =>
      'Fix the earliest blocked operational risk before TestFlight or submission.',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield orderLine;
    yield guardrail;
    yield lowRiskLine;
    yield manualCheckNeededLine;
    yield releaseBlockedLine;
    yield detailLowRisk;
    yield detailManualCheck;
    yield detailReleaseBlocked;
    for (final id in ReleaseFragilityRiskId.values) {
      yield labelFor(id);
    }
    for (final decision in ReleaseFragilityDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum ReleaseFragilityRiskId {
  signing,
  bundleId,
  displayName,
  iosDeploymentTarget,
  revenueCatKey,
  appStoreProducts,
  entitlementId,
  restorePath,
  supportUrl,
  privacyUrl,
  termsUrl,
  widgetExtension,
  productionApi,
  secrets,
  screenshots,
  testFlightUpload,
  staleProductCopy,
}

enum ReleaseFragilityRiskLevel { lowRisk, manualCheckNeeded, releaseBlocked }

enum ReleaseFragilityDecision { lowRisk, manualCheckNeeded, releaseBlocked }
