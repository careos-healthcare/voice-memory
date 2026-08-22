/// Secrets rotation launch gate copy — production submission blocker only.
abstract final class SecretsRotationLaunchGateCopy {
  SecretsRotationLaunchGateCopy._();

  static const headline = 'Secrets rotation launch gate';

  static const body =
      'Make exposed or old production secrets a hard launch blocker. '
      'TestFlight may proceed while rotation is pending; production submission '
      'stays blocked until rotation is confirmed.';

  static const orderLine =
      'Checks: Stripe secret rotation, webhook rotation, production env, old '
      'webhook disabled, RevenueCat key separation, no committed secrets, no '
      'secret logs, Vercel production env, launch block enforced.';

  static const checkStripeSecretKeyRotated = 'Stripe secret key rotated';
  static const checkStripeWebhookSecretRotated =
      'Stripe webhook secret rotated';
  static const checkProductionEnvUpdated = 'Production env updated';
  static const checkOldWebhookDisabled = 'Old webhook disabled';
  static const checkRevenueCatApiKeySeparatedFromDocsLogs =
      'RevenueCat API key separated from docs and logs';
  static const checkNoSecretValuesCommitted = 'No secret values committed';
  static const checkNoSecretValuesPrintedInLogs =
      'No secret values printed in logs';
  static const checkVercelEnvProductionVerified =
      'Vercel and production env verified';
  static const checkLaunchBlockedUntilRotationConfirmed =
      'Launch blocked until rotation confirmed';

  static const detailPass = 'Verified';
  static const detailFail = 'Blocked';
  static const detailPending = 'Confirm before production submission';
  static const detailBlocked = 'Blocked by repo safety';

  static const safeForInternalTestFlightLine =
      'Safe for internal TestFlight. Repo safety passes; confirm secret rotation '
      'before App Store production submission.';

  static const blockedForProductionSubmissionLine =
      'Blocked for production submission. Fix repo safety or complete secret '
      'rotation before launch.';

  static const readyForProductionSubmissionLine =
      'Ready for production submission. Secret rotation confirmed and repo safety '
      'passes.';

  static const guardrail =
      'Secrets rotation launch gate classifies launch safety only. Do not print '
      'secrets, do not commit secret values, and do not change product features.';

  static String labelFor(SecretsRotationLaunchGateCheckId id) => switch (id) {
    SecretsRotationLaunchGateCheckId.stripeSecretKeyRotated =>
      checkStripeSecretKeyRotated,
    SecretsRotationLaunchGateCheckId.stripeWebhookSecretRotated =>
      checkStripeWebhookSecretRotated,
    SecretsRotationLaunchGateCheckId.productionEnvUpdated =>
      checkProductionEnvUpdated,
    SecretsRotationLaunchGateCheckId.oldWebhookDisabled =>
      checkOldWebhookDisabled,
    SecretsRotationLaunchGateCheckId.revenueCatApiKeySeparatedFromDocsLogs =>
      checkRevenueCatApiKeySeparatedFromDocsLogs,
    SecretsRotationLaunchGateCheckId.noSecretValuesCommitted =>
      checkNoSecretValuesCommitted,
    SecretsRotationLaunchGateCheckId.noSecretValuesPrintedInLogs =>
      checkNoSecretValuesPrintedInLogs,
    SecretsRotationLaunchGateCheckId.vercelEnvProductionVerified =>
      checkVercelEnvProductionVerified,
    SecretsRotationLaunchGateCheckId.launchBlockedUntilRotationConfirmed =>
      checkLaunchBlockedUntilRotationConfirmed,
  };

  static String messageFor(SecretsRotationLaunchGateStatus status) =>
      switch (status) {
        SecretsRotationLaunchGateStatus.safeForInternalTestFlight =>
          safeForInternalTestFlightLine,
        SecretsRotationLaunchGateStatus.blockedForProductionSubmission =>
          blockedForProductionSubmissionLine,
        SecretsRotationLaunchGateStatus.readyForProductionSubmission =>
          readyForProductionSubmissionLine,
      };

  static String recommendationFor(
    SecretsRotationLaunchGateStatus status,
  ) => switch (status) {
    SecretsRotationLaunchGateStatus.safeForInternalTestFlight =>
      'Rotate Stripe secrets, update production env, disable old webhooks, '
          'and verify Vercel before submission.',
    SecretsRotationLaunchGateStatus.blockedForProductionSubmission =>
      'Remove committed secrets, stop secret logging, and complete rotation '
          'before any production launch.',
    SecretsRotationLaunchGateStatus.readyForProductionSubmission =>
      'Secrets rotation gate passes. Proceed to production submission.',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield orderLine;
    yield checkStripeSecretKeyRotated;
    yield checkStripeWebhookSecretRotated;
    yield checkProductionEnvUpdated;
    yield checkOldWebhookDisabled;
    yield checkRevenueCatApiKeySeparatedFromDocsLogs;
    yield checkNoSecretValuesCommitted;
    yield checkNoSecretValuesPrintedInLogs;
    yield checkVercelEnvProductionVerified;
    yield checkLaunchBlockedUntilRotationConfirmed;
    yield detailPass;
    yield detailFail;
    yield detailPending;
    yield detailBlocked;
    yield safeForInternalTestFlightLine;
    yield blockedForProductionSubmissionLine;
    yield readyForProductionSubmissionLine;
    yield guardrail;
    for (final status in SecretsRotationLaunchGateStatus.values) {
      yield messageFor(status);
      yield recommendationFor(status);
    }
  }
}

enum SecretsRotationLaunchGateCheckId {
  stripeSecretKeyRotated,
  stripeWebhookSecretRotated,
  productionEnvUpdated,
  oldWebhookDisabled,
  revenueCatApiKeySeparatedFromDocsLogs,
  noSecretValuesCommitted,
  noSecretValuesPrintedInLogs,
  vercelEnvProductionVerified,
  launchBlockedUntilRotationConfirmed,
}

enum SecretsRotationLaunchGateCheckStatus { pass, fail, pending, blocked }

enum SecretsRotationLaunchGateStatus {
  safeForInternalTestFlight,
  blockedForProductionSubmission,
  readyForProductionSubmission,
}