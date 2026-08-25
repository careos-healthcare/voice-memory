import 'package:archiveme_mobile/billing/archive_pro_feature_map.dart';
import 'package:archiveme_mobile/billing/paywall_route_args.dart';
import 'package:archiveme_mobile/billing/tier2_paywall_gate.dart';
import 'package:archiveme_mobile/providers/subscription_provider.dart';
import 'package:archiveme_ui/widgets/billing/paywall_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

export 'package:archiveme_ui/widgets/billing/paywall_gate.dart';

/// Mobile billing adapter for the shared [PaywallGate] widget.
class MobilePaywallGateHost implements PaywallGateHost {
  const MobilePaywallGateHost();

  @override
  PaywallGateSnapshot watch(WidgetRef ref) {
    final sub = ref.watch(subscriptionProvider);
    return PaywallGateSnapshot(
      isLoading: sub.isLoading,
      isPro: sub.isPro,
      monthlyPriceDisplay: sub.monthlyPriceDisplay,
      errorMessage: sub.errorMessage,
    );
  }

  @override
  Future<void> ensureInitialized(WidgetRef ref) {
    return ref.read(subscriptionNotifierProvider).ensureInitialized();
  }

  @override
  Future<void> restorePurchases(WidgetRef ref) {
    return ref.read(subscriptionNotifierProvider).restorePurchases();
  }

  @override
  void openPaywall({
    required BuildContext context,
    required String featureName,
    Object? feature,
    String? sourceRoute,
  }) {
    final typed = feature is ArchiveFeature ? feature : null;
    context.push(
      '/subscription',
      extra: typed == null
          ? null
          : PaywallRouteArgs(
              trigger: Tier2PaywallGate.triggerFor(typed),
              previewTitle: ArchiveProFeatureMap.featureLabel(typed),
              previewBody: ArchiveProFeatureMap.featureBenefit(typed),
              sourceRoute: sourceRoute,
            ),
    );
  }
}

/// Root-container override so [PaywallGate] uses live subscription state.
final paywallGateHostOverrides = [
  paywallGateHostProvider.overrideWith((ref) => const MobilePaywallGateHost()),
];
