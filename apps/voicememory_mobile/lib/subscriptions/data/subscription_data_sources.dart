import '../domain/subscription_models.dart';

abstract interface class SubscriptionStoreDataSource {
  SubscriptionAvailability get availability;

  Stream<SubscriptionState> get stateChanges;

  Future<SubscriptionState> refresh();

  Future<List<SubscriptionOffer>> loadOffers();

  Future<SubscriptionState> purchase(String offerId);

  Future<SubscriptionState> restore();

  Future<String?> updateIdentity(String? identity);

  Future<SubscriptionDiagnostics> loadDiagnostics();
}

abstract interface class SubscriptionRemoteDataSource {
  Future<SubscriptionState> fetchState();

  Future<SubscriptionCheckout> createCheckout();

  Future<void> linkStoreIdentity(String storeIdentity);
}

abstract interface class SubscriptionCacheDataSource {
  Future<SubscriptionState?> load();

  Future<void> save(SubscriptionState state);

  Future<void> clear();
}
