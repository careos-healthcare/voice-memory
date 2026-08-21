import 'package:archiveme_mobile/billing/archive_pro_feature_map.dart';
import 'package:archiveme_mobile/billing/paywall_access.dart';
import 'package:archiveme_mobile/billing/paywall_route_args.dart';
import 'package:archiveme_mobile/billing/paywall_trigger_model.dart';
import 'package:archiveme_mobile/billing/subscription_billing_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/providers/subscription_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Tier 2 historical analysis paywall gates (comparison + weekly review).
abstract final class Tier2PaywallGate {
  Tier2PaywallGate._();

  static ArchiveFeature featureForComparison() =>
      ArchiveFeature.fullHistory;

  static ArchiveFeature featureForWeeklyReview() =>
      ArchiveFeature.tier2WeeklyReview;

  /// Returns true when Pro access is granted; otherwise opens paywall.
  static Future<bool> ensureComparisonAccess(
    BuildContext context, {
    int momentCount = 0,
  }) => PaywallAccess.ensureAccess(
    context,
    feature: featureForComparison(),
    momentCount: momentCount,
    sourceRoute: '/comparison-explorer',
  );

  static Future<bool> ensureWeeklyReviewAccess(
    BuildContext context, {
    int momentCount = 0,
    int weekCount = 1,
  }) => PaywallAccess.ensureAccess(
    context,
    feature: featureForWeeklyReview(),
    momentCount: momentCount,
    weekCount: weekCount,
    sourceRoute: '/weekly-archive-review',
  );

  static PaywallTrigger triggerFor(ArchiveFeature feature) => switch (feature) {
    ArchiveFeature.monthlyReview => PaywallTrigger.monthlyReview,
    ArchiveFeature.tier2WeeklyReview => PaywallTrigger.monthlyReview,
    ArchiveFeature.fullHistory => PaywallTrigger.fullHistory,
    _ => PaywallTrigger.fullHistory,
  };
}

/// Inline intercept when a Tier 2 surface is Pro-only.
class Tier2PaywallDeniedBody extends StatelessWidget {
  const Tier2PaywallDeniedBody({
    required this.feature, required this.onDismiss, super.key,
    this.priceHint = SubscriptionState.proPriceRangeHint,
  });

  final ArchiveFeature feature;
  final VoidCallback onDismiss;
  final String priceHint;

  @override
  Widget build(BuildContext context) {
    final label = ArchiveProFeatureMap.featureLabel(feature);
    final benefit = ArchiveProFeatureMap.featureBenefit(feature);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(benefit),
          const SizedBox(height: 8),
          Text(
            'Free keeps the full evidence citation trail on your recent capped entries. '
            'Pro unlocks the complete historical view.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Text(priceHint, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.push(
              '/subscription',
              extra: PaywallRouteArgs(
                trigger: Tier2PaywallGate.triggerFor(feature),
                previewTitle: label,
                previewBody: benefit,
                sourceRoute: '/weekly-archive-review',
              ),
            ),
            child: const Text(SubscriptionBillingCopy.upgradeCta),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onDismiss, child: const Text(ConsumerUiCopy.paywallSecondaryCta)),
        ],
      ),
    );
  }
}

/// Inline intercept when a Tier 2 surface is Pro-only.
class Tier2PaywallIntercept extends ConsumerWidget {
  const Tier2PaywallIntercept({
    required this.feature, required this.onContinueFree, super.key,
    this.momentCount = 0,
  });

  final ArchiveFeature feature;
  final VoidCallback onContinueFree;
  final int momentCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider);
    if (subscription.isPro) return const SizedBox.shrink();

    final label = ArchiveProFeatureMap.featureLabel(feature);
    final benefit = ArchiveProFeatureMap.featureBenefit(feature);

    return Card(
      key: Key('tier2_paywall_intercept_${feature.name}'),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(benefit),
            const SizedBox(height: 8),
            Text(
              'Free keeps the full evidence citation trail on your recent capped entries. '
              'Pro unlocks the complete historical view.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              subscription.monthlyPriceDisplay,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: Key('tier2_paywall_upgrade_${feature.name}'),
              onPressed: () => context.push(
                '/subscription',
                extra: PaywallRouteArgs(
                  trigger: Tier2PaywallGate.triggerFor(feature),
                  previewTitle: label,
                  previewBody: benefit,
                  sourceRoute: '/comparison-explorer',
                ),
              ),
              child: const Text(SubscriptionBillingCopy.upgradeCta),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: Key('tier2_paywall_continue_free_${feature.name}'),
              onPressed: onContinueFree,
              child: const Text(ConsumerUiCopy.paywallSecondaryCta),
            ),
          ],
        ),
      ),
    );
  }
}