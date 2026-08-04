import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/commercial_readiness_gate/commercial_readiness_gate.dart';
import 'package:voicememory_mobile/features/commercial_readiness_gate/commercial_readiness_gate_copy.dart';
import 'package:voicememory_mobile/features/secrets_rotation_gate/secrets_production_block_hardening.dart';
import 'package:voicememory_mobile/features/secrets_rotation_gate/secrets_rotation_launch_gate.dart';
import 'package:voicememory_mobile/features/secrets_rotation_gate/secrets_rotation_launch_gate_copy.dart';

const _docsPath = 'docs/SECRETS_PRODUCTION_BLOCK_HARDENING.md';
const _testPath = 'test/secrets_production_block_hardening_test.dart';
const _hardeningPath =
    'lib/features/secrets_rotation_gate/secrets_production_block_hardening.dart';

SecretsRotationLaunchGateInput _launchInput({
  bool? stripeSecretKeyRotated = true,
  bool? stripeWebhookSecretRotated = true,
  bool? productionEnvUpdated = true,
  bool? oldWebhookDisabled = true,
  bool revenueCatApiKeySeparatedFromDocsLogs = true,
  bool noSecretValuesCommitted = true,
  bool noSecretValuesPrintedInLogs = true,
  bool? vercelEnvProductionVerified = true,
}) => SecretsRotationLaunchGateInput(
  stripeSecretKeyRotated: stripeSecretKeyRotated,
  stripeWebhookSecretRotated: stripeWebhookSecretRotated,
  productionEnvUpdated: productionEnvUpdated,
  oldWebhookDisabled: oldWebhookDisabled,
  revenueCatApiKeySeparatedFromDocsLogs: revenueCatApiKeySeparatedFromDocsLogs,
  noSecretValuesCommitted: noSecretValuesCommitted,
  noSecretValuesPrintedInLogs: noSecretValuesPrintedInLogs,
  vercelEnvProductionVerified: vercelEnvProductionVerified,
);

CommercialReadinessGateInput _commercialBase({
  bool secretsRotationDone = false,
}) => CommercialReadinessGateInput(
  productPromiseClear: true,
  firstJourneyStable: true,
  firstProofUsefulEnough: true,
  proPromiseClear: true,
  revenueCatProductLoads: true,
  paywallPriceVisible: true,
  sandboxPurchaseWorks: true,
  restoreWorks: true,
  entitlementPersists: true,
  testFlightBuildUploaded: true,
  paidIntentBetaComplete: true,
  secretsRotationDone: secretsRotationDone,
);

SecretsProductionBlockRequirement _requirement(
  SecretsProductionBlockHardeningResult result,
  SecretsProductionBlockRequirementId id,
) => result.requirements.firstWhere((requirement) => requirement.id == id);

void main() {
  group('SecretsProductionBlockHardening.build', () {
    test('tracks nine hardened requirements', () {
      final result = SecretsProductionBlockHardening.build(_launchInput());
      expect(result.requirements.length, 9);
      expect(SecretsProductionBlockHardening.requirementCount, 8);
    });

    test('pending Stripe rotation blocks production', () {
      final result = SecretsProductionBlockHardening.build(
        _launchInput(
          stripeSecretKeyRotated: null,
          stripeWebhookSecretRotated: null,
          productionEnvUpdated: null,
          oldWebhookDisabled: null,
          vercelEnvProductionVerified: null,
        ),
      );
      expect(result.productionSubmissionBlocked, isTrue);
      expect(
        result.decision,
        SecretsProductionBlockHardeningDecision.testFlightSafeOnly,
      );
      expect(result.internalTestFlightSafe, isTrue);
      expect(result.unavoidableProductionBlock, isTrue);
      expect(
        _requirement(
          result,
          SecretsProductionBlockRequirementId.stripeSecretKeyRotated,
        ).pending,
        isTrue,
      );
    });

    test('missing env verification blocks production', () {
      final result = SecretsProductionBlockHardening.build(
        _launchInput(vercelEnvProductionVerified: false),
      );
      expect(result.productionSubmissionBlocked, isTrue);
      expect(
        result.decision,
        SecretsProductionBlockHardeningDecision.productionBlocked,
      );
      expect(result.internalTestFlightSafe, isFalse);
      expect(
        result.earliestBlocker,
        SecretsRotationLaunchGateCheckId.vercelEnvProductionVerified,
      );
    });

    test('internal TestFlight can pass with rotation pending', () {
      final result = SecretsProductionBlockHardening.build(
        _launchInput(
          stripeSecretKeyRotated: null,
          stripeWebhookSecretRotated: null,
          productionEnvUpdated: null,
          oldWebhookDisabled: null,
          vercelEnvProductionVerified: null,
        ),
      );
      expect(result.internalTestFlightSafe, isTrue);
      expect(
        result.gateResult.status,
        SecretsRotationLaunchGateStatus.safeForInternalTestFlight,
      );
      expect(result.productionSubmissionBlocked, isTrue);
    });

    test('all rotation confirmed -> production ready', () {
      final result = SecretsProductionBlockHardening.build(_launchInput());
      expect(
        result.decision,
        SecretsProductionBlockHardeningDecision.productionReady,
      );
      expect(result.productionSubmissionBlocked, isFalse);
      expect(result.unavoidableProductionBlock, isTrue);
    });

    test('report exposes hardening copy', () {
      final report = SecretsProductionBlockHardening.report(
        SecretsProductionBlockHardening.build(_launchInput()),
      );
      expect(report.headline, SecretsProductionBlockHardening.headline);
      expect(report.guardrail, SecretsProductionBlockHardening.guardrail);
    });
  });

  group('SecretsProductionBlockHardening.commercialReadinessBridge', () {
    test('blocks production if secrets not rotated', () {
      final bridge = SecretsProductionBlockHardening.commercialReadinessBridge(
        base: _commercialBase(),
        secrets: _launchInput(
          stripeSecretKeyRotated: null,
          stripeWebhookSecretRotated: null,
          productionEnvUpdated: null,
          oldWebhookDisabled: null,
          vercelEnvProductionVerified: null,
        ),
      );
      expect(bridge.productionSubmissionBlocked, isTrue);
      expect(bridge.internalTestFlightSafe, isTrue);
      expect(
        bridge.commercial.status,
        CommercialReadinessGateStatus.productionBlockedBySecrets,
      );
      expect(bridge.commercial.commerciallyReady, isFalse);
      expect(
        SecretsProductionBlockHardening.blocksCommercialProduction(
          base: _commercialBase(),
          secrets: _launchInput(
            stripeSecretKeyRotated: null,
            stripeWebhookSecretRotated: null,
            productionEnvUpdated: null,
            oldWebhookDisabled: null,
            vercelEnvProductionVerified: null,
          ),
        ),
        isTrue,
      );
    });

    test('allows commercial readiness when rotation confirmed', () {
      final bridge = SecretsProductionBlockHardening.commercialReadinessBridge(
        base: _commercialBase(),
        secrets: _launchInput(),
      );
      expect(bridge.productionSubmissionBlocked, isFalse);
      expect(
        bridge.commercial.status,
        CommercialReadinessGateStatus.commerciallyReady,
      );
      expect(bridge.commercial.commerciallyReady, isTrue);
    });
  });

  group('protected regression', () {
    late String testSource;
    late String hardeningSource;

    setUpAll(() {
      testSource = File(_testPath).readAsStringSync();
      hardeningSource = File(_hardeningPath).readAsStringSync();
    });

    test('docs describe unavoidable production block', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('unavoidable'));
      expect(doc, contains('testflight'));
      expect(doc, contains('never print'));
      expect(doc, contains('never commit'));
      expect(doc, contains('commercial readiness'));
    });

    test('guardrail forbids printing or committing secrets', () {
      final guardrail = SecretsProductionBlockHardening.guardrail.toLowerCase();
      expect(guardrail, contains('never print'));
      expect(guardrail, contains('never commit'));
      expect(
        SecretsProductionBlockHardening.detectNeverPrintsSecrets(
          hardeningSource,
        ),
        isTrue,
      );
      expect(
        SecretsProductionBlockHardening.detectNeverCommitsSecrets(
          hardeningSource,
        ),
        isTrue,
      );
    });

    test('no test contains real secret-looking values', () {
      expect(
        SecretsProductionBlockHardening.detectNoRealSecretsInSource(testSource),
        isTrue,
      );
      expect(
        SecretsProductionBlockHardening.detectNoRealSecretsInSource(
          hardeningSource,
        ),
        isTrue,
      );

      final stripePrefix = String.fromCharCodes([
        115,
        107,
        95,
        108,
        105,
        118,
        101,
        95,
      ]);
      expect(
        SecretsProductionBlockHardening.detectNoRealSecretsInSource(
          'STRIPE_SECRET_KEY=$stripePrefix${'x' * 24}',
        ),
        isFalse,
      );
    });

    test('module does not import billing purchases or api clients', () {
      final importLines = hardeningSource
          .split('\n')
          .where((line) => line.trim().startsWith('import '));
      for (final line in importLines) {
        expect(
          line.contains('package:purchases_flutter'),
          isFalse,
          reason: line,
        );
        expect(line.contains('../api/'), isFalse, reason: line);
      }
    });
  });
}
