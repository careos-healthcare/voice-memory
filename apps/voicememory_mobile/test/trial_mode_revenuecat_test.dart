import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/config/release_config.dart';
import 'package:voicememory_mobile/config/trial_mode.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';

Future<void> _resetTrial(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_trial_rc_journal_$stamp.json',
    prefsPath: '/tmp/vm_trial_rc_prefs_$stamp.json',
  );
}

void main() {
  test('missing RevenueCat key leaves service unconfigured without crash',
      () async {
    final rc = RevenueCatService.instance;
    await rc.initialize();
    expect(rc.isConfigured, isFalse);
  });

  test('trial local mode does not require billing', () {
    if (TrialMode.enabled) {
      expect(ReleaseConfig.billingRequired, isFalse);
      expect(TrialMode.isLocalOnly, isTrue);
    } else {
      expect(ReleaseConfig.billingRequired, isTrue);
    }
  });

  test('paywall surfaces clear message when billing not configured', () {
    expect(
      ConsumerUiCopy.paywallBillingNotConfigured,
      contains('not set up'),
    );
  });

  test('trial reset initializes app services without RevenueCat configure',
      () async {
    if (!TrialMode.enabled) return;
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _resetTrial(stamp);
    expect(AppServices.isInitialized, isTrue);
    expect(RevenueCatService.instance.isConfigured, isFalse);
  });
}
