import 'dart:async';

import 'package:archiveme_mobile/billing/archive_pro_feature_map.dart';
import 'package:archiveme_mobile/billing/paywall_route_args.dart';
import 'package:archiveme_mobile/billing/restore_purchases_copy.dart';
import 'package:archiveme_mobile/billing/subscription_billing_copy.dart';
import 'package:archiveme_mobile/billing/tier2_paywall_gate.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/providers/subscription_provider.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Declarative Pro gate — renders [child] when entitled, otherwise a paywall card.
class PaywallGate extends ConsumerStatefulWidget {
  const PaywallGate({
    required this.child, required this.featureName, super.key,
    this.feature,
    this.sourceRoute,
    this.onDismiss,
  });

  final Widget child;
  final String featureName;

  /// When set, opens `/subscription` with trigger-specific copy.
  final ArchiveFeature? feature;

  final String? sourceRoute;
  final VoidCallback? onDismiss;

  @override
  ConsumerState<PaywallGate> createState() => _PaywallGateState();
}

class _PaywallGateState extends ConsumerState<PaywallGate> {
  bool _restoreBusy = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      Future.microtask(
        () => ref.read(subscriptionNotifierProvider).ensureInitialized(),
      ),
    );
  }

  Future<void> _restorePurchases() async {
    if (_restoreBusy) return;
    setState(() => _restoreBusy = true);
    try {
      await ref.read(subscriptionNotifierProvider).restorePurchases();
      if (!mounted) return;
      final isPro = ref.read(subscriptionProvider).isPro;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPro
                ? RestorePurchasesCopy.purchaseRestored
                : RestorePurchasesCopy.noActivePurchase,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _restoreBusy = false);
    }
  }

  void _openPaywall() {
    final feature = widget.feature;
    unawaited(context.push(
      '/subscription',
      extra: feature == null
          ? null
          : PaywallRouteArgs(
              trigger: Tier2PaywallGate.triggerFor(feature),
              previewTitle: ArchiveProFeatureMap.featureLabel(feature),
              previewBody: ArchiveProFeatureMap.featureBenefit(feature),
              sourceRoute: widget.sourceRoute,
            ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(subscriptionProvider);

    if (subState.isLoading) {
      return PushedScreenShell(
        title: widget.featureName,
        showBottomDone: false,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (subState.isPro) {
      return widget.child;
    }

    final priceLabel = subState.monthlyPriceDisplay;

    return PushedScreenShell(
      title: widget.featureName,
      onBack: widget.onDismiss,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: VoiceMemoryColors.textSecondary.withValues(alpha: 0.85),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Unlock ${widget.featureName} with ArchiveMe Pro',
              style: ArchiveMobileTypography.responsivePageTitle(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Deep historical comparison engines, weekly chapters, and unlimited '
              'archive history sit behind Pro. Your core evidence-citation trails '
              'remain fully verifiable on free entries.',
              style: ArchiveMobileTypography.responsiveHelper(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              key: const Key('paywall_gate_upgrade'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              onPressed: _openPaywall,
              child: Text('Upgrade to Pro ($priceLabel)'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const Key('paywall_gate_restore'),
              onPressed: _restoreBusy ? null : _restorePurchases,
              child: _restoreBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(SubscriptionBillingCopy.restoreCta),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              key: const Key('paywall_gate_dismiss'),
              onPressed: widget.onDismiss ?? () => context.pop(),
              child: const Text(ConsumerUiCopy.paywallSecondaryCta),
            ),
            if (subState.errorMessage case final error?) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                error,
                style: ArchiveMobileTypography.responsiveHelper(context),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}