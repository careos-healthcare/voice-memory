import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/release_fragility/release_fragility_audit.dart';
import 'package:voicememory_mobile/features/release_fragility/release_fragility_copy.dart';
import 'package:voicememory_mobile/features/secrets_rotation_gate/secrets_rotation_launch_gate.dart';

const _docsPath = 'docs/RELEASE_FRAGILITY_AUDIT.md';

ReleaseFragilityRisk _risk(
  ReleaseFragilityAuditResult result,
  ReleaseFragilityRiskId id,
) => result.risks.firstWhere((risk) => risk.id == id);

SecretsRotationLaunchGateInput _secretsInput({
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

ReleaseFragilityAuditInput _input({
  bool? signingConfigured,
  bool bundleIdCanonical = true,
  bool displayNameCanonical = true,
  bool iosDeploymentTargetAligned = true,
  bool revenueCatKeySeparated = true,
  bool appStoreProductsConfigured = true,
  bool entitlementIdConfigured = true,
  bool restorePathPresent = true,
  bool supportUrlConfigured = true,
  bool privacyUrlConfigured = true,
  bool termsRouteConfigured = true,
  bool widgetExtensionSafe = true,
  bool widgetExtensionNeedsReview = false,
  bool productionApiConfigured = true,
  SecretsRotationLaunchGateInput? secretsRotationInput,
  bool? screenshotsReady = true,
  bool? testFlightUploaded = true,
  bool staleProductCopyRisk = false,
  bool signingRepoSignal = true,
}) => ReleaseFragilityAuditInput(
  signingConfigured: signingConfigured,
  bundleIdCanonical: bundleIdCanonical,
  displayNameCanonical: displayNameCanonical,
  iosDeploymentTargetAligned: iosDeploymentTargetAligned,
  revenueCatKeySeparated: revenueCatKeySeparated,
  appStoreProductsConfigured: appStoreProductsConfigured,
  entitlementIdConfigured: entitlementIdConfigured,
  restorePathPresent: restorePathPresent,
  supportUrlConfigured: supportUrlConfigured,
  privacyUrlConfigured: privacyUrlConfigured,
  termsRouteConfigured: termsRouteConfigured,
  widgetExtensionSafe: widgetExtensionSafe,
  widgetExtensionNeedsReview: widgetExtensionNeedsReview,
  productionApiConfigured: productionApiConfigured,
  secretsRotationInput: secretsRotationInput ?? _secretsInput(),
  screenshotsReady: screenshotsReady,
  testFlightUploaded: testFlightUploaded,
  staleProductCopyRisk: staleProductCopyRisk,
  signingRepoSignal: signingRepoSignal,
);

String _readIfExists(String path) {
  final file = File(path);
  if (!file.existsSync()) return '';
  return file.readAsStringSync();
}

String _aggregateMobileLibAndDocs() {
  final buffer = StringBuffer();
  for (final root in ['lib', 'docs']) {
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
  group('ReleaseFragilityAudit.build', () {
    test('audit has seventeen canonical risks in order', () {
      final result = ReleaseFragilityAudit.build(_input());
      expect(result.risks.length, ReleaseFragilityAudit.riskCount);
      expect(result.riskOrder, ReleaseFragilityAudit.canonicalRiskOrder);
      expect(
        result.risks.map((risk) => risk.id).toList(),
        ReleaseFragilityAudit.canonicalRiskOrder,
      );
    });

    test('all repo and manual checks pass -> lowRisk', () {
      final result = ReleaseFragilityAudit.build(
        _input(signingConfigured: true),
      );
      expect(result.decision, ReleaseFragilityDecision.lowRisk);
      expect(result.blockedCount, 0);
      expect(result.manualCheckCount, 0);
      expect(result.lowRiskCount, ReleaseFragilityAudit.riskCount);
      expect(result.earliestBlocker, isNull);
    });

    test('bundle id mismatch -> releaseBlocked', () {
      final result = ReleaseFragilityAudit.build(
        _input(bundleIdCanonical: false),
      );
      expect(result.decision, ReleaseFragilityDecision.releaseBlocked);
      expect(result.earliestBlocker, ReleaseFragilityRiskId.bundleId);
      expect(
        _risk(result, ReleaseFragilityRiskId.bundleId).level,
        ReleaseFragilityRiskLevel.releaseBlocked,
      );
    });

    test('secrets rotation pending -> manualCheckNeeded', () {
      final result = ReleaseFragilityAudit.build(
        _input(
          signingConfigured: true,
          secretsRotationInput: _secretsInput(
            stripeSecretKeyRotated: null,
            stripeWebhookSecretRotated: null,
            productionEnvUpdated: null,
            oldWebhookDisabled: null,
            vercelEnvProductionVerified: null,
          ),
        ),
      );
      expect(result.decision, ReleaseFragilityDecision.manualCheckNeeded);
      expect(
        _risk(result, ReleaseFragilityRiskId.secrets).level,
        ReleaseFragilityRiskLevel.manualCheckNeeded,
      );
    });

    test('committed secrets unsafe -> releaseBlocked', () {
      final result = ReleaseFragilityAudit.build(
        _input(
          secretsRotationInput: _secretsInput(noSecretValuesCommitted: false),
        ),
      );
      expect(result.decision, ReleaseFragilityDecision.releaseBlocked);
      expect(
        _risk(result, ReleaseFragilityRiskId.secrets).level,
        ReleaseFragilityRiskLevel.releaseBlocked,
      );
    });

    test('widget extension blocks TestFlight -> releaseBlocked', () {
      final result = ReleaseFragilityAudit.build(
        _input(widgetExtensionSafe: false),
      );
      expect(result.decision, ReleaseFragilityDecision.releaseBlocked);
      expect(result.earliestBlocker, ReleaseFragilityRiskId.widgetExtension);
    });

    test('widget needs review without TF block -> manualCheckNeeded', () {
      final result = ReleaseFragilityAudit.build(
        _input(
          signingConfigured: true,
          widgetExtensionSafe: true,
          widgetExtensionNeedsReview: true,
        ),
      );
      expect(result.decision, ReleaseFragilityDecision.manualCheckNeeded);
      expect(
        _risk(result, ReleaseFragilityRiskId.widgetExtension).level,
        ReleaseFragilityRiskLevel.manualCheckNeeded,
      );
    });

    test('pending screenshots and TestFlight -> manualCheckNeeded', () {
      final result = ReleaseFragilityAudit.build(
        _input(
          signingConfigured: true,
          screenshotsReady: null,
          testFlightUploaded: null,
        ),
      );
      expect(result.decision, ReleaseFragilityDecision.manualCheckNeeded);
      expect(
        _risk(result, ReleaseFragilityRiskId.screenshots).level,
        ReleaseFragilityRiskLevel.manualCheckNeeded,
      );
      expect(
        _risk(result, ReleaseFragilityRiskId.testFlightUpload).level,
        ReleaseFragilityRiskLevel.manualCheckNeeded,
      );
    });

    test('stale product copy -> releaseBlocked', () {
      final result = ReleaseFragilityAudit.build(
        _input(staleProductCopyRisk: true),
      );
      expect(result.decision, ReleaseFragilityDecision.releaseBlocked);
      expect(
        _risk(result, ReleaseFragilityRiskId.staleProductCopy).level,
        ReleaseFragilityRiskLevel.releaseBlocked,
      );
    });

    test('report exposes canonical copy', () {
      final report = ReleaseFragilityAudit.report(
        ReleaseFragilityAudit.build(_input()),
      );
      expect(report.headline, ReleaseFragilityCopy.headline);
      expect(report.guardrail, ReleaseFragilityCopy.guardrail);
      expect(report.orderLine, ReleaseFragilityCopy.orderLine);
    });
  });

  group('ReleaseFragilityAudit detectors', () {
    test('detectCanonicalBundleId rejects legacy bundle id', () {
      expect(
        ReleaseFragilityAudit.detectCanonicalBundleId(
          appConfigSource: "bundleId = 'com.voicememory.mobile'",
          pbxprojSource: 'PRODUCT_BUNDLE_IDENTIFIER = com.voicememory.app;',
        ),
        isFalse,
      );
    });

    test('detectAppStoreProductsConfigured requires expectedStoreProductIds', () {
      expect(
        ReleaseFragilityAudit.detectAppStoreProductsConfigured(
          "static const expectedStoreProductIds = ['archive_loop_pro_monthly'];",
        ),
        isTrue,
      );
      expect(
        ReleaseFragilityAudit.detectAppStoreProductsConfigured(
          "productId = 'archive_loop_pro_monthly'",
        ),
        isFalse,
      );
    });
  });

  group('ReleaseFragilityAudit.fromRepoSignals', () {
    late String appConfigSource;
    late String pbxprojSource;
    late String infoPlistSource;
    late String appRouterSource;
    late String securitySettingsSource;
    late String revenueCatServiceSource;
    late String revenueCatReleaseChecklistSource;
    late String revenueCatArchiveLoopLogsSource;
    late String revenueCatLiveProofRunnerSource;
    late String archiveLoopEntitlementIdsSource;
    late String proSinglePromiseCopySource;
    late String mobileLibAndDocsScanSource;
    late String revenueCatOfferingsDebugLogSource;
    late String deploySecretsCheckSource;
    late String envExampleSource;
    late String widgetPbxprojSource;
    late String runnerEntitlementsSource;
    late String extensionEntitlementsSource;
    late String objectiveWidgetStorageSwiftSource;
    late String todayCheckWidgetSwiftSource;
    late String widgetExporterDartSource;
    late String widgetPrepDocSource;

    setUpAll(() {
      appConfigSource = File('lib/config/app_config.dart').readAsStringSync();
      pbxprojSource = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      infoPlistSource = File('ios/Runner/Info.plist').readAsStringSync();
      appRouterSource = File('lib/router/app_router.dart').readAsStringSync();
      securitySettingsSource = File(
        'lib/screens/security_settings_screen.dart',
      ).readAsStringSync();
      revenueCatServiceSource = File(
        'lib/billing/revenuecat_service.dart',
      ).readAsStringSync();
      revenueCatReleaseChecklistSource = File(
        'docs/REVENUECAT_RELEASE_CHECKLIST.md',
      ).readAsStringSync();
      revenueCatArchiveLoopLogsSource = File(
        'lib/billing/revenuecat_archive_loop_logs.dart',
      ).readAsStringSync();
      revenueCatLiveProofRunnerSource = File(
        'lib/features/revenuecat_live_proof/revenuecat_live_proof_runner.dart',
      ).readAsStringSync();
      archiveLoopEntitlementIdsSource = File(
        'lib/billing/archive_loop_entitlement_ids.dart',
      ).readAsStringSync();
      proSinglePromiseCopySource = File(
        'lib/features/pro_single_promise/pro_single_promise_copy.dart',
      ).readAsStringSync();
      mobileLibAndDocsScanSource = _aggregateMobileLibAndDocs();
      revenueCatOfferingsDebugLogSource = File(
        'lib/billing/revenuecat_offerings_debug_log.dart',
      ).readAsStringSync();
      deploySecretsCheckSource = _readIfExists(
        '../../lib/server/deploy-secrets-check.ts',
      );
      envExampleSource = _readIfExists('../../.env.example');
      widgetPbxprojSource = pbxprojSource;
      runnerEntitlementsSource = File(
        'ios/Runner/Runner.entitlements',
      ).readAsStringSync();
      extensionEntitlementsSource = File(
        'ios/TodayCheckWidget/TodayCheckWidgetExtension.entitlements',
      ).readAsStringSync();
      objectiveWidgetStorageSwiftSource = File(
        'ios/Runner/ObjectiveWidgetStorage.swift',
      ).readAsStringSync();
      todayCheckWidgetSwiftSource = File(
        'ios/TodayCheckWidget/TodayCheckWidget.swift',
      ).readAsStringSync();
      widgetExporterDartSource = File(
        'lib/features/objective/current_objective_widget_exporter.dart',
      ).readAsStringSync();
      widgetPrepDocSource = File(
        'docs/WIDGET_SHORTCUT_PREP.md',
      ).readAsStringSync();
    });

    test('repo signals detect canonical bundle id and deployment target', () {
      expect(
        ReleaseFragilityAudit.detectCanonicalBundleId(
          appConfigSource: appConfigSource,
          pbxprojSource: pbxprojSource,
        ),
        isTrue,
      );
      expect(
        ReleaseFragilityAudit.detectIosDeploymentTargetAligned(
          pbxprojSource: pbxprojSource,
        ),
        isTrue,
      );
    });

    test(
      'fromRepoSignals -> manualCheckNeeded with pending manual evidence',
      () {
        final result = ReleaseFragilityAudit.build(
          ReleaseFragilityAudit.fromRepoSignals(
            appConfigSource: appConfigSource,
            pbxprojSource: pbxprojSource,
            infoPlistSource: infoPlistSource,
            appRouterSource: appRouterSource,
            securitySettingsSource: securitySettingsSource,
            revenueCatServiceSource: revenueCatServiceSource,
            revenueCatReleaseChecklistSource: revenueCatReleaseChecklistSource,
            revenueCatArchiveLoopLogsSource: revenueCatArchiveLoopLogsSource,
            revenueCatLiveProofRunnerSource: revenueCatLiveProofRunnerSource,
            archiveLoopEntitlementIdsSource: archiveLoopEntitlementIdsSource,
            proSinglePromiseCopySource: proSinglePromiseCopySource,
            mobileLibAndDocsScanSource: mobileLibAndDocsScanSource,
            revenueCatOfferingsDebugLogSource:
                revenueCatOfferingsDebugLogSource,
            deploySecretsCheckSource: deploySecretsCheckSource,
            envExampleSource: envExampleSource,
            widgetPbxprojSource: widgetPbxprojSource,
            runnerEntitlementsSource: runnerEntitlementsSource,
            extensionEntitlementsSource: extensionEntitlementsSource,
            objectiveWidgetStorageSwiftSource:
                objectiveWidgetStorageSwiftSource,
            todayCheckWidgetSwiftSource: todayCheckWidgetSwiftSource,
            widgetExporterDartSource: widgetExporterDartSource,
            widgetPrepDocSource: widgetPrepDocSource,
          ),
        );
        expect(result.decision, ReleaseFragilityDecision.manualCheckNeeded);
        expect(
          _risk(result, ReleaseFragilityRiskId.secrets).level,
          ReleaseFragilityRiskLevel.manualCheckNeeded,
        );
        expect(
          _risk(result, ReleaseFragilityRiskId.signing).level,
          ReleaseFragilityRiskLevel.manualCheckNeeded,
        );
        expect(
          _risk(result, ReleaseFragilityRiskId.screenshots).level,
          ReleaseFragilityRiskLevel.manualCheckNeeded,
        );
        expect(
          _risk(result, ReleaseFragilityRiskId.testFlightUpload).level,
          ReleaseFragilityRiskLevel.manualCheckNeeded,
        );
        expect(result.blockedCount, 0);
      },
    );

    test(
      'fromRepoSignals with manual evidence confirmed has no blocked risks',
      () {
        final result = ReleaseFragilityAudit.build(
          ReleaseFragilityAudit.fromRepoSignals(
            appConfigSource: appConfigSource,
            pbxprojSource: pbxprojSource,
            infoPlistSource: infoPlistSource,
            appRouterSource: appRouterSource,
            securitySettingsSource: securitySettingsSource,
            revenueCatServiceSource: revenueCatServiceSource,
            revenueCatReleaseChecklistSource: revenueCatReleaseChecklistSource,
            revenueCatArchiveLoopLogsSource: revenueCatArchiveLoopLogsSource,
            revenueCatLiveProofRunnerSource: revenueCatLiveProofRunnerSource,
            archiveLoopEntitlementIdsSource: archiveLoopEntitlementIdsSource,
            proSinglePromiseCopySource: proSinglePromiseCopySource,
            mobileLibAndDocsScanSource: mobileLibAndDocsScanSource,
            revenueCatOfferingsDebugLogSource:
                revenueCatOfferingsDebugLogSource,
            deploySecretsCheckSource: deploySecretsCheckSource,
            envExampleSource: envExampleSource,
            widgetPbxprojSource: widgetPbxprojSource,
            runnerEntitlementsSource: runnerEntitlementsSource,
            extensionEntitlementsSource: extensionEntitlementsSource,
            objectiveWidgetStorageSwiftSource:
                objectiveWidgetStorageSwiftSource,
            todayCheckWidgetSwiftSource: todayCheckWidgetSwiftSource,
            widgetExporterDartSource: widgetExporterDartSource,
            widgetPrepDocSource: widgetPrepDocSource,
            signingVerified: true,
            screenshotsReady: true,
            testFlightUploaded: true,
            stripeSecretKeyRotated: true,
            stripeWebhookSecretRotated: true,
            productionEnvUpdated: true,
            oldWebhookDisabled: true,
            vercelEnvProductionVerified: true,
          ),
        );
        expect(result.blockedCount, 0);
        expect(
          _risk(result, ReleaseFragilityRiskId.secrets).level,
          ReleaseFragilityRiskLevel.lowRisk,
        );
        expect(
          _risk(result, ReleaseFragilityRiskId.signing).level,
          ReleaseFragilityRiskLevel.lowRisk,
        );
        expect(
          _risk(result, ReleaseFragilityRiskId.widgetExtension).level,
          ReleaseFragilityRiskLevel.manualCheckNeeded,
        );
        expect(result.decision, ReleaseFragilityDecision.manualCheckNeeded);
      },
    );
  });

  group('protected regression', () {
    test('docs describe audit-only release fragility scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('release fragility'));
      expect(doc, contains('audit only'));
      expect(doc, contains('no product changes'));
    });

    test('guardrail forbids product changes', () {
      final guardrail = ReleaseFragilityCopy.guardrail.toLowerCase();
      expect(guardrail, contains('reports risks only'));
      expect(guardrail, contains('no product changes'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in ReleaseFragilityCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import billing SDK or purchases_flutter', () {
      for (final path in [
        'lib/features/release_fragility/release_fragility_audit.dart',
        'lib/features/release_fragility/release_fragility_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
      }
    });

    test('advice guard registers release fragility copy', () {
      final guardSource = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(guardSource, contains('ReleaseFragilityCopy.allVisibleStrings()'));
    });
  });
}
