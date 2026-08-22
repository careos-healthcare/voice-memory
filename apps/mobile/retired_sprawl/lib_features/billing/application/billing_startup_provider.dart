import 'package:archiveme_mobile/features/billing/application/billing_startup_result.dart';
import 'package:archiveme_mobile/features/billing/application/billing_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Startup bootstrap: SQLite → JSON cache → RevenueCat, with offline fallback.
final billingInitializationProvider = FutureProvider<BillingStartupResult>(
  (ref) => ref.read(billingProvider.notifier).initializeOnStartup(),
);

/// Pro flag after startup initialization completes; falls back to in-flight billing state.
final startupProStatusProvider = Provider<bool>((ref) {
  final init = ref.watch(billingInitializationProvider);
  return init.when(
    data: (result) => result.entitlements.isPro,
    loading: () => ref.watch(billingProvider).entitlements?.isPro ?? false,
    error: (_, __) => ref.watch(billingProvider).entitlements?.isPro ?? false,
  );
});