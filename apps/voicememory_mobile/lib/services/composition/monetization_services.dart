// Named parameters cannot expose private field names.
// ignore_for_file: prefer_initializing_formals

import '../../billing/billing_platform.dart';
import '../../billing/revenuecat_service.dart';
import '../../billing/value_moment_paywall.dart';
import '../../features/monetization/data/monetization_local_migration.dart';
import '../../storage/entitlement_cache.dart';
import '../../subscriptions/data/billing_api_subscription_data_source.dart';
import '../../subscriptions/data/default_subscription_repository.dart';
import '../../subscriptions/data/entitlement_cache_subscription_data_source.dart';
import '../../subscriptions/data/revenuecat_subscription_data_source.dart';
import '../../subscriptions/data/subscription_data_sources.dart';
import '../../subscriptions/domain/subscription_repository.dart';
import 'core_services.dart';
import 'v1_composition_config.dart';

final class MonetizationServices {
  MonetizationServices._({
    required this.entitlementCache,
    required this.billingPlatform,
    required this.subscriptionStoreDataSource,
    required this.subscriptionRemoteDataSource,
    required this.subscriptionCacheDataSource,
    required this.subscriptionRepository,
    required this.paywall,
    required V1CompositionConfig config,
  }) : _config = config;

  final EntitlementCache entitlementCache;
  final BillingPlatform billingPlatform;
  final SubscriptionStoreDataSource subscriptionStoreDataSource;
  final SubscriptionRemoteDataSource subscriptionRemoteDataSource;
  final SubscriptionCacheDataSource subscriptionCacheDataSource;
  final SubscriptionRepository subscriptionRepository;
  final ValueMomentPaywallLogic paywall;

  final V1CompositionConfig _config;
  bool _activated = false;
  Future<void>? _activation;
  String? _accountScopeAwaitingRefresh;

  /// True once the billing SDK, cached entitlements and store subscription are
  /// live. Capture never waits on this.
  bool get isActivated => _activated;

  /// Constructs the commercial object graph without any billing SDK start-up,
  /// cache hydration or store subscription.
  ///
  /// Those are side-effectful and network-bound, and nothing on the capture
  /// path reads them, so they move to [activate].
  static Future<MonetizationServices> create(
    CoreServices core,
    V1CompositionConfig config,
  ) async {
    final entitlementCache = await EntitlementCache.open(
      '${config.basePath}/entitlements.json',
    );
    final billingPlatform = config.billingPlatform ?? RevenueCatService();
    final store =
        config.subscriptionStoreDataSource ??
        RevenueCatSubscriptionDataSource(billingPlatform: billingPlatform);
    final remote =
        config.subscriptionRemoteDataSource ??
        BillingApiSubscriptionDataSource(core.billingApi);
    final cache =
        config.subscriptionCacheDataSource ??
        EntitlementCacheSubscriptionDataSource(
          entitlementCache,
          MonetizationLocalMigration(core.prefs),
        );
    final repository =
        config.subscriptionRepository ??
        DefaultSubscriptionRepository(store, remote, cache);
    return MonetizationServices._(
      entitlementCache: entitlementCache,
      billingPlatform: billingPlatform,
      subscriptionStoreDataSource: store,
      subscriptionRemoteDataSource: remote,
      subscriptionCacheDataSource: cache,
      subscriptionRepository: repository,
      paywall: ValueMomentPaywallLogic(core.prefs),
      config: config,
    );
  }

  /// Everything [create] deliberately skipped. Runs after the first frame, or
  /// earlier if a commercial surface is opened first.
  Future<void> activate() async {
    if (_activated) return;
    final inFlight = _activation;
    if (inFlight != null) return inFlight;
    final future = _activate();
    _activation = future;
    try {
      await future;
      _activated = true;
    } finally {
      _activation = null;
    }
  }

  Future<void> _activate() async {
    if (!_config.skipBillingInitialization) {
      await billingPlatform.initialize();
    }
    await subscriptionRepository.hydrateFromCache();
    subscriptionRepository.start();
    final pending = _accountScopeAwaitingRefresh;
    if (pending != null) {
      _accountScopeAwaitingRefresh = null;
      await subscriptionRepository.refresh(force: true);
    }
  }

  Future<void> resetAccountScope(String? accountId) async {
    await subscriptionRepository.updateIdentity(accountId);
    if (accountId == null) return;
    if (!_activated) {
      // The forced server refresh is network work. It waits for activation
      // instead of holding a signed-in user's cold start open.
      _accountScopeAwaitingRefresh = accountId;
      return;
    }
    await subscriptionRepository.refresh(force: true);
  }

  Future<void> dispose() async {
    await subscriptionRepository.dispose();
    billingPlatform.dispose();
  }
}
