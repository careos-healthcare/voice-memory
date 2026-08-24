import 'package:archiveme_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:archiveme_mobile/billing/revenuecat_configuration.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/core/config/v1_billing_capability.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:flutter_test/flutter_test.dart';

const _iosKey = 'REVENUECAT_IOS_API_KEY';
const _androidKey = 'REVENUECAT_ANDROID_API_KEY';
const _fallbackKey = 'REVENUECAT_API_KEY';

void main() {
  late RevenueCatEnvReader originalReader;
  late Map<String, int> reads;

  setUp(() {
    originalReader = RevenueCatConfiguration.envReader;
    reads = <String, int>{};
    RevenueCatConfiguration.resetCacheForTest();
    RevenueCatConfiguration.envReader = (name, {defaultValue = ''}) {
      reads.update(name, (count) => count + 1, ifAbsent: () => 1);
      return defaultValue;
    };
  });

  tearDown(() {
    RevenueCatConfiguration.envReader = originalReader;
    RevenueCatConfiguration.resetCacheForTest();
  });

  test(
    'initialize reads RevenueCat env vars once and reuses the cached configuration',
    () async {
      expect(V1CapabilityRegistry.storeBilling, isFalse);

      await RevenueCatService.instance.initialize();

      expect(reads[_iosKey], 1);
      expect(reads[_androidKey], 1);
      expect(reads[_fallbackKey], 1);

      final first = RevenueCatConfiguration.current;

      await RevenueCatService.instance.initialize();
      final second = RevenueCatConfiguration.current;

      expect(reads[_iosKey], 1);
      expect(reads[_androidKey], 1);
      expect(reads[_fallbackKey], 1);
      expect(identical(first, second), isTrue);
      expect(RevenueCatService.instance.isConfigured, isFalse);
    },
  );

  test(
    'storeBilling off wins over REVENUECAT_PURCHASES_ENABLED for product enable',
    () async {
      expect(V1CapabilityRegistry.storeBilling, isFalse);
      expect(V1BillingCapability.isEnabled, isFalse);
      // Env default (and load()) still report purchases as config-enabled.
      expect(RevenueCatConfiguration.purchasesEnabledAtBuildTime, isTrue);

      final config = RevenueCatConfiguration(
        iosPublicSdkKey: 'appl_spy_ios',
        androidPublicSdkKey: 'goog_spy_android',
        entitlementId: ArchiveLoopEntitlementIds.archiveLoopPro,
        environment: RevenueCatBuildEnvironment.development,
        purchasesEnabled: true,
      );
      expect(config.purchasesEnabled, isTrue);

      await RevenueCatService.instance.initialize(configuration: config);

      expect(V1BillingCapability.isEnabled, isFalse);
      expect(RevenueCatService.instance.isConfigured, isFalse);
    },
  );
}
