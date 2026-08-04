import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/revenuecat_configuration.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/router/app_router.dart';
import 'package:voicememory_mobile/subscriptions/domain/subscription_models.dart';

const _monthly = SubscriptionOffer(
  id: 'monthly',
  productIdentifier: 'com.voicememory.app.pro.monthly',
  price: r'$4.99',
  period: SubscriptionPeriod.monthly,
);
const _yearly = SubscriptionOffer(
  id: 'yearly',
  productIdentifier: 'com.voicememory.app.pro.annual',
  price: r'$39.99',
  period: SubscriptionPeriod.annual,
);

RevenueCatConfiguration _configuration({
  String iosKey = 'appl_public_sdk_key',
  String androidKey = 'goog_public_sdk_key',
  bool enabled = true,
}) => RevenueCatConfiguration(
  iosPublicSdkKey: iosKey,
  androidPublicSdkKey: androidKey,
  entitlementId: 'archive_loop_pro',
  monthlyProductIdentifier: 'com.voicememory.app.pro.monthly',
  yearlyProductIdentifier: 'com.voicememory.app.pro.annual',
  environment: RevenueCatBuildEnvironment.production,
  purchasesEnabled: enabled,
);

void main() {
  test('paid platform configuration accepts public SDK keys', () {
    final configuration = _configuration();

    expect(configuration.validationErrorsFor(RevenueCatPlatform.ios), isEmpty);
    expect(
      configuration.validationErrorsFor(RevenueCatPlatform.android),
      isEmpty,
    );
  });

  test('paid build configuration rejects missing or malformed keys', () {
    expect(
      _configuration(iosKey: '').validationErrorsFor(RevenueCatPlatform.ios),
      contains('missing_public_sdk_key'),
    );
    expect(
      _configuration(
        androidKey: 'appl_wrong_platform',
      ).validationErrorsFor(RevenueCatPlatform.android),
      contains('malformed_public_sdk_key'),
    );
    expect(
      _configuration(
        iosKey: 'sk_secret',
      ).validationErrorsFor(RevenueCatPlatform.ios),
      contains('secret_key_forbidden'),
    );
  });

  test('explicitly free configuration does not require store keys', () {
    expect(
      _configuration(
        iosKey: '',
        androidKey: '',
        enabled: false,
      ).validationErrorsFor(RevenueCatPlatform.ios),
      isEmpty,
    );
  });

  test('valid offering requires exact monthly and yearly products', () {
    final result = _configuration().validateOffers(const [
      _monthly,
      _yearly,
    ], offeringExists: true);

    expect(result.isValid, isTrue);
  });

  test(
    'paid configuration requires monthly and yearly product identifiers',
    () {
      final configuration = RevenueCatConfiguration(
        iosPublicSdkKey: 'appl_public_sdk_key',
        androidPublicSdkKey: 'goog_public_sdk_key',
        entitlementId: 'archive_loop_pro',
        environment: RevenueCatBuildEnvironment.production,
        purchasesEnabled: true,
      );

      expect(
        configuration.validationErrorsFor(RevenueCatPlatform.ios),
        containsAll([
          'missing_monthly_product_id',
          'missing_yearly_product_id',
        ]),
      );
    },
  );

  test('missing offering and packages are rejected', () {
    expect(
      _configuration().validateOffers(const [], offeringExists: false).code,
      'missing_current_offering',
    );
    expect(
      _configuration().validateOffers(const [
        _yearly,
      ], offeringExists: true).code,
      'missing_monthly_package',
    );
    expect(
      _configuration().validateOffers(const [
        _monthly,
      ], offeringExists: true).code,
      'missing_yearly_package',
    );
  });

  test('product identifier mismatch is rejected', () {
    const wrongMonthly = SubscriptionOffer(
      id: 'monthly',
      productIdentifier: 'wrong.monthly.product',
      price: r'$4.99',
      period: SubscriptionPeriod.monthly,
    );

    expect(
      _configuration().validateOffers(const [
        wrongMonthly,
        _yearly,
      ], offeringExists: true).code,
      'monthly_product_mismatch',
    );
  });

  test('purchase build flag controls every subscription route', () {
    final paths = <String>[
      for (final route in appRouter.configuration.routes)
        if (route is GoRoute) route.path,
    ];
    const purchaseRoutes = {'/pricing', '/subscription', '/restore-purchases'};

    if (RevenueCatConfiguration.purchasesEnabledAtBuildTime) {
      expect(paths, containsAll(purchaseRoutes));
    } else {
      expect(paths.where(purchaseRoutes.contains), isEmpty);
    }
  });

  test('restore requires the currently configured RevenueCat identity', () {
    expect(
      RevenueCatService.identityAllowsRestore(
        'signed-in-user',
        'signed-in-user',
      ),
      isTrue,
    );
    expect(
      RevenueCatService.identityAllowsRestore(
        'anonymous-user',
        'signed-in-user',
      ),
      isFalse,
    );
  });
}
