import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Subscription snapshot consumed by [PaywallGate].
class PaywallGateSnapshot {
  const PaywallGateSnapshot({
    required this.isLoading,
    required this.isPro,
    required this.monthlyPriceDisplay,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isPro;
  final String monthlyPriceDisplay;
  final String? errorMessage;
}

/// Host-app billing port for [PaywallGate].
///
/// The mobile app overrides [paywallGateHostProvider] with a host that talks
/// to the real subscription notifier. Research and tests can supply a stub.
abstract class PaywallGateHost {
  const PaywallGateHost();

  PaywallGateSnapshot watch(WidgetRef ref);

  Future<void> ensureInitialized(WidgetRef ref);

  Future<void> restorePurchases(WidgetRef ref);

  void openPaywall({
    required BuildContext context,
    required String featureName,
    Object? feature,
    String? sourceRoute,
  });
}

class _DefaultPaywallGateHost implements PaywallGateHost {
  const _DefaultPaywallGateHost();

  static const _priceHint = r'$7–$9/month';

  @override
  PaywallGateSnapshot watch(WidgetRef ref) {
    return const PaywallGateSnapshot(
      isLoading: false,
      isPro: false,
      monthlyPriceDisplay: _priceHint,
    );
  }

  @override
  Future<void> ensureInitialized(WidgetRef ref) async {}

  @override
  Future<void> restorePurchases(WidgetRef ref) async {}

  @override
  void openPaywall({
    required BuildContext context,
    required String featureName,
    Object? feature,
    String? sourceRoute,
  }) {
    unawaited(context.push('/subscription'));
  }
}

/// Override in the host app to wire real billing.
final paywallGateHostProvider = Provider<PaywallGateHost>(
  (ref) => const _DefaultPaywallGateHost(),
);

/// Declarative Pro gate — renders [child] when entitled, otherwise a paywall card.
class PaywallGate extends ConsumerStatefulWidget {
  const PaywallGate({
    required this.child,
    required this.featureName,
    super.key,
    this.feature,
    this.sourceRoute,
    this.onDismiss,
  });

  final Widget child;
  final String featureName;

  /// Host-interpreted feature token (typically an [ArchiveFeature] enum).
  final Object? feature;

  final String? sourceRoute;
  final VoidCallback? onDismiss;

  @override
  ConsumerState<PaywallGate> createState() => _PaywallGateState();
}

class _PaywallGateState extends ConsumerState<PaywallGate> {
  static const _restoreCta = 'Restore purchases';
  static const _purchaseRestored = 'Purchase restored. Pro is active.';
  static const _noActivePurchase =
      'No previous Pro purchase was found on this Apple ID.';
  static const _dismissCta = 'Not now';
  static const _textSecondary = Color(0xFF667085);

  bool _restoreBusy = false;

  PaywallGateHost get _host => ref.read(paywallGateHostProvider);

  @override
  void initState() {
    super.initState();
    unawaited(
      Future.microtask(() => _host.ensureInitialized(ref)),
    );
  }

  Future<void> _restorePurchases() async {
    if (_restoreBusy) return;
    setState(() => _restoreBusy = true);
    try {
      await _host.restorePurchases(ref);
      if (!mounted) return;
      final isPro = _host.watch(ref).isPro;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPro ? _purchaseRestored : _noActivePurchase),
        ),
      );
    } finally {
      if (mounted) setState(() => _restoreBusy = false);
    }
  }

  void _openPaywall() {
    _host.openPaywall(
      context: context,
      featureName: widget.featureName,
      feature: widget.feature,
      sourceRoute: widget.sourceRoute,
    );
  }

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(paywallGateHostProvider).watch(ref);

    if (subState.isLoading) {
      return _PaywallShell(
        title: widget.featureName,
        showBottomDone: false,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (subState.isPro) {
      return widget.child;
    }

    final priceLabel = subState.monthlyPriceDisplay;
    final helper = Theme.of(context).textTheme.bodyMedium;

    return _PaywallShell(
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
              color: _textSecondary.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 32),
            Text(
              'Unlock ${widget.featureName} with ArchiveMe Pro',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Deep historical comparison engines, weekly chapters, and unlimited '
              'archive history sit behind Pro. Your core evidence-citation trails '
              'remain fully verifiable on free entries.',
              style: helper,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
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
            const SizedBox(height: 16),
            OutlinedButton(
              key: const Key('paywall_gate_restore'),
              onPressed: _restoreBusy ? null : _restorePurchases,
              child: _restoreBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(_restoreCta),
            ),
            const SizedBox(height: 16),
            TextButton(
              key: const Key('paywall_gate_dismiss'),
              onPressed: widget.onDismiss ?? () => context.pop(),
              child: const Text(_dismissCta),
            ),
            if (subState.errorMessage case final error?) ...[
              const SizedBox(height: 24),
              Text(error, style: helper, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaywallShell extends StatelessWidget {
  const _PaywallShell({
    required this.title,
    required this.body,
    this.showBottomDone = true,
    this.onBack,
  });

  final String title;
  final Widget body;
  final bool showBottomDone;
  final VoidCallback? onBack;

  void _goBack(BuildContext context) {
    if (onBack != null) {
      onBack!();
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/archive-belief');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => _goBack(context),
        ),
        title: Text(title),
      ),
      body: body,
      bottomNavigationBar: showBottomDone
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => _goBack(context),
                    child: const Text('Done'),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
