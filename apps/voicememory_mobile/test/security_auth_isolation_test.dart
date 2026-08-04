import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/subscriptions/data/default_subscription_repository.dart';
import 'package:voicememory_mobile/subscriptions/data/subscription_data_sources.dart';
import 'package:voicememory_mobile/subscriptions/domain/subscription_models.dart';

void main() {
  test('auth reset clears cached subscription state', () async {
    final cache = _Cache(
      const SubscriptionState(
        tier: SubscriptionTier.pro,
        entitlementIds: [SubscriptionEntitlements.pro],
        billingConnected: true,
        origin: SubscriptionStateOrigin.cache,
      ),
    );
    final repository = DefaultSubscriptionRepository(
      _Store(),
      _Remote(),
      cache,
    );
    await repository.hydrateFromCache();
    expect(repository.currentState?.isPro, isTrue);

    await repository.resetForAuthChange();

    expect(cache.value, isNull);
    expect(repository.currentState?.isPro, isFalse);
  });
}

class _Cache implements SubscriptionCacheDataSource {
  _Cache(this.value);
  SubscriptionState? value;

  @override
  Future<void> clear() async => value = null;
  @override
  Future<SubscriptionState?> load() async => value;
  @override
  Future<void> save(SubscriptionState state) async => value = state;
}

class _Store implements SubscriptionStoreDataSource {
  @override
  SubscriptionAvailability get availability =>
      SubscriptionAvailability.notConfigured;
  @override
  Future<SubscriptionDiagnostics> loadDiagnostics() async =>
      const SubscriptionDiagnostics(
        availability: SubscriptionAvailability.notConfigured,
      );
  @override
  Future<List<SubscriptionOffer>> loadOffers() async => const [];
  @override
  Future<SubscriptionState> purchase(String offerId) =>
      throw UnimplementedError();
  @override
  Future<SubscriptionState> refresh() async => SubscriptionState.free();
  @override
  Future<SubscriptionState> restore() => throw UnimplementedError();
  @override
  Stream<SubscriptionState> get stateChanges => const Stream.empty();
  @override
  Future<String?> updateIdentity(String? identity) async => identity;
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
