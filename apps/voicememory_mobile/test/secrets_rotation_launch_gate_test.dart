import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/secrets_rotation_gate/secrets_rotation_launch_gate.dart';
import 'package:voicememory_mobile/features/secrets_rotation_gate/secrets_rotation_launch_gate_copy.dart';

const _docsPath = 'docs/SECRETS_ROTATION_LAUNCH_GATE.md';

SecretsRotationLaunchGateInput _input({
  bool? stripeSecretKeyRotated = true,
  bool? stripeWebhookSecretRotated = true,
  bool? productionEnvUpdated = true,
  bool? oldWebhookDisabled = true,
  bool revenueCatApiKeySeparatedFromDocsLogs = true,
  bool noSecretValuesCommitted = true,
  bool noSecretValuesPrintedInLogs = true,
  bool? vercelEnvProductionVerified = true,
}) =>
    SecretsRotationLaunchGateInput(
      stripeSecretKeyRotated: stripeSecretKeyRotated,
      stripeWebhookSecretRotated: stripeWebhookSecretRotated,
      productionEnvUpdated: productionEnvUpdated,
      oldWebhookDisabled: oldWebhookDisabled,
      revenueCatApiKeySeparatedFromDocsLogs:
          revenueCatApiKeySeparatedFromDocsLogs,
      noSecretValuesCommitted: noSecretValuesCommitted,
      noSecretValuesPrintedInLogs: noSecretValuesPrintedInLogs,
      vercelEnvProductionVerified: vercelEnvProductionVerified,
    );

SecretsRotationLaunchGateCheck _check(
  SecretsRotationLaunchGateResult result,
  SecretsRotationLaunchGateCheckId id,
) =>
    result.checks.firstWhere((check) => check.id == id);

String _readIfExists(String path) {
  final file = File(path);
  if (!file.existsSync()) return '';
  return file.readAsStringSync();
}

String _aggregateMobileLibAndDocs() {
  final buffer = StringBuffer();
  final roots = ['lib', 'docs'];
  for (final root in roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (entity.path.contains('/test/')) continue;
      if (!entity.path.endsWith('.dart') && !entity.path.endsWith('.md')) {
        continue;
      }
      buffer.writeln(entity.readAsStringSync());
    }
  }
  return buffer.toString();
}

void main() {
  group('SecretsRotationLaunchGate.build', () {
    test('gate has nine canonical checks', () {
      final result = SecretsRotationLaunchGate.build(_input());
      expect(result.checks.length, SecretsRotationLaunchGate.checkCount);
      expect(
        result.checks.map((check) => check.id).toList(),
        [
          SecretsRotationLaunchGateCheckId.stripeSecretKeyRotated,
          SecretsRotationLaunchGateCheckId.stripeWebhookSecretRotated,
          SecretsRotationLaunchGateCheckId.productionEnvUpdated,
          SecretsRotationLaunchGateCheckId.oldWebhookDisabled,
          SecretsRotationLaunchGateCheckId.revenueCatApiKeySeparatedFromDocsLogs,
          SecretsRotationLaunchGateCheckId.noSecretValuesCommitted,
          SecretsRotationLaunchGateCheckId.noSecretValuesPrintedInLogs,
          SecretsRotationLaunchGateCheckId.vercelEnvProductionVerified,
          SecretsRotationLaunchGateCheckId.launchBlockedUntilRotationConfirmed,
        ],
      );
    });

    test('all rotation confirmed and repo safe -> readyForProductionSubmission',
        () {
      final result = SecretsRotationLaunchGate.build(_input());
      expect(
        result.status,
        SecretsRotationLaunchGateStatus.readyForProductionSubmission,
      );
      expect(result.productionSubmissionReady, isTrue);
      expect(result.testFlightAllowed, isTrue);
      expect(result.earliestBlocker, isNull);
      expect(
        _check(
          result,
          SecretsRotationLaunchGateCheckId.launchBlockedUntilRotationConfirmed,
        ).status,
        SecretsRotationLaunchGateCheckStatus.pass,
      );
    });

    test('repo safe but rotation pending -> safeForInternalTestFlight', () {
      final result = SecretsRotationLaunchGate.build(
        _input(
          stripeSecretKeyRotated: null,
          stripeWebhookSecretRotated: null,
          productionEnvUpdated: null,
          oldWebhookDisabled: null,
          vercelEnvProductionVerified: null,
        ),
      );
      expect(
        result.status,
        SecretsRotationLaunchGateStatus.safeForInternalTestFlight,
      );
      expect(result.productionSubmissionReady, isFalse);
      expect(result.testFlightAllowed, isTrue);
      expect(
        _check(result, SecretsRotationLaunchGateCheckId.stripeSecretKeyRotated)
            .status,
        SecretsRotationLaunchGateCheckStatus.pending,
      );
    });

    test('committed secrets fail -> blockedForProductionSubmission', () {
      final result = SecretsRotationLaunchGate.build(
        _input(noSecretValuesCommitted: false),
      );
      expect(
        result.status,
        SecretsRotationLaunchGateStatus.blockedForProductionSubmission,
      );
      expect(result.testFlightAllowed, isFalse);
      expect(
        result.earliestBlocker,
        SecretsRotationLaunchGateCheckId.noSecretValuesCommitted,
      );
    });

    test('secret logs fail -> blockedForProductionSubmission', () {
      final result = SecretsRotationLaunchGate.build(
        _input(noSecretValuesPrintedInLogs: false),
      );
      expect(
        result.status,
        SecretsRotationLaunchGateStatus.blockedForProductionSubmission,
      );
    });

    test('rotation explicitly failed -> blockedForProductionSubmission', () {
      final result = SecretsRotationLaunchGate.build(
        _input(stripeSecretKeyRotated: false),
      );
      expect(
        result.status,
        SecretsRotationLaunchGateStatus.blockedForProductionSubmission,
      );
      expect(
        result.earliestBlocker,
        SecretsRotationLaunchGateCheckId.stripeSecretKeyRotated,
      );
    });

    test('repo safety failure blocks rotation checks', () {
      final result = SecretsRotationLaunchGate.build(
        _input(
          noSecretValuesCommitted: false,
          stripeSecretKeyRotated: null,
        ),
      );
      expect(
        _check(result, SecretsRotationLaunchGateCheckId.stripeSecretKeyRotated)
            .status,
        SecretsRotationLaunchGateCheckStatus.blocked,
      );
    });

    test('report exposes canonical copy', () {
      final report = SecretsRotationLaunchGate.report(
        SecretsRotationLaunchGate.build(_input()),
      );
      expect(report.headline, SecretsRotationLaunchGateCopy.headline);
      expect(report.guardrail, SecretsRotationLaunchGateCopy.guardrail);
    });
  });

  group('SecretsRotationLaunchGate detectors', () {
    test('detectNoSecretValuesCommitted rejects live Stripe prefixes', () {
      final stripePrefix = String.fromCharCodes([
        115, 107, 95, 108, 105, 118, 101, 95,
      ]);
      final fixture = 'STRIPE_SECRET_KEY=$stripePrefix${'x' * 24}';
      expect(
        SecretsRotationLaunchGate.detectNoSecretValuesCommitted(fixture),
        isFalse,
      );
      expect(
        SecretsRotationLaunchGate.detectNoSecretValuesCommitted(
          'placeholder only',
        ),
        isTrue,
      );
    });

    test('detectNoSecretValuesPrintedInLogs rejects apiKey debug prints', () {
      expect(
        SecretsRotationLaunchGate.detectNoSecretValuesPrintedInLogs(
          revenueCatServiceSource: "debugPrint(apiKey)",
          revenueCatArchiveLoopLogsSource: '',
          revenueCatOfferingsDebugLogSource: '',
          deploySecretsCheckSource: '',
        ),
        isFalse,
      );
    });
  });

  group('SecretsRotationLaunchGate.fromRepoSignals', () {
    late String mobileLibAndDocsScanSource;
    late String revenueCatServiceSource;
    late String revenueCatArchiveLoopLogsSource;
    late String revenueCatOfferingsDebugLogSource;
    late String revenueCatReleaseChecklistSource;
    late String deploySecretsCheckSource;
    late String envExampleSource;

    setUpAll(() {
      mobileLibAndDocsScanSource = _aggregateMobileLibAndDocs();
      revenueCatServiceSource =
          File('lib/billing/revenuecat_service.dart').readAsStringSync();
      revenueCatArchiveLoopLogsSource =
          File('lib/billing/revenuecat_archive_loop_logs.dart')
              .readAsStringSync();
      revenueCatOfferingsDebugLogSource =
          File('lib/billing/revenuecat_offerings_debug_log.dart')
              .readAsStringSync();
      revenueCatReleaseChecklistSource =
          File('docs/REVENUECAT_RELEASE_CHECKLIST.md').readAsStringSync();
      deploySecretsCheckSource = _readIfExists(
        '../../lib/server/deploy-secrets-check.ts',
      );
      envExampleSource = _readIfExists('../../.env.example');
    });

    test('repo signals detect RevenueCat separation and log safety', () {
      expect(
        SecretsRotationLaunchGate.detectRevenueCatApiKeySeparatedFromDocsLogs(
          revenueCatServiceSource: revenueCatServiceSource,
          revenueCatReleaseChecklistSource: revenueCatReleaseChecklistSource,
          revenueCatArchiveLoopLogsSource: revenueCatArchiveLoopLogsSource,
        ),
        isTrue,
      );
      expect(
        SecretsRotationLaunchGate.detectNoSecretValuesPrintedInLogs(
          revenueCatServiceSource: revenueCatServiceSource,
          revenueCatArchiveLoopLogsSource: revenueCatArchiveLoopLogsSource,
          revenueCatOfferingsDebugLogSource: revenueCatOfferingsDebugLogSource,
          deploySecretsCheckSource: deploySecretsCheckSource,
        ),
        isTrue,
      );
      expect(
        SecretsRotationLaunchGate.detectNoSecretValuesCommitted(
          mobileLibAndDocsScanSource,
        ),
        isTrue,
      );
    });

    test('fromRepoSignals returns safeForInternalTestFlight with repo checks passing',
        () {
      final result = SecretsRotationLaunchGate.build(
        SecretsRotationLaunchGate.fromRepoSignals(
          mobileLibAndDocsScanSource: mobileLibAndDocsScanSource,
          revenueCatServiceSource: revenueCatServiceSource,
          revenueCatArchiveLoopLogsSource: revenueCatArchiveLoopLogsSource,
          revenueCatOfferingsDebugLogSource: revenueCatOfferingsDebugLogSource,
          revenueCatReleaseChecklistSource: revenueCatReleaseChecklistSource,
          deploySecretsCheckSource: deploySecretsCheckSource,
          envExampleSource: envExampleSource,
        ),
      );
      expect(
        result.status,
        SecretsRotationLaunchGateStatus.safeForInternalTestFlight,
      );
      expect(
        _check(
          result,
          SecretsRotationLaunchGateCheckId.noSecretValuesCommitted,
        ).status,
        SecretsRotationLaunchGateCheckStatus.pass,
      );
      expect(
        _check(
          result,
          SecretsRotationLaunchGateCheckId.revenueCatApiKeySeparatedFromDocsLogs,
        ).status,
        SecretsRotationLaunchGateCheckStatus.pass,
      );
    });
  });

  group('protected regression', () {
    test('docs describe checklist-only scope and TestFlight allowance', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('do not print secrets'));
      expect(doc, contains('do not commit secret values'));
      expect(doc, contains('testflight'));
      expect(doc, contains('blockedforproductionsubmission'));
    });

    test('guardrail forbids printing or committing secrets', () {
      final lower = SecretsRotationLaunchGateCopy.guardrail.toLowerCase();
      expect(lower, contains('do not print secrets'));
      expect(lower, contains('do not commit secret values'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy
          in SecretsRotationLaunchGateCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('visible copy never contains secret prefixes', () {
      final joined =
          SecretsRotationLaunchGateCopy.allVisibleStrings().join('\n');
      expect(joined, isNot(contains('sk_live_')));
      expect(joined, isNot(contains('sk_test_')));
      expect(joined, isNot(contains('whsec_')));
      expect(joined, isNot(contains('appl_')));
    });
  });
}
