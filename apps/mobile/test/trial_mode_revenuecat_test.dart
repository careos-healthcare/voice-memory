import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/config/release_config.dart';
import 'package:archiveme_mobile/config/trial_mode.dart';
import 'package:archiveme_mobile/core/config/v1_billing_capability.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _resetTrial(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_trial_rc_journal_$stamp.json',
    prefsPath: '/tmp/vm_trial_rc_prefs_$stamp.json',
  );
}

void main() {
  test(
    'missing RevenueCat key leaves service unconfigured without crash',
    () async {
      final rc = RevenueCatService.instance;
      await rc.initialize();
      expect(rc.isConfigured, isFalse);
    },
  );

  test('billing requirement follows capability registry', () {
    if (V1BillingCapability.isEnabled && !TrialMode.isLocalOnly) {
      expect(ReleaseConfig.billingRequired, isTrue);
    } else {
      expect(ReleaseConfig.billingRequired, isFalse);
    }
    if (TrialMode.enabled) {
      expect(TrialMode.isLocalOnly, isTrue);
    }
  });

  test('paywall surfaces clear message when billing not configured', () {
    expect(
      ConsumerUiCopy.paywallBillingNotConfigured,
      contains('not available right now'),
    );
  });

  test(
    'trial reset initializes app services without RevenueCat configure',
    () async {
      if (!TrialMode.enabled) return;
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetTrial(stamp);
      expect(AppServices.isInitialized, isTrue);
      expect(RevenueCatService.instance.isConfigured, isFalse);
    },
  );
}