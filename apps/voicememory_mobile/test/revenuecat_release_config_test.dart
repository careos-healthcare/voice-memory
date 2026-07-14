import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/revenuecat_diagnostics_log.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/config/release_config.dart';
import 'package:voicememory_mobile/config/trial_mode.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

void main() {
  test('pro entitlement id is pro', () {
    expect(RevenueCatService.proEntitlementId, 'pro');
  });

  test('missing RevenueCat key does not crash initialize', () async {
    final rc = RevenueCatService.instance;
    await rc.initialize();
    expect(rc.isConfigured, isFalse);
  });

  test('trial mode skips billing requirement', () {
    if (TrialMode.enabled) {
      expect(ReleaseConfig.billingRequired, isFalse);
      expect(TrialMode.isLocalOnly, isTrue);
    } else {
      expect(ReleaseConfig.billingRequired, isTrue);
    }
  });

  test('paywall shows safe message when billing not configured', () {
    expect(
      ConsumerUiCopy.paywallBillingNotConfigured,
      contains('Purchases are not available right now'),
    );
    expect(
      ConsumerUiCopy.paywallSetupUnavailableBody,
      'Purchases are not available right now.',
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
      RevenueCatDiagnosticsLog.keyFingerprint('appl_pOUlWdiVXlWpFLvaZscgayWhfpH'),
      'appl_pOU…',
    );
  });
}
