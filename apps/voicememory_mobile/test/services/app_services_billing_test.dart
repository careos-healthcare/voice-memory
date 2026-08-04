import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/billing_platform.dart';
import 'package:voicememory_mobile/models/entitlement.dart';
import 'package:voicememory_mobile/services/app_services.dart';

class _TrackedBillingPlatform extends Fake implements BillingPlatform {
  int initializeCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<PremiumEntitlements> get entitlementStream =>
      const Stream<PremiumEntitlements>.empty();

  @override
  bool get isConfigured => false;

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  void dispose() {
    disposeCalls++;
  }
}

void main() {
  test(
    'AppServices owns injected billing platform and disposes it once',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'app_services_billing_test',
      );
      addTearDown(() async {
        await AppServices.disposeForTest();
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final billingPlatform = _TrackedBillingPlatform();

      await AppServices.resetForTest(
        journalPath: '${directory.path}/journal.json',
        billingPlatform: billingPlatform,
        skipRevenueCat: true,
      );

      expect(AppServices.instance.billingPlatform, same(billingPlatform));
      expect(billingPlatform.initializeCalls, 0);

      await AppServices.disposeForTest();
      await AppServices.disposeForTest();

      expect(billingPlatform.disposeCalls, 1);
    },
  );
}
