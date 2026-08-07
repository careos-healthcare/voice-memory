import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:voicememory_mobile/billing/billing_service.dart';
import 'package:voicememory_mobile/billing/store_billing_port.dart';
import 'package:voicememory_mobile/core/di/network_providers.dart';
import 'package:voicememory_mobile/core/network/http_transport.dart';
import 'package:voicememory_mobile/core/network/network_cancel_token.dart';
import 'package:voicememory_mobile/data/network/http_billing_api_client.dart';
import 'package:voicememory_mobile/data/repositories/billing_repository.dart';
import 'package:voicememory_mobile/features/billing/application/billing_notifier.dart';
import 'package:voicememory_mobile/models/entitlement.dart';
import 'package:voicememory_mobile/storage/entitlement_cache.dart';

/// Builds a [BillingService] backed by Riverpod for unit/widget tests.
BillingService createBillingServiceWithTestOverrides({
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
