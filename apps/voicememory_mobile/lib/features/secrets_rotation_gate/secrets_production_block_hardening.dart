import '../commercial_readiness_gate/commercial_readiness_gate.dart';
import 'secrets_rotation_launch_gate.dart';
import 'secrets_rotation_launch_gate_copy.dart';

/// Secrets production block hardening — unavoidable production submission blocker.
abstract final class SecretsProductionBlockHardening {
  SecretsProductionBlockHardening._();

  static const requirementCount = 8;

  static const headline = 'Secrets production block hardening';

  static const body =
      'Make secrets rotation an unavoidable production submission blocker while '
      'keeping internal TestFlight safe when rotation is still pending.';

  static const guardrail =
      'Never print actual secrets. Never commit actual secrets. Hardening only — '
      'no product feature changes.';

  static const canonicalRequirements = [
    'Stripe secret key rotated',
    'Stripe webhook secret rotated',
    'Old webhook disabled',
    'Production env updated',
    'No secret values committed',
    'No secret values printed in logs',
    'RevenueCat key not exposed in docs/logs',
    'Production env verified',
  ];

  static const productionBlockedLine =
      'Production submission blocked until secrets rotation and repo safety pass.';

  static const testFlightSafeLine =
      'Internal TestFlight may proceed while rotation is pending if repo safety passes.';

  static const productionReadyLine =
      'Production submission may proceed. Secrets rotation is confirmed.';

  static SecretsProductionBlockHardeningResult build(
    SecretsRotationLaunchGateInput input,
  ) {
    final gateResult = SecretsRotationLaunchGate.build(input);
    final requirements = _buildRequirements(input, gateResult);
    final decision = _resolveDecision(gateResult);
    return SecretsProductionBlockHardeningResult(
      decision: decision,
      message: _messageFor(decision),
      recommendation: _recommendationFor(decision),
      requirements: requirements,
      gateResult: gateResult,
      productionSubmissionBlocked: !gateResult.productionSubmissionReady,
      internalTestFlightSafe: _internalTestFlightSafe(gateResult),
      unavoidableProductionBlock: _unavoidableProductionBlock(gateResult),
      earliestBlocker: gateResult.earliestBlocker,
    );
  }

  static SecretsProductionBlockHardeningReport report(
    SecretsProductionBlockHardeningResult result,
  ) =>
      SecretsProductionBlockHardeningReport(
        headline: headline,
        body: body,
        guardrail: guardrail,
        result: result,
      );

  static SecretsCommercialReadinessBridgeResult commercialReadinessBridge({
    required CommercialReadinessGateInput base,
    required SecretsRotationLaunchGateInput secrets,
  }) {
    final hardened = build(secrets);
    final merged = CommercialReadinessGate.mergeSecretsRotationLaunchGate(
      base,
      secrets,
    );
    final commercial = CommercialReadinessGate.build(merged);
    return SecretsCommercialReadinessBridgeResult(
      hardened: hardened,
      commercial: commercial,
      productionSubmissionBlocked: hardened.productionSubmissionBlocked,
      internalTestFlightSafe: hardened.internalTestFlightSafe,
    );
  }

  static bool blocksCommercialProduction({
    required CommercialReadinessGateInput base,
    required SecretsRotationLaunchGateInput secrets,
  }) =>
      commercialReadinessBridge(base: base, secrets: secrets)
          .productionSubmissionBlocked;

  static SecretsProductionBlockHardeningInput fromLaunchGateInput(
    SecretsRotationLaunchGateInput input,
  ) =>
      SecretsProductionBlockHardeningInput(launchGate: input);

  static bool detectNoRealSecretsInSource(String source) {
    const forbiddenPatterns = [
      'sk_live_',
      'sk_test_',
      'whsec_',
      're_live_',
      'appl_live_',
    ];

    for (final line in source.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('//')) continue;

      final isPatternDefinition = forbiddenPatterns.any(
        (pattern) =>
            trimmed.contains("'$pattern'") || trimmed.contains('"$pattern"'),
      );
      if (isPatternDefinition) continue;

      if (forbiddenPatterns.any(trimmed.contains)) {
        return false;
      }
    }

    return true;
  }

  static bool detectNeverPrintsSecrets(String hardeningSource) =>
      hardeningSource.contains('Never print actual secrets');

  static bool detectNeverCommitsSecrets(String hardeningSource) =>
      hardeningSource.contains('Never commit actual secrets');

  static bool _internalTestFlightSafe(SecretsRotationLaunchGateResult result) =>
      result.status ==
          SecretsRotationLaunchGateStatus.safeForInternalTestFlight ||
      result.status ==
          SecretsRotationLaunchGateStatus.readyForProductionSubmission;

  static bool _unavoidableProductionBlock(
    SecretsRotationLaunchGateResult result,
  ) {
    if (result.productionSubmissionReady) {
      return result.status ==
          SecretsRotationLaunchGateStatus.readyForProductionSubmission;
    }
    return result.status ==
            SecretsRotationLaunchGateStatus.blockedForProductionSubmission ||
        result.status ==
            SecretsRotationLaunchGateStatus.safeForInternalTestFlight;
  }

  static SecretsProductionBlockHardeningDecision _resolveDecision(
    SecretsRotationLaunchGateResult gateResult,
  ) {
    if (gateResult.productionSubmissionReady) {
      return SecretsProductionBlockHardeningDecision.productionReady;
    }
    if (_internalTestFlightSafe(gateResult)) {
      return SecretsProductionBlockHardeningDecision.testFlightSafeOnly;
    }
    return SecretsProductionBlockHardeningDecision.productionBlocked;
  }

  static List<SecretsProductionBlockRequirement> _buildRequirements(
    SecretsRotationLaunchGateInput input,
    SecretsRotationLaunchGateResult gateResult,
  ) {
    final repoSafe = input.revenueCatApiKeySeparatedFromDocsLogs &&
        input.noSecretValuesCommitted &&
        input.noSecretValuesPrintedInLogs;

    bool? passFor(bool? value) {
      if (!repoSafe && value == null) return false;
      return value;
    }

    return [
      _requirement(
        id: SecretsProductionBlockRequirementId.stripeSecretKeyRotated,
        passes: passFor(input.stripeSecretKeyRotated) == true,
        pending: input.stripeSecretKeyRotated == null && repoSafe,
      ),
      _requirement(
        id: SecretsProductionBlockRequirementId.stripeWebhookSecretRotated,
        passes: passFor(input.stripeWebhookSecretRotated) == true,
        pending: input.stripeWebhookSecretRotated == null && repoSafe,
      ),
      _requirement(
        id: SecretsProductionBlockRequirementId.oldWebhookDisabled,
        passes: passFor(input.oldWebhookDisabled) == true,
        pending: input.oldWebhookDisabled == null && repoSafe,
      ),
      _requirement(
        id: SecretsProductionBlockRequirementId.productionEnvUpdated,
        passes: passFor(input.productionEnvUpdated) == true,
        pending: input.productionEnvUpdated == null && repoSafe,
      ),
      _requirement(
        id: SecretsProductionBlockRequirementId.noSecretValuesCommitted,
        passes: input.noSecretValuesCommitted,
      ),
      _requirement(
        id: SecretsProductionBlockRequirementId.noSecretValuesPrintedInLogs,
        passes: input.noSecretValuesPrintedInLogs,
      ),
      _requirement(
        id: SecretsProductionBlockRequirementId.revenueCatKeyNotExposed,
        passes: input.revenueCatApiKeySeparatedFromDocsLogs,
      ),
      _requirement(
        id: SecretsProductionBlockRequirementId.productionEnvVerified,
        passes: passFor(input.vercelEnvProductionVerified) == true,
        pending: input.vercelEnvProductionVerified == null && repoSafe,
      ),
      _requirement(
        id: SecretsProductionBlockRequirementId.launchBlockedUntilRotationConfirmed,
        passes: gateResult.checks
            .firstWhere(
              (check) =>
                  check.id ==
                  SecretsRotationLaunchGateCheckId
                      .launchBlockedUntilRotationConfirmed,
            )
            .status ==
            SecretsRotationLaunchGateCheckStatus.pass,
        pending: gateResult.status ==
            SecretsRotationLaunchGateStatus.safeForInternalTestFlight,
      ),
    ];
  }

  static SecretsProductionBlockRequirement _requirement({
    required SecretsProductionBlockRequirementId id,
    required bool passes,
    bool pending = false,
  }) =>
      SecretsProductionBlockRequirement(
        id: id,
        label: _labelFor(id),
        passes: passes,
        pending: pending,
        detailLabel: pending
            ? SecretsRotationLaunchGateCopy.detailPending
            : passes
                ? SecretsRotationLaunchGateCopy.detailPass
                : SecretsRotationLaunchGateCopy.detailFail,
      );

  static String _labelFor(SecretsProductionBlockRequirementId id) =>
      switch (id) {
        SecretsProductionBlockRequirementId.stripeSecretKeyRotated =>
          canonicalRequirements[0],
        SecretsProductionBlockRequirementId.stripeWebhookSecretRotated =>
          canonicalRequirements[1],
        SecretsProductionBlockRequirementId.oldWebhookDisabled =>
          canonicalRequirements[2],
        SecretsProductionBlockRequirementId.productionEnvUpdated =>
          canonicalRequirements[3],
        SecretsProductionBlockRequirementId.noSecretValuesCommitted =>
          canonicalRequirements[4],
        SecretsProductionBlockRequirementId.noSecretValuesPrintedInLogs =>
          canonicalRequirements[5],
        SecretsProductionBlockRequirementId.revenueCatKeyNotExposed =>
          canonicalRequirements[6],
        SecretsProductionBlockRequirementId.productionEnvVerified =>
          canonicalRequirements[7],
        SecretsProductionBlockRequirementId.launchBlockedUntilRotationConfirmed =>
          'Launch blocked until rotation confirmed',
      };

  static String _messageFor(SecretsProductionBlockHardeningDecision decision) =>
      switch (decision) {
        SecretsProductionBlockHardeningDecision.productionBlocked =>
          productionBlockedLine,
        SecretsProductionBlockHardeningDecision.testFlightSafeOnly =>
          testFlightSafeLine,
        SecretsProductionBlockHardeningDecision.productionReady =>
          productionReadyLine,
      };

  static String _recommendationFor(
    SecretsProductionBlockHardeningDecision decision,
  ) =>
      switch (decision) {
        SecretsProductionBlockHardeningDecision.productionBlocked =>
          'Fix repo safety failures before TestFlight or production submission.',
        SecretsProductionBlockHardeningDecision.testFlightSafeOnly =>
          'Finish Stripe rotation and production env verification before App Store submission.',
        SecretsProductionBlockHardeningDecision.productionReady =>
          'Proceed with production submission.',
      };
}

enum SecretsProductionBlockHardeningDecision {
  productionBlocked,
  testFlightSafeOnly,
  productionReady,
}

enum SecretsProductionBlockRequirementId {
  stripeSecretKeyRotated,
  stripeWebhookSecretRotated,
  oldWebhookDisabled,
  productionEnvUpdated,
  noSecretValuesCommitted,
  noSecretValuesPrintedInLogs,
  revenueCatKeyNotExposed,
  productionEnvVerified,
  launchBlockedUntilRotationConfirmed,
}

class SecretsProductionBlockHardeningInput {
  const SecretsProductionBlockHardeningInput({
    required this.launchGate,
  });

  final SecretsRotationLaunchGateInput launchGate;
}

class SecretsProductionBlockRequirement {
  const SecretsProductionBlockRequirement({
    required this.id,
    required this.label,
    required this.passes,
    required this.pending,
    required this.detailLabel,
  });

  final SecretsProductionBlockRequirementId id;
  final String label;
  final bool passes;
  final bool pending;
  final String detailLabel;
}

class SecretsProductionBlockHardeningResult {
  const SecretsProductionBlockHardeningResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.requirements,
    required this.gateResult,
    required this.productionSubmissionBlocked,
    required this.internalTestFlightSafe,
    required this.unavoidableProductionBlock,
    required this.earliestBlocker,
  });

  final SecretsProductionBlockHardeningDecision decision;
  final String message;
  final String recommendation;
  final List<SecretsProductionBlockRequirement> requirements;
  final SecretsRotationLaunchGateResult gateResult;
  final bool productionSubmissionBlocked;
  final bool internalTestFlightSafe;
  final bool unavoidableProductionBlock;
  final SecretsRotationLaunchGateCheckId? earliestBlocker;
}

class SecretsProductionBlockHardeningReport {
  const SecretsProductionBlockHardeningReport({
    required this.headline,
    required this.body,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String guardrail;
  final SecretsProductionBlockHardeningResult result;
}

class SecretsCommercialReadinessBridgeResult {
  const SecretsCommercialReadinessBridgeResult({
    required this.hardened,
    required this.commercial,
    required this.productionSubmissionBlocked,
    required this.internalTestFlightSafe,
  });

  final SecretsProductionBlockHardeningResult hardened;
  final CommercialReadinessGateResult commercial;
  final bool productionSubmissionBlocked;
  final bool internalTestFlightSafe;
}
