import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../billing/archive_paywall_stats.dart';
import '../billing/paywall_access.dart';
import '../billing/paywall_route_args.dart';
import '../billing/value_moment_paywall.dart';
import '../billing/subscription_purchase_coordinator.dart';
import '../features/first25/first25_user_metrics.dart';
import '../features/monetization/domain/access_policy_engine.dart';
import '../features/monetization/domain/services/monetization_analytics.dart';
import '../features/pro_bridge_visibility/delayed_paywall_proof_store.dart';
import '../product/consumer_ui_copy.dart';
import '../services/app_services.dart';
import '../subscriptions/domain/subscription_models.dart';
import '../subscriptions/domain/subscription_repository.dart';
import '../theme/app_theme.dart';

enum PaywallSurface { blindSpot, discover, archiveContinuity }

enum ValueMomentPaywallReason { premiumInsights, fullHistory }

/// Entitlement-aware Pro boundary for high-intent value moments.
///
/// Entitlements and checkout sessions are resolved through
/// [SubscriptionRepository].
class ValueMomentPaywall extends StatefulWidget {
  const ValueMomentPaywall({
    super.key,
    required this.reason,
    this.onDismissed,
    this.onUnlocked,
    this.entitlementLoader,
    this.checkoutCreator,
    this.checkoutLauncher,
    this.useWebCheckout = kIsWeb,
    this.knownIsPro,
    this.purchaseHandler,
    this.restoreHandler,
    this.analytics = const ProductMonetizationAnalyticsEngine(),
    this.onUpgradeTapped,
    this.personalizationLoader,
    this.subscriptionRepository,
  });

  final ValueMomentPaywallReason reason;
  final VoidCallback? onDismissed;
  final VoidCallback? onUnlocked;
  final Future<SubscriptionState> Function()? entitlementLoader;
  final Future<SubscriptionCheckout> Function()? checkoutCreator;
  final Future<bool> Function(Uri uri)? checkoutLauncher;
  final bool useWebCheckout;
  final bool? knownIsPro;
  final Future<SubscriptionState> Function()? purchaseHandler;
  final Future<SubscriptionState> Function()? restoreHandler;
  final AnalyticsEngine analytics;
  final VoidCallback? onUpgradeTapped;
  final Future<ArchivePaywallStats> Function()? personalizationLoader;
  final SubscriptionRepository? subscriptionRepository;

  @override
  State<ValueMomentPaywall> createState() => _ValueMomentPaywallState();
}

class _ValueMomentPaywallState extends State<ValueMomentPaywall> {
  static bool _stateAllowsProGeneration(SubscriptionState state) =>
      AccessPolicyEngine.decide(
        capability: CapabilityId.ongoingComparisons,
        entitlement: EntitlementSnapshot.fromSubscriptionState(state),
        usage: const UsageSnapshot.serverAuthoritative(),
      ).allowed;

  bool _loading = true;
  bool _checkoutInFlight = false;
  bool _restoreInFlight = false;
  bool _isPro = false;
  bool _presentedTracked = false;
  bool _dismissedTracked = false;
  bool _converted = false;
  bool _resolvedAsPro = false;
  String? _error;
  ArchivePaywallStats? _personalization;
  SubscriptionPurchaseCoordinator? _purchaseCoordinator;

  SubscriptionRepository get _repository =>
      widget.subscriptionRepository ??
      AppServices.instance.subscriptionRepository;

  SubscriptionPurchaseCoordinator get _coordinator => _purchaseCoordinator ??=
      SubscriptionPurchaseCoordinator(repository: _repository);

  @override
  void initState() {
    super.initState();
    _loadPersonalization();
    if (widget.knownIsPro == true) {
      _loading = false;
      _isPro = true;
      _resolvedAsPro = true;
    } else {
      if (widget.knownIsPro == false) {
        _loading = false;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _trackPresentedIfVisible(),
        );
      }
      // A known free snapshot is only an initial value. Always re-check so a
      // purchase, restore, or connectivity recovery can unlock in place.
      _loadEntitlement();
    }
  }

  Future<void> _loadPersonalization() async {
    try {
      final loader = widget.personalizationLoader;
      final stats = loader != null
          ? await loader()
          : ArchivePaywallStats.fromEntries(
              entries: await AppServices.instance.journalStore.loadAll(),
            );
      if (mounted) setState(() => _personalization = stats);
    } on Object {
      // Personalized proof is additive; billing controls remain available.
    }
  }

  @override
  void dispose() {
    if (_presentedTracked &&
        !_dismissedTracked &&
        !_converted &&
        !_resolvedAsPro) {
      _trackDismissed();
    }
    super.dispose();
  }

  Future<void> _loadEntitlement({bool forceRefresh = false}) async {
    try {
      final loader =
          widget.entitlementLoader ??
          () => _repository.refresh(force: forceRefresh);
      final state = await loader();
      if (!mounted) return;
      final allowed = _stateAllowsProGeneration(state);
      setState(() {
        _isPro = allowed;
        _resolvedAsPro = allowed;
        _loading = false;
        _error = null;
      });
      _trackPresentedIfVisible();
      if (allowed) widget.onUnlocked?.call();
    } on Object {
      if (!mounted) return;
      if (widget.entitlementLoader == null && AppServices.isInitialized) {
        final cached = await _repository.loadCachedState();
        if (!mounted) return;
        if (cached != null && _stateAllowsProGeneration(cached)) {
          setState(() {
            _isPro = true;
            _resolvedAsPro = true;
            _loading = false;
            _error = null;
          });
          widget.onUnlocked?.call();
          return;
        }
      }
      setState(() {
        _loading = false;
        _error = 'Pro access could not be checked. You can try again.';
      });
    }
  }

  Future<void> _startCheckout() async {
    if (_checkoutInFlight) return;
    widget.onUpgradeTapped?.call();
    final purchaseHandler = widget.purchaseHandler;
    if (purchaseHandler != null) {
      await _runEntitlementAction(action: purchaseHandler, restore: false);
      return;
    }
    if (!widget.useWebCheckout) {
      await _openSubscriptionFallback(showError: false);
      return;
    }
    setState(() {
      _checkoutInFlight = true;
      _error = null;
    });
    try {
      final creator = widget.checkoutCreator ?? _repository.createCheckout;
      final session = await creator();
      final uri = Uri.tryParse(session.url);
      final safeUri = uri != null && uri.scheme == 'https' ? uri : null;
      final launcher =
          widget.checkoutLauncher ??
          (target) => launchUrl(target, mode: LaunchMode.externalApplication);
      final opened = safeUri != null && await launcher(safeUri);
      if (!opened && mounted) {
        await _openSubscriptionFallback();
      }
    } on Object {
      if (mounted) await _openSubscriptionFallback();
    } finally {
      if (mounted) setState(() => _checkoutInFlight = false);
    }
  }

  Future<void> _restorePurchases() async {
    if (_restoreInFlight || _checkoutInFlight) return;
    await _runEntitlementAction(
      action: widget.restoreHandler ?? _coordinator.restore,
      restore: true,
    );
  }

  Future<void> _runEntitlementAction({
    required Future<SubscriptionState> Function() action,
    required bool restore,
  }) async {
    setState(() {
      if (restore) {
        _restoreInFlight = true;
      } else {
        _checkoutInFlight = true;
      }
      _error = null;
    });
    try {
      final state = await action();
      if (!mounted) return;
      if (!_stateAllowsProGeneration(state)) {
        setState(() {
          _error = restore
              ? 'No active purchase was found for this account.'
              : 'The purchase did not unlock Pro. Please try restoring.';
        });
        return;
      }
      setState(() => _isPro = true);
      _resolvedAsPro = true;
      if (state.verification != SubscriptionVerification.cached) {
        _converted = true;
        _trackConverted();
      }
      widget.onUnlocked?.call();
    } on Object catch (error, stackTrace) {
      if (!mounted) return;
      final purchaseFailure = error is SubscriptionPurchaseException
          ? error
          : null;
      if (purchaseFailure?.isCancelled == true) return;
      if (purchaseFailure?.kind == SubscriptionPurchaseFailureKind.unexpected ||
          (restore && error is! SubscriptionRestoreException)) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'billing',
            context: ErrorDescription(
              restore ? 'while restoring purchases' : 'while purchasing Pro',
            ),
          ),
        );
      }
      setState(() {
        _error = restore
            ? error is SubscriptionRestoreException
                  ? 'Purchases are temporarily unavailable.'
                  : 'Purchases could not be restored. Please try again.'
            : 'Purchase could not be completed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          if (restore) {
            _restoreInFlight = false;
          } else {
            _checkoutInFlight = false;
          }
        });
      }
    }
  }

  String get _triggerSource => switch (widget.reason) {
    ValueMomentPaywallReason.premiumInsights => 'insight_tease',
    ValueMomentPaywallReason.fullHistory => 'pro_bridge',
  };

  void _trackPresentedIfVisible() {
    if (_presentedTracked || _loading || _isPro || !mounted) return;
    _presentedTracked = true;
    widget.analytics.logEvent(
      'paywall_seen',
      parameters: {'source': _triggerSource},
    );
  }

  void _trackDismissed() {
    if (_dismissedTracked || _converted) return;
    _dismissedTracked = true;
    widget.analytics.logEvent(
      'paywall_dismissed',
      parameters: {'source': _triggerSource},
    );
  }

  void _trackConverted() {
    widget.analytics.logEvent(
      'purchase_completed',
      parameters: {'source': _triggerSource},
    );
  }

  void _dismiss() {
    _trackDismissed();
    widget.onDismissed?.call();
  }

  Future<void> _openSubscriptionFallback({bool showError = true}) async {
    setState(() {
      _error = showError
          ? 'Checkout is unavailable right now. You can still view plans.'
          : null;
    });
    await context.push(
      '/subscription',
      extra: PaywallRouteArgs(
        previewTitle: _title,
        previewBody: _body,
        sourceRoute: _sourceRoute,
        source: PaywallSource.valueMoment,
      ),
    );
    if (!mounted || _converted) return;
    final entitlement = await _repository.loadCachedState();
    if (!mounted) return;
    if (entitlement != null && _stateAllowsProGeneration(entitlement)) {
      setState(() {
        _isPro = true;
        _resolvedAsPro = true;
      });
      widget.onUnlocked?.call();
    } else {
      _trackDismissed();
    }
  }

  String get _title => switch (widget.reason) {
    ValueMomentPaywallReason.premiumInsights => 'See the deeper pattern',
    ValueMomentPaywallReason.fullHistory => 'Replay your full history',
  };

  String get _body => switch (widget.reason) {
    ValueMomentPaywallReason.premiumInsights =>
      'Pro connects recurring topics, mood shifts, and evidence across your archive.',
    ValueMomentPaywallReason.fullHistory =>
      'Your recordings stay yours. Pro generates new full-history comparisons and deeper archive analysis.',
  };

  String? get _personalizedProof {
    final stats = _personalization;
    if (stats == null || stats.recordingCount == 0) return null;
    return switch (widget.reason) {
      ValueMomentPaywallReason.premiumInsights =>
        '${stats.recordingCount} saved moments across ${stats.spanLabel}'
            '${stats.recurringThemeCount > 0 ? ' reveal ${stats.recurringThemeCount} recurring themes.' : '.'}',
      ValueMomentPaywallReason.fullHistory =>
        'Your local archive spans ${stats.spanLabel} across ${stats.recordingCount} recordings.',
    };
  }

  String get _sourceRoute => switch (widget.reason) {
    ValueMomentPaywallReason.premiumInsights => '/pattern-recognition',
    ValueMomentPaywallReason.fullHistory => '/pattern-recognition',
  };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_isPro) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        key: Key('value_moment_paywall_${widget.reason.name}'),
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.25)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(_body),
              if (_personalizedProof case final proof?) ...[
                const SizedBox(height: 8),
                Text(
                  proof,
                  key: const Key('value_moment_paywall_personalized_proof'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
              if (_error case final error?) ...[
                const SizedBox(height: 8),
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('value_moment_paywall_checkout'),
                  onPressed: _checkoutInFlight || _restoreInFlight
                      ? null
                      : _startCheckout,
                  child: Text(
                    _checkoutInFlight ? 'Opening checkout…' : 'Explore Pro',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('value_moment_paywall_restore'),
                  onPressed: _restoreInFlight || _checkoutInFlight
                      ? null
                      : _restorePurchases,
                  icon: _restoreInFlight
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restore),
                  label: Text(
                    _restoreInFlight ? 'Restoring…' : 'Restore Purchases',
                  ),
                ),
              ),
              TextButton(onPressed: _dismiss, child: const Text('Not now')),
            ],
          ),
        ),
      ),
    );
  }
}

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
  final SubscriptionState? entitlements;
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
      PaywallSurface.blindSpot => '/self-discovery?tab=blind-spots',
      PaywallSurface.discover => '/archive-belief',
      PaywallSurface.archiveContinuity => '/archive-belief',
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
