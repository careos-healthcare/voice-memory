import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../billing/paywall_access.dart';
import '../billing/paywall_route_args.dart';
import '../billing/paywall_source.dart';
import '../billing/value_moment_paywall.dart';
import '../features/first25/first25_user_metrics.dart';
import '../features/pro_bridge_visibility/delayed_paywall_proof_store.dart';
import '../models/entitlement.dart';
import '../product/consumer_ui_copy.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';

enum PaywallSurface { blindSpot, discover, archiveContinuity }

class ValueMomentPaywallCard extends StatefulWidget {
  const ValueMomentPaywallCard({
    super.key,
    required this.surface,
    required this.reflectionCount,
    required this.entitlements,
    required this.shouldShow,
    this.onDismissed,
  });

  final PaywallSurface surface;
  final int reflectionCount;
  final PremiumEntitlements? entitlements;
  final bool shouldShow;
  final VoidCallback? onDismissed;

  @override
  State<ValueMomentPaywallCard> createState() => _ValueMomentPaywallCardState();
}

class _ValueMomentPaywallCardState extends State<ValueMomentPaywallCard> {
  bool _seenTracked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackSeenIfVisible());
  }

  @override
  void didUpdateWidget(covariant ValueMomentPaywallCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackSeenIfVisible());
  }

  void _trackSeenIfVisible() {
    if (_seenTracked) return;
    if (!widget.shouldShow || widget.entitlements?.isPro == true) return;
    _seenTracked = true;
    First25UserMetrics.trackPaywallSeen(
      surface: 'value_moment_${widget.surface.name}',
    );
  }

  Future<void> _markSeen() async {
    final logic = AppServices.instance.paywall;
    switch (widget.surface) {
      case PaywallSurface.blindSpot:
        await logic.markPostBlindSpotSeen();
      case PaywallSurface.discover:
        await logic.markPostDiscoverSeen();
      case PaywallSurface.archiveContinuity:
        await logic.markPostBlindSpotSeen();
        await logic.markPostDiscoverSeen();
    }
    widget.onDismissed?.call();
    if (mounted) setState(() {});
  }

  Future<void> _openSubscription() async {
    First25UserMetrics.trackPaywallStarted(
      surface: 'value_moment_${widget.surface.name}',
    );
    if (!await PaywallAccess.canOpenPaywall()) return;
    if (!mounted) return;
    final sourceRoute = switch (widget.surface) {
      PaywallSurface.blindSpot => '/blind-spots',
      PaywallSurface.discover => '/discover',
      PaywallSurface.archiveContinuity => '/discover',
    };
    context.push(
      '/subscription',
      extra: PaywallRouteArgs(
        previewTitle: ValueMomentPaywallLogic.copyHeadline,
        previewBody: ValueMomentPaywallLogic.copyBody,
        sourceRoute: sourceRoute,
        source: PaywallSource.generalPro,
      ),
    );
    await _markSeen();
  }

  Future<void> _dismissPaywall() async {
    First25UserMetrics.trackPaywallDismissed(
      surface: 'value_moment_${widget.surface.name}',
    );
    await _markSeen();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.shouldShow) return const SizedBox.shrink();
    if (widget.entitlements?.isPro == true) return const SizedBox.shrink();
    if (!DelayedPaywallProofStore.passesGate) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.withValues(alpha: 0.15),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ValueMomentPaywallLogic.copyHeadline,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            ValueMomentPaywallLogic.copyBody,
            style: const TextStyle(color: AppTheme.muted, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            ValueMomentPaywallLogic.copyPatternMemory,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          for (final bullet in ConsumerUiCopy.paywallBullets) Text('· $bullet'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _openSubscription,
            child: const Text(ValueMomentPaywallLogic.ctaLabel),
          ),
          TextButton(
            onPressed: _dismissPaywall,
            child: const Text(ValueMomentPaywallLogic.secondaryLabel),
          ),
        ],
      ),
    );
  }
}
