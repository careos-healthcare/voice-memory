import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../billing/archive_paywall_copy.dart';
import '../billing/archive_paywall_stats.dart';
import '../features/first25/first25_user_metrics.dart';
import '../billing/subscription_copy.dart';
import '../billing/subscription_purchase_coordinator.dart';
import '../design/archive_responsive_layout.dart';
import '../product/consumer_ui_copy.dart';
import '../features/archive_evidence/archive_evidence.dart';
import '../features/archive_v1/archive_v1_models.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../subscriptions/domain/subscription_models.dart';
import '../subscriptions/domain/subscription_repository.dart';
import '../theme/app_theme.dart';
import '../features/archive_growth/archive_growth_service.dart';
import '../widgets/archive_growth/archive_growth_card.dart';
import '../widgets/archive_paywall/archive_paywall_body.dart';
import '../widgets/archive_paywall/paywall_unavailable_fallback.dart';
import '../widgets/pushed_screen_shell.dart';

/// Archive intelligence subscription paywall.
class MobileSubscriptionScreen extends StatefulWidget {
  const MobileSubscriptionScreen({
    super.key,
    this.journalLoader,
    this.archiveViewBuilder,
    this.growthLoader,
    this.offeringsLoader,
    this.entitlementLoader,
    this.subscriptionsAvailableOverride,
    this.subscriptionRepository,
  });

  final Future<List<JournalEntry>> Function()? journalLoader;
  final Future<ArchiveV1View> Function(List<JournalEntry> entries)?
  archiveViewBuilder;
  final Future<ArchiveGrowthSnapshot?> Function()? growthLoader;
  final Future<List<SubscriptionOffer>> Function()? offeringsLoader;
  final Future<SubscriptionState> Function()? entitlementLoader;
  final bool? subscriptionsAvailableOverride;
  final SubscriptionRepository? subscriptionRepository;

  @override
  State<MobileSubscriptionScreen> createState() =>
      _MobileSubscriptionScreenState();
}

class _MobileSubscriptionScreenState extends State<MobileSubscriptionScreen> {
  static const Duration _loadTimeout = Duration(seconds: 12);
  bool _paywallSeenTracked = false;

  List<SubscriptionOffer> _offers = const [];
  SubscriptionState? _subscriptionState;
  ArchivePaywallStats? _paywallStats;
  ArchiveGrowthSnapshot? _growth;
  bool _loading = true;
  bool _offeringsReloading = false;
  bool _busy = false;
  bool _productsUnavailable = false;
  String? _error;
  SubscriptionPurchaseCoordinator? _purchaseCoordinator;

  SubscriptionRepository get _repository =>
      widget.subscriptionRepository ??
      AppServices.instance.subscriptionRepository;

  SubscriptionPurchaseCoordinator get _coordinator => _purchaseCoordinator ??=
      SubscriptionPurchaseCoordinator(repository: _repository);

  bool get _subscriptionsAvailable =>
      widget.subscriptionsAvailableOverride ??
      _repository.availability == SubscriptionAvailability.available;

  String get _unavailableBodyText {
    if (!_subscriptionsAvailable) {
      return ConsumerUiCopy.paywallBillingNotConfigured;
    }
    final err = _error;
    if (err != null &&
        err != SubscriptionCopy.paywallNoOfferings &&
        err != SubscriptionCopy.temporarilyUnavailable) {
      return err;
    }
    return ConsumerUiCopy.paywallSetupUnavailableBody;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _hasStorePackages(List<SubscriptionOffer> offers) => offers.isNotEmpty;

  Future<ArchivePaywallStats> _loadArchiveStats(
    List<JournalEntry> entries,
  ) async {
    ArchiveV1View? v1;
    if (archiveHasMinimumEvidence(entries)) {
      v1 = await AppServices.instance.archiveIntelligence.buildArchiveView(
        entries: entries,
        evolutionService: AppServices.instance.beliefEvolution,
      );
    }
    return ArchivePaywallStats.fromEntries(entries: entries, archiveV1: v1);
  }

  Future<void> _load({bool isRetry = false}) async {
    if (!mounted) return;
    setState(() {
      if (isRetry) {
        _offeringsReloading = true;
      } else {
        _loading = true;
        _error = null;
        _productsUnavailable = false;
      }
    });

    ArchivePaywallStats stats =
        _paywallStats ??
        const ArchivePaywallStats(
          recordingCount: 0,
          spanDays: 1,
          recurringThemeCount: 0,
          activeTheoryCount: 0,
          changeCount: 0,
          contradictionCount: 0,
        );

    ArchiveGrowthSnapshot? growth;
    List<JournalEntry>? entries;
    try {
      entries =
          await (widget.journalLoader?.call() ??
              AppServices.instance.journalStore.loadAll());
      // Basic local counts never depend on advanced intelligence builders.
      stats = ArchivePaywallStats.fromEntries(entries: entries);
    } catch (error) {
      debugPrint(
        'Paywall local stats unavailable — retaining prior stats: $error',
      );
    }
    if (entries != null) {
      try {
        final builder = widget.archiveViewBuilder;
        if (builder != null) {
          final view = await builder(entries);
          stats = ArchivePaywallStats.fromEntries(
            entries: entries,
            archiveV1: view,
          );
        } else {
          stats = await _loadArchiveStats(entries);
        }
      } catch (error) {
        debugPrint(
          'Paywall advanced intelligence unavailable — using basic stats: $error',
        );
      }
    }
    try {
      growth =
          await (widget.growthLoader?.call() ?? ArchiveGrowthService.load());
    } catch (error) {
      debugPrint('Paywall growth snapshot unavailable: $error');
    }

    List<SubscriptionOffer> offers = const [];
    SubscriptionState subscriptionState = SubscriptionState.free();
    String? error;
    var productsUnavailable = !_subscriptionsAvailable;

    try {
      if (!_subscriptionsAvailable) {
        error = SubscriptionCopy.temporarilyUnavailable;
        _trackSubscriptionPaywallSeen(subscriptionState);
        return;
      }

      try {
        offers =
            (await (widget.offeringsLoader?.call() ?? _repository.loadOffers())
                    .timeout(_loadTimeout))
                .where(
                  (offer) =>
                      offer.period == SubscriptionPeriod.monthly ||
                      offer.period == SubscriptionPeriod.annual,
                )
                .where((offer) => offer.price.trim().isNotEmpty)
                .toList(growable: false);
        subscriptionState =
            await (widget.entitlementLoader?.call() ??
                    _repository.refresh(force: true))
                .timeout(
                  _loadTimeout,
                  onTimeout: () =>
                      _repository.currentState ?? SubscriptionState.free(),
                );
      } on TimeoutException {
        error = SubscriptionCopy.paywallNoOfferings;
      } catch (e) {
        error = SubscriptionCopy.paywallNoOfferings;
      }

      final productsOk = _hasStorePackages(offers);
      productsUnavailable = !productsOk;
      if (!productsOk && error == null) {
        error = SubscriptionCopy.paywallNoOfferings;
      }
      _trackSubscriptionPaywallSeen(subscriptionState);
    } finally {
      if (mounted) {
        setState(() {
          _offers = offers;
          _subscriptionState = subscriptionState;
          _paywallStats = stats;
          _growth = growth;
          _loading = false;
          _offeringsReloading = false;
          _productsUnavailable = productsUnavailable;
          _error = error;
        });
      }
    }
  }

  SubscriptionOffer? _offerForBillingPeriod(BillingPeriod period) {
    final subscriptionPeriod = period == BillingPeriod.monthly
        ? SubscriptionPeriod.monthly
        : SubscriptionPeriod.annual;
    for (final offer in _offers) {
      if (offer.period == subscriptionPeriod) return offer;
    }
    return null;
  }

  void _trackSubscriptionPaywallSeen(SubscriptionState state) {
    if (_paywallSeenTracked || state.isPro) return;
    _paywallSeenTracked = true;
    First25UserMetrics.trackPaywallSeen(surface: 'subscription_screen');
  }

  Future<void> _purchase(BillingPeriod period) async {
    if (_busy) return;
    final offer = _offerForBillingPeriod(period);
    if (offer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(SubscriptionCopy.temporarilyUnavailable)),
      );
      return;
    }
    setState(() => _busy = true);
    First25UserMetrics.trackPaywallStarted(
      surface: 'subscription_screen',
      period: period == BillingPeriod.monthly ? 'monthly' : 'yearly',
    );
    try {
      final state = await _coordinator.purchase(offer);
      if (state.isPro) {
        await First25UserMetrics.trackPaywallPurchased(
          surface: 'subscription_screen',
          period: period == BillingPeriod.monthly ? 'monthly' : 'yearly',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pattern insights are now active on this device.'),
          ),
        );
        await _load();
      }
    } on SubscriptionPurchaseException catch (failure) {
      if (mounted && !failure.isCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase could not be completed.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _purchasePreferred() {
    final yearly = _offerForBillingPeriod(BillingPeriod.yearly);
    if (yearly != null) {
      _purchase(BillingPeriod.yearly);
      return;
    }
    final monthly = _offerForBillingPeriod(BillingPeriod.monthly);
    if (monthly != null) {
      _purchase(BillingPeriod.monthly);
    }
  }

  Widget? _plansSection() {
    if (_productsUnavailable) return null;
    final monthly = _offerForBillingPeriod(BillingPeriod.monthly);
    final yearly = _offerForBillingPeriod(BillingPeriod.yearly);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (yearly != null)
          _planOutlineButton(
            label: 'Yearly',
            price: yearly.price,
            introductoryOffer: yearly.introductoryDisplay,
            onPressed: _busy ? null : () => _purchase(BillingPeriod.yearly),
          ),
        if (monthly != null) ...[
          const SizedBox(height: 8),
          _planOutlineButton(
            label: 'Monthly',
            price: monthly.price,
            introductoryOffer: monthly.introductoryDisplay,
            onPressed: _busy ? null : () => _purchase(BillingPeriod.monthly),
          ),
        ],
      ],
    );
  }

  Widget _planOutlineButton({
    required String label,
    required String price,
    required String? introductoryOffer,
    required VoidCallback? onPressed,
  }) {
    return Semantics(
      button: true,
      label: [label, price, ?introductoryOffer].join(', '),
      child: OutlinedButton(
        onPressed: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (introductoryOffer != null)
                    Text(
                      introductoryOffer,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionState = _subscriptionState ?? SubscriptionState.free();
    final stats =
        _paywallStats ??
        const ArchivePaywallStats(
          recordingCount: 0,
          spanDays: 1,
          recurringThemeCount: 0,
          activeTheoryCount: 0,
          changeCount: 0,
          contradictionCount: 0,
        );

    return PushedScreenShell(
      title: ArchivePaywallCopy.screenTitle,
      body: ListView(
        padding: ArchiveResponsiveLayout.pagePadding(context),
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (subscriptionState.isPro)
            _proActivePanel()
          else ...[
            if (_growth != null &&
                _growth!.confidence.maturity.recordingCount > 0) ...[
              ArchiveGrowthCard(
                confidence: _growth!.confidence,
                compact: true,
                showExplanation: false,
              ),
              const SizedBox(height: 16),
            ],
            ArchivePaywallBody(
              stats: stats,
              busy: _busy,
              showPurchaseSection:
                  !_productsUnavailable && _subscriptionsAvailable,
              plansSection: _plansSection(),
              onPrimaryCta: _purchasePreferred,
              onContinueFree: () => context.pop(),
            ),
            if (!_subscriptionsAvailable || _productsUnavailable) ...[
              PaywallUnavailableFallback(
                body: _unavailableBodyText,
                busy: _busy,
                retrying: _offeringsReloading,
                showRetry: _subscriptionsAvailable,
                onRetry: () => unawaited(_load(isRetry: true)),
                onRestore: () => context.push('/restore-purchases'),
                onDismiss: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/record');
                  }
                },
              ),
            ] else if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppTheme.muted, height: 1.4),
              ),
            ],
            if (_subscriptionsAvailable && !subscriptionState.isPro) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _busy || _loading
                      ? null
                      : () => context.push('/restore-purchases'),
                  child: Text(ConsumerUiCopy.restorePurchases),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _proActivePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ArchivePaywallCopy.proActiveTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Text(
          ArchivePaywallCopy.proActiveBody,
          style: const TextStyle(color: AppTheme.muted, height: 1.45),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => context.pop(),
          child: const Text(ConsumerUiCopy.paywallBackToPatterns),
        ),
      ],
    );
  }
}

enum BillingPeriod { monthly, yearly }
