import 'subscription_models.dart';

abstract interface class SubscriptionRepository {
  SubscriptionState? get currentState;

  Stream<SubscriptionState> watchState();

  Future<SubscriptionState?> hydrateFromCache();

  Future<SubscriptionState?> loadCachedState();

  Future<SubscriptionState> refresh({bool force = false});

  Future<List<SubscriptionOffer>> loadOffers();

  Future<SubscriptionState> purchase(String offerId);

  Future<SubscriptionState> restore();

  Future<SubscriptionCheckout> createCheckout();

  Future<void> updateIdentity(String? identity);

  Future<void> resetForAuthChange();

  SubscriptionAvailability get availability;

  Future<SubscriptionDiagnostics> loadDiagnostics();

  void start();

  Future<void> stop();

  Future<void> dispose();
}
