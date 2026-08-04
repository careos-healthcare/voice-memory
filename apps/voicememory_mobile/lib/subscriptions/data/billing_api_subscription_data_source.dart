import '../../api/api_exceptions.dart';
import '../../api/billing_api_client.dart';
import '../domain/subscription_models.dart';
import 'legacy_subscription_mapper.dart';
import 'subscription_data_sources.dart';

class BillingApiSubscriptionDataSource implements SubscriptionRemoteDataSource {
  const BillingApiSubscriptionDataSource(this._api);

  final BillingApiClient _api;

  @override
  Future<SubscriptionState> fetchState() async {
    try {
      final value = await _api.getEntitlements();
      return LegacySubscriptionMapper.fromEntitlements(
        value,
      ).copyWith(origin: SubscriptionStateOrigin.backend);
    } on AuthRequiredException {
      throw const SubscriptionAuthRequiredException();
    }
  }

  @override
  Future<SubscriptionCheckout> createCheckout() async {
    try {
      final value = await _api.createCheckoutSession();
      return SubscriptionCheckout(url: value.url, sessionId: value.sessionId);
    } on AuthRequiredException {
      throw const SubscriptionAuthRequiredException();
    }
  }

  @override
  Future<void> linkStoreIdentity(String storeIdentity) async {
    try {
      await _api.linkRevenueCatAppUserId(storeIdentity);
    } on AuthRequiredException {
      throw const SubscriptionAuthRequiredException();
    }
  }
}
