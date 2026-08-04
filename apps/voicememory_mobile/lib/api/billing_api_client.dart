import '../models/entitlement.dart';
import 'api_exceptions.dart';
import 'api_models.dart';
import 'api_transport.dart';

class BillingApiClient {
  BillingApiClient(this.transport);

  final ApiTransport transport;

  Future<PremiumEntitlements> getEntitlements() async {
    final response = await transport.get('/api/billing/entitlements');
    return PremiumEntitlements.fromJson(transport.decodeJson(response));
  }

  Future<SubscriptionStatusResponse> getSubscriptionStatus() async {
    final response = await transport.get('/api/user/subscription-status');
    return SubscriptionStatusResponse.fromJson(transport.decodeJson(response));
  }

  Future<void> linkRevenueCatAppUserId(String appUserId) async {
    await transport.postJson(
      '/api/billing/revenuecat/link',
      body: {'appUserId': appUserId},
    );
  }

  Future<CheckoutSession> createCheckoutSession() async {
    final response = await transport.postJson('/api/billing/checkout');
    final body = transport.decodeJson(response);
    final url = body['url'] as String?;
    if (url == null || url.isEmpty) {
      throw ApiException(
        'Checkout URL missing',
        statusCode: response.statusCode,
      );
    }
    return CheckoutSession(url: url, sessionId: body['sessionId'] as String?);
  }

  Future<PremiumEntitlements> restorePurchases() async {
    final response = await transport.postJson('/api/billing/restore');
    final body = transport.decodeJson(response);
    final nested = body['entitlements'];
    return PremiumEntitlements.fromJson(
      nested is Map ? Map<String, dynamic>.from(nested) : body,
    );
  }
}
