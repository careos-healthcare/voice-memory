import 'secrets_rotation_launch_gate_copy.dart';

/// Secrets rotation launch gate — hard production blocker for exposed secrets.
abstract final class SecretsRotationLaunchGate {
  SecretsRotationLaunchGate._();

  static const checkCount = 9;

  static final RegExp _committedSecretPattern = RegExp(
    r'(sk_live_[A-Za-z0-9]{8,}|sk_test_[A-Za-z0-9]{16,}|whsec_[A-Za-z0-9]{16,}|'
    r'OPENAI_API_KEY\s*=\s*sk-|RESEND_API_KEY\s*=\s*re_[A-Za-z0-9]{8,}|'
    r'STRIPE_SECRET_KEY\s*=\s*sk_)',
  );

  static final RegExp _logSecretLeakPattern = RegExp(
    r'(debugPrint\s*\(\s*apiKey|print\s*\(\s*apiKey|log\s*\(\s*apiKey|'
    r'debugPrint\s*\(\s*[_]apiKey|STRIPE_SECRET_KEY\s*[=:]\s*sk_)',
    caseSensitive: false,
  );

  static SecretsRotationLaunchGateResult build(
    SecretsRotationLaunchGateInput input,
  ) {
    final checks = _buildChecks(input);
    final status = _resolveStatus(input);
    return SecretsRotationLaunchGateResult(
      status: status,
      message: SecretsRotationLaunchGateCopy.messageFor(status),
      recommendation: SecretsRotationLaunchGateCopy.recommendationFor(status),
      checks: checks,
      earliestBlocker: checks
          .where(
            (check) =>
                check.status == SecretsRotationLaunchGateCheckStatus.fail,
          )
          .map((check) => check.id)
          .firstOrNull,
      productionSubmissionReady:
          status ==
          SecretsRotationLaunchGateStatus.readyForProductionSubmission,
      testFlightAllowed:
          status !=
          SecretsRotationLaunchGateStatus.blockedForProductionSubmission,
    );
  }

  static SecretsRotationLaunchGateReport report(
    SecretsRotationLaunchGateResult result,
  ) => SecretsRotationLaunchGateReport(
    headline: SecretsRotationLaunchGateCopy.headline,
    body: SecretsRotationLaunchGateCopy.body,
    orderLine: SecretsRotationLaunchGateCopy.orderLine,
    guardrail: SecretsRotationLaunchGateCopy.guardrail,
    result: result,
  );

  static bool detectNoSecretValuesCommitted(String scannedSource) =>
      !_committedSecretPattern.hasMatch(scannedSource);

  static bool detectNoSecretValuesPrintedInLogs({
    required String revenueCatServiceSource,
    required String revenueCatArchiveLoopLogsSource,
    required String revenueCatOfferingsDebugLogSource,
    required String deploySecretsCheckSource,
  }) {
    if (_logSecretLeakPattern.hasMatch(revenueCatServiceSource)) return false;
    if (_logSecretLeakPattern.hasMatch(revenueCatArchiveLoopLogsSource)) {
      return false;
    }
    if (_logSecretLeakPattern.hasMatch(revenueCatOfferingsDebugLogSource)) {
      return false;
    }
    if (deploySecretsCheckSource.contains('STRIPE_SECRET_KEY') &&
        !deploySecretsCheckSource.contains('value not logged') &&
        !deploySecretsCheckSource.contains('prefix only')) {
      return false;
    }
    return !revenueCatServiceSource.contains('debugPrint(apiKey') &&
        !revenueCatServiceSource.contains('debugPrint(_apiKey');
  }

  static bool detectRevenueCatApiKeySeparatedFromDocsLogs({
    required String revenueCatServiceSource,
    required String revenueCatReleaseChecklistSource,
    required String revenueCatArchiveLoopLogsSource,
  }) =>
      revenueCatServiceSource.contains("String.fromEnvironment(") &&
      revenueCatServiceSource.contains('REVENUECAT_IOS_API_KEY') &&
      !revenueCatArchiveLoopLogsSource.contains('apiKey=') &&
      (revenueCatReleaseChecklistSource.contains('appl_xxx') ||
          revenueCatReleaseChecklistSource.contains('your_key_here'));

  static bool detectProductionEnvTemplatePresent(String envExampleSource) =>
      envExampleSource.contains('STRIPE_SECRET_KEY') &&
      envExampleSource.contains('STRIPE_WEBHOOK_SECRET') &&
      envExampleSource.contains('NEXT_PUBLIC_APP_URL');

  static bool detectDeploySecretsCheckPresent(
    String deploySecretsCheckSource,
  ) =>
      deploySecretsCheckSource.contains('validateDeploySecrets') &&
      deploySecretsCheckSource.contains('STRIPE_WEBHOOK_SECRET');

  static SecretsRotationLaunchGateInput fromRepoSignals({
    required String mobileLibAndDocsScanSource,
    required String revenueCatServiceSource,
    required String revenueCatArchiveLoopLogsSource,
    required String revenueCatOfferingsDebugLogSource,
    required String revenueCatReleaseChecklistSource,
    required String deploySecretsCheckSource,
    required String envExampleSource,
    bool? stripeSecretKeyRotated,
    bool? stripeWebhookSecretRotated,
    bool? productionEnvUpdated,
    bool? oldWebhookDisabled,
    bool? vercelEnvProductionVerified,
  }) {
    final noSecretsCommitted = detectNoSecretValuesCommitted(
      mobileLibAndDocsScanSource,
    );
    final noSecretsInLogs = detectNoSecretValuesPrintedInLogs(
      revenueCatServiceSource: revenueCatServiceSource,
      revenueCatArchiveLoopLogsSource: revenueCatArchiveLoopLogsSource,
      revenueCatOfferingsDebugLogSource: revenueCatOfferingsDebugLogSource,
      deploySecretsCheckSource: deploySecretsCheckSource,
    );
    final revenueCatSeparated = detectRevenueCatApiKeySeparatedFromDocsLogs(
      revenueCatServiceSource: revenueCatServiceSource,
      revenueCatReleaseChecklistSource: revenueCatReleaseChecklistSource,
      revenueCatArchiveLoopLogsSource: revenueCatArchiveLoopLogsSource,
    );
    final envTemplatePresent = detectProductionEnvTemplatePresent(
      envExampleSource,
    );
    final deployCheckPresent = detectDeploySecretsCheckPresent(
      deploySecretsCheckSource,
    );

    return SecretsRotationLaunchGateInput(
      stripeSecretKeyRotated: stripeSecretKeyRotated,
      stripeWebhookSecretRotated: stripeWebhookSecretRotated,
      productionEnvUpdated:
          productionEnvUpdated ??
          (envTemplatePresent && deployCheckPresent ? null : false),
      oldWebhookDisabled: oldWebhookDisabled,
      revenueCatApiKeySeparatedFromDocsLogs: revenueCatSeparated,
      noSecretValuesCommitted: noSecretsCommitted,
      noSecretValuesPrintedInLogs: noSecretsInLogs,
      vercelEnvProductionVerified:
          vercelEnvProductionVerified ?? (envTemplatePresent ? null : false),
    );
  }

  static bool _repoSafetyPasses(SecretsRotationLaunchGateInput input) =>
      input.revenueCatApiKeySeparatedFromDocsLogs &&
      input.noSecretValuesCommitted &&
      input.noSecretValuesPrintedInLogs;

  static bool _rotationConfirmed(SecretsRotationLaunchGateInput input) =>
      input.stripeSecretKeyRotated == true &&
      input.stripeWebhookSecretRotated == true &&
      input.productionEnvUpdated == true &&
      input.oldWebhookDisabled == true &&
      input.vercelEnvProductionVerified == true;

  static bool _rotationFailed(SecretsRotationLaunchGateInput input) =>
      input.stripeSecretKeyRotated == false ||
      input.stripeWebhookSecretRotated == false ||
      input.productionEnvUpdated == false ||
      input.oldWebhookDisabled == false ||
      input.vercelEnvProductionVerified == false;

  static bool _launchBlockEnforced(
    SecretsRotationLaunchGateInput input,
    SecretsRotationLaunchGateStatus status,
  ) {
    if (!_repoSafetyPasses(input)) {
      return status ==
          SecretsRotationLaunchGateStatus.blockedForProductionSubmission;
    }
    if (_rotationFailed(input)) {
      return status ==
          SecretsRotationLaunchGateStatus.blockedForProductionSubmission;
    }
    if (!_rotationConfirmed(input)) {
      return status ==
          SecretsRotationLaunchGateStatus.safeForInternalTestFlight;
    }
    return status ==
        SecretsRotationLaunchGateStatus.readyForProductionSubmission;
  }

  static SecretsRotationLaunchGateStatus _resolveStatus(
    SecretsRotationLaunchGateInput input,
  ) {
    if (!_repoSafetyPasses(input) || _rotationFailed(input)) {
      return SecretsRotationLaunchGateStatus.blockedForProductionSubmission;
    }
    if (!_rotationConfirmed(input)) {
      return SecretsRotationLaunchGateStatus.safeForInternalTestFlight;
    }
    return SecretsRotationLaunchGateStatus.readyForProductionSubmission;
  }

  static List<SecretsRotationLaunchGateCheck> _buildChecks(
    SecretsRotationLaunchGateInput input,
  ) {
    final status = _resolveStatus(input);
    final repoSafe = _repoSafetyPasses(input);

    SecretsRotationLaunchGateCheckStatus triState(bool? value) {
      if (value == null) return SecretsRotationLaunchGateCheckStatus.pending;
      return value
          ? SecretsRotationLaunchGateCheckStatus.pass
          : SecretsRotationLaunchGateCheckStatus.fail;
    }

    SecretsRotationLaunchGateCheckStatus repoBool(bool value) => value
        ? SecretsRotationLaunchGateCheckStatus.pass
        : SecretsRotationLaunchGateCheckStatus.fail;

    SecretsRotationLaunchGateCheckStatus gatedTriState({
      required bool prerequisite,
      required bool? value,
    }) {
      if (!prerequisite) {
        return SecretsRotationLaunchGateCheckStatus.blocked;
      }
      return triState(value);
    }

    return [
      _check(
        id: SecretsRotationLaunchGateCheckId.stripeSecretKeyRotated,
        status: gatedTriState(
          prerequisite: repoSafe,
          value: input.stripeSecretKeyRotated,
        ),
        detailLabel: _detailFor(
          gatedTriState(
            prerequisite: repoSafe,
            value: input.stripeSecretKeyRotated,
          ),
        ),
      ),
      _check(
        id: SecretsRotationLaunchGateCheckId.stripeWebhookSecretRotated,
        status: gatedTriState(
          prerequisite: repoSafe,
          value: input.stripeWebhookSecretRotated,
        ),
        detailLabel: _detailFor(
          gatedTriState(
            prerequisite: repoSafe,
            value: input.stripeWebhookSecretRotated,
          ),
        ),
      ),
      _check(
        id: SecretsRotationLaunchGateCheckId.productionEnvUpdated,
        status: gatedTriState(
          prerequisite: repoSafe,
          value: input.productionEnvUpdated,
        ),
        detailLabel: _detailFor(
          gatedTriState(
            prerequisite: repoSafe,
            value: input.productionEnvUpdated,
          ),
        ),
      ),
      _check(
        id: SecretsRotationLaunchGateCheckId.oldWebhookDisabled,
        status: gatedTriState(
          prerequisite: repoSafe,
          value: input.oldWebhookDisabled,
        ),
        detailLabel: _detailFor(
          gatedTriState(
            prerequisite: repoSafe,
            value: input.oldWebhookDisabled,
          ),
        ),
      ),
      _check(
        id: SecretsRotationLaunchGateCheckId
            .revenueCatApiKeySeparatedFromDocsLogs,
        status: repoBool(input.revenueCatApiKeySeparatedFromDocsLogs),
        detailLabel: input.revenueCatApiKeySeparatedFromDocsLogs
            ? SecretsRotationLaunchGateCopy.detailPass
            : SecretsRotationLaunchGateCopy.detailFail,
      ),
      _check(
        id: SecretsRotationLaunchGateCheckId.noSecretValuesCommitted,
        status: repoBool(input.noSecretValuesCommitted),
        detailLabel: input.noSecretValuesCommitted
            ? SecretsRotationLaunchGateCopy.detailPass
            : SecretsRotationLaunchGateCopy.detailFail,
      ),
      _check(
        id: SecretsRotationLaunchGateCheckId.noSecretValuesPrintedInLogs,
        status: repoBool(input.noSecretValuesPrintedInLogs),
        detailLabel: input.noSecretValuesPrintedInLogs
            ? SecretsRotationLaunchGateCopy.detailPass
            : SecretsRotationLaunchGateCopy.detailFail,
      ),
      _check(
        id: SecretsRotationLaunchGateCheckId.vercelEnvProductionVerified,
        status: gatedTriState(
          prerequisite: repoSafe,
          value: input.vercelEnvProductionVerified,
        ),
        detailLabel: _detailFor(
          gatedTriState(
            prerequisite: repoSafe,
            value: input.vercelEnvProductionVerified,
          ),
        ),
      ),
      _check(
        id: SecretsRotationLaunchGateCheckId
            .launchBlockedUntilRotationConfirmed,
        status: _launchBlockEnforced(input, status)
            ? SecretsRotationLaunchGateCheckStatus.pass
            : SecretsRotationLaunchGateCheckStatus.fail,
        detailLabel: _launchBlockEnforced(input, status)
            ? SecretsRotationLaunchGateCopy.detailPass
            : SecretsRotationLaunchGateCopy.detailFail,
      ),
    ];
  }

  static String _detailFor(SecretsRotationLaunchGateCheckStatus status) =>
      switch (status) {
        SecretsRotationLaunchGateCheckStatus.pass =>
          SecretsRotationLaunchGateCopy.detailPass,
        SecretsRotationLaunchGateCheckStatus.fail =>
          SecretsRotationLaunchGateCopy.detailFail,
        SecretsRotationLaunchGateCheckStatus.pending =>
          SecretsRotationLaunchGateCopy.detailPending,
        SecretsRotationLaunchGateCheckStatus.blocked =>
          SecretsRotationLaunchGateCopy.detailBlocked,
      };

  static SecretsRotationLaunchGateCheck _check({
    required SecretsRotationLaunchGateCheckId id,
    required SecretsRotationLaunchGateCheckStatus status,
    required String detailLabel,
  }) => SecretsRotationLaunchGateCheck(
    id: id,
    label: SecretsRotationLaunchGateCopy.labelFor(id),
    status: status,
    detailLabel: detailLabel,
  );
}

class SecretsRotationLaunchGateInput {
  const SecretsRotationLaunchGateInput({
    this.stripeSecretKeyRotated,
    this.stripeWebhookSecretRotated,
    this.productionEnvUpdated,
    this.oldWebhookDisabled,
    this.revenueCatApiKeySeparatedFromDocsLogs = false,
    this.noSecretValuesCommitted = false,
    this.noSecretValuesPrintedInLogs = false,
    this.vercelEnvProductionVerified,
  });

  final bool? stripeSecretKeyRotated;
  final bool? stripeWebhookSecretRotated;
  final bool? productionEnvUpdated;
  final bool? oldWebhookDisabled;
  final bool revenueCatApiKeySeparatedFromDocsLogs;
  final bool noSecretValuesCommitted;
  final bool noSecretValuesPrintedInLogs;
  final bool? vercelEnvProductionVerified;
}

class SecretsRotationLaunchGateCheck {
  const SecretsRotationLaunchGateCheck({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final SecretsRotationLaunchGateCheckId id;
  final String label;
  final SecretsRotationLaunchGateCheckStatus status;
  final String detailLabel;
}

class SecretsRotationLaunchGateResult {
  const SecretsRotationLaunchGateResult({
    required this.status,
    required this.message,
    required this.recommendation,
    required this.checks,
    required this.earliestBlocker,
    required this.productionSubmissionReady,
    required this.testFlightAllowed,
  });

  final SecretsRotationLaunchGateStatus status;
  final String message;
  final String recommendation;
  final List<SecretsRotationLaunchGateCheck> checks;
  final SecretsRotationLaunchGateCheckId? earliestBlocker;
  final bool productionSubmissionReady;
  final bool testFlightAllowed;
}

class SecretsRotationLaunchGateReport {
  const SecretsRotationLaunchGateReport({
    required this.headline,
    required this.body,
    required this.orderLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String orderLine;
  final String guardrail;
  final SecretsRotationLaunchGateResult result;
}
