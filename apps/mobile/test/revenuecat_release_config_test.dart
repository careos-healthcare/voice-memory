import 'package:archiveme_mobile/billing/revenuecat_diagnostics_log.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/core/config/v1_billing_capability.dart';
import 'package:archiveme_mobile/config/release_config.dart';
import 'package:archiveme_mobile/config/trial_mode.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:flutter_test/flutter_test.dart';

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
}