import 'dart:io';

import 'package:archiveme_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:archiveme_mobile/billing/revenuecat_configuration.dart';
import 'package:archiveme_mobile/billing/revenuecat_diagnostics_log.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/core/config/v1_billing_capability.dart';
import 'package:archiveme_mobile/config/release_config.dart';
import 'package:archiveme_mobile/config/trial_mode.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:flutter_test/flutter_test.dart';

RevenueCatConfiguration _sdkKeyConfig({
  String ios = '',
  String android = '',
  String? fallback,
}) {
  return RevenueCatConfiguration(
    iosPublicSdkKey: ios,
    androidPublicSdkKey: android,
    fallbackPublicSdkKey: fallback,
    entitlementId: ArchiveLoopEntitlementIds.archiveLoopPro,
    environment: RevenueCatBuildEnvironment.development,
    purchasesEnabled: true,
  );
}

void main() {
  test('pro entitlement id is pro', () {
    expect(RevenueCatService.proEntitlementId, 'pro');
  });

  test('missing RevenueCat key does not crash initialize', () async {
    final rc = RevenueCatService.instance;
    await rc.initialize();
    expect(rc.isConfigured, isFalse);
  });

  test('billing requirement follows capability registry', () {
    if (V1BillingCapability.isEnabled && !TrialMode.isLocalOnly) {
      expect(ReleaseConfig.billingRequired, isTrue);
    } else {
      expect(ReleaseConfig.billingRequired, isFalse);
    }
  });

  test('paywall shows safe message when billing not configured', () {
    expect(
      ConsumerUiCopy.paywallBillingNotConfigured,
      contains('not available right now'),
    );
    expect(
      ConsumerUiCopy.paywallSetupUnavailableBody,
      'Plans are not available right now.',
    );
    expect(
      ConsumerUiCopy.paywallBillingNotConfigured.toLowerCase(),
      isNot(contains('revenuecat')),
    );
  });

  test('diagnostics expose QA fields when SDK not configured', () async {
    final rc = RevenueCatService.instance;
    await rc.initialize();
    final d = rc.diagnostics;
    expect(d.revenueCatConfigured, isFalse);
    expect(d.apiKeyMissing, isTrue);
    expect(d.offeringsLoaded, isFalse);
    expect(d.offeringCount, 0);
    expect(d.packageCount, 0);
  });

  test('diagnostics log key fingerprint never exposes full key', () {
    expect(RevenueCatDiagnosticsLog.keyFingerprint(null), 'missing');
    expect(RevenueCatDiagnosticsLog.keyFingerprint(''), 'missing');
    expect(
      RevenueCatDiagnosticsLog.keyFingerprint(
        'appl_pOUlWdiVXlWpFLvaZscgayWhfpH',
      ),
      'appl_pOU…',
    );
  });

  test('sdkKeyForConfigure prefers the platform key then the shared fallback', () {
    const ios = 'appl_ios_public';
    const android = 'goog_android_public';
    const fallback = 'appl_shared_fallback';
    final withPlatformKeys = _sdkKeyConfig(
      ios: ios,
      android: android,
      fallback: fallback,
    );
    expect(
      withPlatformKeys.sdkKeyForConfigure(RevenueCatPlatform.ios),
      ios,
    );
    expect(
      withPlatformKeys.sdkKeyForConfigure(RevenueCatPlatform.android),
      android,
    );

    final fallbackOnly = _sdkKeyConfig(fallback: fallback);
    expect(
      fallbackOnly.sdkKeyForConfigure(RevenueCatPlatform.ios),
      fallback,
    );
    expect(
      fallbackOnly.sdkKeyForConfigure(RevenueCatPlatform.android),
      fallback,
    );
    expect(
      fallbackOnly.sdkKeyForConfigure(RevenueCatPlatform.unsupported),
      fallback,
    );
    expect(_sdkKeyConfig().sdkKeyForConfigure(RevenueCatPlatform.ios), isNull);
  });

  test('initialize uses the injected configuration and skips configure without a key',
      () async {
    final rc = RevenueCatService.instance;
    await rc.initialize(configuration: _sdkKeyConfig());
    expect(rc.isConfigured, isFalse);
    expect(rc.diagnostics.apiKeyMissing, isTrue);
  });

  test('RevenueCat API keys are read once on the canonical configuration', () {
    const keys = [
      'REVENUECAT_IOS_API_KEY',
      'REVENUECAT_ANDROID_API_KEY',
      'REVENUECAT_API_KEY',
    ];
    final configurationSource = File(
      'lib/billing/revenuecat_configuration.dart',
    ).readAsStringSync();
    final serviceSource = File(
      'lib/billing/revenuecat_service.dart',
    ).readAsStringSync();

    expect(serviceSource, isNot(contains('fromEnvironment')));
    for (final key in keys) {
      expect(configurationSource.split("'$key'"), hasLength(2));
      expect(serviceSource, isNot(contains(key)));
    }
    expect(serviceSource, contains('configuration.sdkKeyForConfigure'));
  });
}