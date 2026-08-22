import 'dart:io';

import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/config/release_config.dart';
import 'package:archiveme_mobile/core/config/v1_billing_capability.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/config/v1_production_allowlist.dart';
import 'package:archiveme_mobile/features/release_evidence/release_evidence_pack.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/router/production_billing_import_gate.dart';
import 'package:archiveme_mobile/router/production_route_link_gate.dart';
import 'package:archiveme_mobile/router/v1_route_registry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('focused beta billing capability is disabled in registry', () {
    expect(V1CapabilityRegistry.storeBilling, isFalse);
    expect(V1BillingCapability.isEnabled, isFalse);
    expect(V1BillingCapability.isProductionReachable, isFalse);
    expect(ReleaseConfig.billingRequired, isFalse);
  });

  test('production allowlist excludes billing screens and paid capability', () {
    expect(
      V1ProductionAllowlist.productionRouterScreens,
      isNot(contains('PaywallScreen')),
    );
    expect(
      V1ProductionAllowlist.productionRouterScreens,
      isNot(contains('PricingScreen')),
    );
    expect(
      V1ProductionAllowlist.productionRouterScreens,
      isNot(contains('RestorePurchasesScreen')),
    );
    expect(
      V1ProductionAllowlist.productionRouterScreens,
      isNot(contains('RevenueCatVerificationScreen')),
    );
    expect(
      V1ProductionAllowlist.launchCapabilities,
      contains('free_beta_unlimited_local_archive'),
    );
    expect(
      V1ProductionAllowlist.launchCapabilities,
      isNot(contains('optional_paid_deeper_history')),
    );
  });

  test('billing routes are quarantined not allowlisted', () {
    expect(V1RouteRegistry.paidPaths, isEmpty);
    for (final path in [
      '/subscription',
      '/pricing',
      '/restore-purchases',
    ]) {
      expect(V1RouteRegistry.quarantinedExactPaths, contains(path));
    }
  });

  test('release evidence pack excludes purchase proof when billing disabled', () {
    expect(
      ReleaseEvidencePack.requiredEvidenceItems,
      isNot(contains(ReleaseEvidenceItem.sandboxPurchase)),
    );
    expect(
      ReleaseEvidencePack.requiredEvidenceItems,
      contains(ReleaseEvidenceItem.voiceSavePath),
    );
  });

  test('consumer production graph has no billing imports or CTAs', () {
    final root = Directory.current.path.endsWith('apps/mobile')
        ? Directory.current.path
        : '${Directory.current.path}/apps/mobile';
    final failures = [
      ...ProductionRouteLinkGate.validateActiveProductionGraph(root),
      ...ProductionBillingImportGate.validateConsumerProductionGraph(root),
    ];
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('RevenueCat initialize is inert when billing capability disabled', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await AppServices.resetForTest(
      journalPath: '/tmp/vm_billing_frozen_journal_$stamp.json',
      prefsPath: '/tmp/vm_billing_frozen_prefs_$stamp.json',
      skipRevenueCat: true,
    );
    await RevenueCatService.instance.initialize();
    expect(RevenueCatService.instance.isConfigured, isFalse);
  });

  test('free beta policy copy replaces paid-limit messaging', () {
    expect(
      ConsumerUiCopy.freeBetaUnlimitedLocalArchive,
      contains('no moment cap'),
    );
    expect(
      ConsumerUiCopy.freeBetaNoPaidLimits,
      contains('without a subscription'),
    );
  });
}
