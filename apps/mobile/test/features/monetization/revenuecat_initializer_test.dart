import 'package:archiveme_mobile/features/monetization/revenuecat_constants.dart';
import 'package:archiveme_mobile/features/monetization/revenuecat_initializer.dart';
import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public key follows debug, sandbox, and production', () {
    expect(
      RevenueCatInitializer.publicApiKey(
        environment: RevenueCatRuntimeEnvironment.debug,
        ios: true,
        debugKey: 'appl_debug',
        sandboxKey: 'appl_sandbox',
        productionKey: 'appl_production',
        iosKey: 'appl_ios',
      ),
      'appl_debug',
    );
    expect(
      RevenueCatInitializer.publicApiKey(
        environment: RevenueCatRuntimeEnvironment.sandbox,
        ios: false,
        android: true,
        sandboxKey: 'goog_sandbox',
        androidKey: 'goog_android',
      ),
      'goog_sandbox',
    );
    expect(
      RevenueCatInitializer.publicApiKey(
        environment: RevenueCatRuntimeEnvironment.production,
        ios: true,
        iosKey: 'appl_ios',
      ),
      'appl_ios',
    );
    expect(
      RevenueCatInitializer.publicApiKey(
        environment: RevenueCatRuntimeEnvironment.debug,
        debugKey: 'sk_secret',
        fallbackKey: 'appl_fallback',
      ),
      isNull,
    );
  });

  test('configure is skipped when the SDK is already configured', () async {
    var calls = 0;
    final ready = await RevenueCatInitializer.ensureConfigured(
      apiKey: 'appl_test',
      readConfigured: () async => true,
      configure: (_) async {
        calls += 1;
      },
    );
    expect(ready, isTrue);
    expect(calls, 0);
  });

  test('configure runs once when the SDK is not configured', () async {
    final seen = <String>[];
    final ready = await RevenueCatInitializer.ensureConfigured(
      apiKey: 'appl_test',
      readConfigured: () async => false,
      configure: (configuration) async {
        seen.add(configuration.apiKey);
      },
    );
    expect(ready, isTrue);
    expect(seen, ['appl_test']);
  });

  test('a missing key does not call configure', () async {
    var calls = 0;
    final ready = await RevenueCatInitializer.ensureConfigured(
      apiKey: '   ',
      readConfigured: () async => false,
      configure: (_) async {
        calls += 1;
      },
    );
    expect(ready, isFalse);
    expect(calls, 0);
  });

  test('a configure failure does not throw', () async {
    final ready = await RevenueCatInitializer.ensureConfigured(
      apiKey: 'appl_test',
      readConfigured: () async => false,
      configure: (_) async {
        throw StateError('already configured');
      },
    );
    expect(ready, isFalse);
  });

  test('premium provider uses the dashboard entitlement ids', () {
    expect(PremiumEntitlementProvider.entitlementIds, [
      RevenueCatConstants.pro,
      RevenueCatConstants.archiveLoopPro,
    ]);
    expect(PremiumEntitlementProvider.offeringId, 'default');
    expect(RevenueCatConstants.monthlyProductId, 'archive_loop_pro_monthly');
    expect(RevenueCatConstants.yearlyProductId, 'archive_loop_pro_yearly');
  });
}
