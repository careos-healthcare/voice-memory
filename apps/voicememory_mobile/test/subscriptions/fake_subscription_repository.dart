import 'dart:async';

import 'package:voicememory_mobile/subscriptions/domain/subscription_models.dart';
import 'package:voicememory_mobile/subscriptions/domain/subscription_repository.dart';

class FakeSubscriptionRepository implements SubscriptionRepository {
  FakeSubscriptionRepository({
    SubscriptionState? state,
    this.availability = SubscriptionAvailability.available,
    this.offers = const [],
    this.purchaseResult,
    this.purchaseError,
    this.restoreResult,
    this.restoreError,
  }) : state = state ?? SubscriptionState.free();

  SubscriptionState state;
  final List<SubscriptionOffer> offers;
  final SubscriptionState? purchaseResult;
  final Object? purchaseError;
  final SubscriptionState? restoreResult;
  final Object? restoreError;
  @override
  final SubscriptionAvailability availability;
  int refreshCalls = 0;
  int purchaseCalls = 0;
  int restoreCalls = 0;
  final List<String> purchasedOfferIds = [];
  final StreamController<SubscriptionState> _states =
      StreamController<SubscriptionState>.broadcast();

  @override
  SubscriptionState get currentState => state;

  @override
  Future<SubscriptionCheckout> createCheckout() async =>
      const SubscriptionCheckout(url: 'https://example.test/checkout');

  @override
  Future<void> dispose() => _states.close();

  @override
  Future<SubscriptionState?> hydrateFromCache() async => state;

  @override
  Future<List<SubscriptionOffer>> loadOffers() async => offers;

  @override
  Future<SubscriptionState?> loadCachedState() async => state;

  @override
  Future<SubscriptionDiagnostics> loadDiagnostics() async =>
      SubscriptionDiagnostics(
        availability: availability,
        offersLoaded: offers.isNotEmpty,
        offerCount: offers.length,
      );

  @override
  Future<SubscriptionState> purchase(String offerId) async {
    purchaseCalls++;
    purchasedOfferIds.add(offerId);
    if (purchaseError case final error?) throw error;
    state = purchaseResult ?? state;
    _states.add(state);
    return state;
  }

  @override
  Future<SubscriptionState> refresh({bool force = false}) async {
    refreshCalls++;
    return state;
  }

  @override
  Future<void> resetForAuthChange() async {}

  @override
  Future<SubscriptionState> restore() async {
    restoreCalls++;
    if (restoreError case final error?) throw error;
    state = restoreResult ?? state;
    _states.add(state);
    return state;
  }

  @override
  void start() {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> updateIdentity(String? identity) async {}

  @override
  Stream<SubscriptionState> watchState() async* {
    yield state;
    yield* _states.stream;
  }
}
