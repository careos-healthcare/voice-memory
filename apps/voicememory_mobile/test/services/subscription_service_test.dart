import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_models.dart';
import 'package:voicememory_mobile/api/billing_api_client.dart';
import 'package:voicememory_mobile/services/subscription_service.dart';

void main() {
  test('reads active subscription from server status endpoint', () async {
    final service = SubscriptionService(
      _BillingApi(active: true),
      useWebCheckout: false,
    );

    expect(await service.hasActiveSubscription(), isTrue);
  });

  test('opens an HTTPS Stripe checkout in the external browser', () async {
    Uri? opened;
    final service = SubscriptionService(
      _BillingApi(active: false),
      useWebCheckout: true,
      allowIosWebCheckout: true,
      allowAndroidWebCheckout: true,
      launchExternal: (uri) async {
        opened = uri;
        return true;
      },
    );

    expect(await service.openCheckout(), isTrue);
    expect(opened, Uri.parse('https://checkout.stripe.com/c/pay_test'));
  });

  test('rejects web checkout when the global flag is disabled', () async {
    final service = SubscriptionService(
      _BillingApi(active: false),
      useWebCheckout: false,
    );

    expect(service.canOfferWebCheckout, isFalse);
    expect(service.createCheckoutUri, throwsStateError);
  });
}

final class _BillingApi implements BillingApiClient {
  _BillingApi({required this.active});

  final bool active;

  @override
  Future<SubscriptionStatusResponse> getSubscriptionStatus() async =>
      SubscriptionStatusResponse(
        hasActiveSubscription: active,
        subscriptionStatus: active ? 'active' : 'inactive',
      );

  @override
  Future<CheckoutSession> createCheckoutSession() async =>
      const CheckoutSession(
        url: 'https://checkout.stripe.com/c/pay_test',
        sessionId: 'cs_test',
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
