import 'package:archiveme_mobile/billing/revenuecat_configuration.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/core/config/v1_billing_capability.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/providers/subscription_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// `SubscriptionNotifier.build()` used to call `_initRevenueCat()` inline. An
/// `async` body runs synchronously up to its first `await`, and that method
/// reads `state` before any await, so the read landed while the provider was
/// still building and threw `Tried to read the state of an uninitialized
/// provider`. Nothing could mount the real notifier.
void main() {
  test('the provider is readable the moment it is built', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(() => container.read(subscriptionProvider), returnsNormally);
    expect(container.read(subscriptionProvider).isLoading, isTrue);
  });

  test('build still starts the billing bootstrap, and it can be awaited',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final seen = <bool>[];
    container.listen<SubscriptionState>(
      subscriptionProvider,
      (previous, next) => seen.add(next.isLoading),
      fireImmediately: true,
    );

    // Nobody called `ensureInitialized`; the notifier owns its own kickoff.
    await container.read(subscriptionProvider.notifier).bootstrapped;

    expect(
      seen.first,
      isTrue,
      reason: 'build must hand out a loading state synchronously',
    );
    expect(
      seen.last,
      isFalse,
      reason: 'deferring the bootstrap must not turn it into a no-op — the '
          'state has to leave loading on its own',
    );
    expect(container.read(subscriptionProvider).isLoading, isFalse);
  });

  test('a concurrent ensureInitialized joins the bootstrap build started',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(subscriptionProvider.notifier);
    // Same microtask turn as `build`, before its deferred kickoff has run.
    final joined = notifier.ensureInitialized();

    await Future.wait([joined, notifier.bootstrapped]);

    expect(container.read(subscriptionProvider).isLoading, isFalse);
  });

  test('disposing mid-bootstrap does not write to a dead provider', () async {
    final container = ProviderContainer();
    container.read(subscriptionProvider);
    container.dispose();

    // The kickoff microtask is still queued at this point. It must notice the
    // provider is gone rather than throwing out of an unawaited future.
    await Future<void>.delayed(Duration.zero);
  });

  test('storeBilling off wins over REVENUECAT_PURCHASES_ENABLED on init',
      () async {
    expect(V1CapabilityRegistry.storeBilling, isFalse);
    expect(RevenueCatConfiguration.purchasesEnabledAtBuildTime, isTrue);
    expect(V1BillingCapability.isEnabled, isFalse);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(subscriptionProvider.notifier).bootstrapped;

    final state = container.read(subscriptionProvider);
    expect(state.purchasesEnabled, isFalse);
    expect(state.billingConfigured, isFalse);
    expect(RevenueCatService.instance.isConfigured, isFalse);
  });
}
