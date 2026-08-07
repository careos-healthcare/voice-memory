import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:purchases_flutter/purchases_flutter.dart';

import '../billing/store_billing_port.dart';
import '../core/di/network_providers.dart';
import '../core/network/http_transport.dart';
import '../core/network/network_cancel_token.dart';
import '../data/network/http_billing_api_client.dart';
import '../data/repositories/billing_repository.dart';
import '../features/billing/application/billing_notifier.dart';
import '../models/entitlement.dart';
import '../storage/entitlement_cache.dart';
import '../billing/billing_service.dart';

/// Builds a [BillingService] backed by Riverpod for unit/widget tests.
BillingService createBillingServiceForTest({
  required EntitlementCache cache,
  required StoreBillingPort revenueCat,
  http.Client? httpClient,
  BillingRepository? repository,
}) {
  final client = httpClient ?? http.Client();
  final scope = NetworkRequestScope();
  final container = ProviderContainer(
    overrides: [
      entitlementCacheHolderProvider.overrideWithValue(
        EntitlementCacheHolder()..value = cache,
      ),
      storeBillingPortProvider.overrideWithValue(revenueCat),
      billingRepositoryProvider.overrideWithValue(
        repository ??
            BillingRepository(
              api: HttpBillingApiClient(HttpTransport(client: client)),
              requestScope: scope,
            ),
      ),
    ],
  );
  return BillingService(container.read(billingProvider.notifier));
}

Future<PremiumEntitlements> purchaseNativeViaTestBilling(
  BillingService billing,
  Package package,
) {
  return billing.purchaseNative(package);
}
