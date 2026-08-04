import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:voicememory_mobile/billing/billing_platform.dart';
import 'package:voicememory_mobile/billing/revenuecat_configuration.dart';
import 'package:voicememory_mobile/billing/revenuecat_diagnostics.dart';
import 'package:voicememory_mobile/models/entitlement.dart';
import 'package:voicememory_mobile/subscriptions/data/default_subscription_repository.dart';
import 'package:voicememory_mobile/subscriptions/data/revenuecat_subscription_data_source.dart';
import 'package:voicememory_mobile/subscriptions/data/subscription_data_sources.dart';
import 'package:voicememory_mobile/subscriptions/domain/subscription_models.dart';

const _pro = PremiumEntitlements(
  tier: BillingTier.pro,
  entitlementIds: ['archive_loop_pro'],
  billingConnected: true,
  source: 'revenuecat',
);

const _free = PremiumEntitlements(
  tier: BillingTier.free,
  entitlementIds: [],
  billingConnected: true,
  source: 'revenuecat',
);

class _FakeBillingPlatform implements BillingPlatform {
  _FakeBillingPlatform(this.value, {this.offerings});

  PremiumEntitlements value;
  Offerings? offerings;
  final StreamController<PremiumEntitlements> _controller =
      StreamController<PremiumEntitlements>.broadcast();
  bool disposed = false;

  void emit(PremiumEntitlements next) {
    value = next;
    _controller.add(next);
  }

  @override
  bool get apiKeyMissing => false;

  @override
  RevenueCatDiagnostics get diagnostics => RevenueCatDiagnostics.initial();

  @override
  Stream<PremiumEntitlements> get entitlementStream => _controller.stream;

  @override
  bool get isConfigured => true;

  @override
  PremiumEntitlements get latestEntitlements => value;

  @override
  Future<Offerings?> fetchOfferings() async => offerings;

  @override
  Future<String?> getAppUserId() async => 'fake-user';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> logIn(String appUserId) async {}

  @override
  Future<void> logOut() async {}

  @override
  Future<PremiumEntitlements> purchasePackage(Package package) async => value;

  @override
  Future<PremiumEntitlements> refreshEntitlements() async => value;

  @override
  Future<PremiumEntitlements> restorePurchases() async => value;

  @override
  Future<PremiumEntitlements> syncAndRefreshEntitlements() async => value;

  @override
  void dispose() {
    if (disposed) return;
    disposed = true;
    _controller.close();
  }
}

Package _package(
  String id,
  PackageType type,
  String localizedPrice, {
  IntroductoryPrice? intro,
}) => Package(
  id,
  type,
  StoreProduct(
    id,
    '$id description',
    '$id title',
    12,
    localizedPrice,
    'EUR',
    introductoryPrice: intro,
  ),
  const PresentedOfferingContext('current', null, null),
);

Offerings _offerings(List<Package> packages) {
  final offering = Offering('current', 'Current', const {}, packages);
  return Offerings({'current': offering}, current: offering);
}

class _Remote implements SubscriptionRemoteDataSource {
  @override
  Future<SubscriptionCheckout> createCheckout() async =>
      const SubscriptionCheckout(url: 'https://example.test');

  @override
  Future<SubscriptionState> fetchState() async => SubscriptionState.free();

  @override
  Future<void> linkStoreIdentity(String storeIdentity) async {}
}

class _Cache implements SubscriptionCacheDataSource {
  SubscriptionState? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<SubscriptionState?> load() async => value;

  @override
  Future<void> save(SubscriptionState state) async => value = state;
}

void main() {
  test(
    'current offering exposes only monthly and annual localized offers',
    () async {
      final platform = _FakeBillingPlatform(
        _free,
        offerings: _offerings([
          _package('month', PackageType.monthly, '€4,99'),
          _package(
            'year',
            PackageType.annual,
            '€39,99',
            intro: const IntroductoryPrice(
              0,
              '€0,00',
              'P7D',
              1,
              PeriodUnit.day,
              7,
            ),
          ),
          _package('legacy', PackageType.lifetime, '€89,99'),
        ]),
      );
      addTearDown(platform.dispose);

      final offers = await RevenueCatSubscriptionDataSource(
        billingPlatform: platform,
      ).loadOffers();

      expect(offers.map((offer) => offer.period), [
        SubscriptionPeriod.monthly,
        SubscriptionPeriod.annual,
      ]);
      expect(offers.map((offer) => offer.price), ['€4,99', '€39,99']);
      expect(offers.last.introductoryDisplay, 'Free for P7D');
      expect(
        RevenueCatSubscriptionDataSource.isCurrentSubscriptionPackage(
          PackageType.lifetime,
        ),
        isFalse,
      );
    },
  );

  test('missing required package makes current offering unavailable', () async {
    final platform = _FakeBillingPlatform(
      _free,
      offerings: _offerings([_package('month', PackageType.monthly, '€4,99')]),
    );
    addTearDown(platform.dispose);

    expect(
      RevenueCatSubscriptionDataSource(billingPlatform: platform).loadOffers(),
      throwsA(
        isA<RevenueCatOfferingConfigurationException>().having(
          (error) => error.code,
          'code',
          'missing_yearly_package',
        ),
      ),
    );
  });

  test(
    'injected billing platforms keep data sources and repositories isolated',
    () async {
      final proPlatform = _FakeBillingPlatform(_pro);
      final freePlatform = _FakeBillingPlatform(_free);
      addTearDown(proPlatform.dispose);
      addTearDown(freePlatform.dispose);

      final proSource = RevenueCatSubscriptionDataSource(
        billingPlatform: proPlatform,
      );
      final freeSource = RevenueCatSubscriptionDataSource(
        billingPlatform: freePlatform,
      );
      final proEvents = <SubscriptionState>[];
      final freeEvents = <SubscriptionState>[];
      final proSubscription = proSource.stateChanges.listen(proEvents.add);
      final freeSubscription = freeSource.stateChanges.listen(freeEvents.add);
      addTearDown(proSubscription.cancel);
      addTearDown(freeSubscription.cancel);

      proPlatform.emit(_pro);
      await Future<void>.delayed(Duration.zero);

      expect(proEvents.single.isPro, isTrue);
      expect(freeEvents, isEmpty);

      final proRepository = DefaultSubscriptionRepository(
        proSource,
        _Remote(),
        _Cache(),
      );
      final freeRepository = DefaultSubscriptionRepository(
        freeSource,
        _Remote(),
        _Cache(),
      );
      addTearDown(proRepository.dispose);
      addTearDown(freeRepository.dispose);

      expect((await proRepository.refresh(force: true)).isPro, isTrue);
      expect((await freeRepository.refresh(force: true)).isPro, isFalse);
    },
  );
}
