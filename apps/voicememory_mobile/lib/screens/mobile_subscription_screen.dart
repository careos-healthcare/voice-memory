import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../api/api_error_message.dart';
import '../billing/archive_paywall_copy.dart';
import '../billing/archive_paywall_stats.dart';
import '../billing/revenuecat_service.dart';
import '../features/first25/first25_user_metrics.dart';
import '../billing/subscription_copy.dart';
import '../design/archive_responsive_layout.dart';
import '../product/consumer_ui_copy.dart';
import '../features/archive_evidence/archive_evidence.dart';
import '../features/archive_v1/archive_v1_builder.dart';
import '../features/archive_v1/archive_v1_models.dart';
import '../models/entitlement.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../features/archive_growth/archive_growth_service.dart';
import '../widgets/archive_growth/archive_growth_card.dart';
import '../widgets/archive_paywall/archive_paywall_body.dart';
import '../widgets/archive_paywall/paywall_unavailable_fallback.dart';
import '../widgets/pushed_screen_shell.dart';

/// Archive intelligence paywall — RevenueCat purchase flow unchanged.
class MobileSubscriptionScreen extends StatefulWidget {
  const MobileSubscriptionScreen({super.key});

  @override
  State<MobileSubscriptionScreen> createState() =>
      _MobileSubscriptionScreenState();
}

class _MobileSubscriptionScreenState extends State<MobileSubscriptionScreen> {
  static const Duration _loadTimeout = Duration(seconds: 12);
  bool _paywallSeenTracked = false;

  Offerings? _offerings;
  PremiumEntitlements? _entitlements;
  ArchivePaywallStats? _paywallStats;
  ArchiveGrowthSnapshot? _growth;
  bool _loading = true;
  bool _busy = false;
  bool _productsUnavailable = false;
  String? _error;

  bool get _subscriptionsAvailable => RevenueCatService.instance.isConfigured;

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

  bool _hasStorePackages(Offerings? offerings) {
    final packages = offerings?.current?.availablePackages;
    return packages != null && packages.isNotEmpty;
  }

  Future<ArchivePaywallStats> _loadArchiveStats(
    List<JournalEntry> entries,
  ) async {
    ArchiveV1View? v1;
    if (archiveHasMinimumEvidence(entries)) {
      v1 = await const ArchiveV1Builder().build(
        entries: entries,
        evolutionService: AppServices.instance.beliefEvolution,
      );
    }
    return ArchivePaywallStats.fromEntries(entries: entries, archiveV1: v1);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _productsUnavailable = false;
    });

    ArchivePaywallStats stats = const ArchivePaywallStats(
      recordingCount: 0,
      spanDays: 1,
      recurringThemeCount: 0,
      activeTheoryCount: 0,
      changeCount: 0,
      contradictionCount: 0,
    );

    ArchiveGrowthSnapshot? growth;
    try {
      final entries = await AppServices.instance.journal.loadAll();
      stats = await _loadArchiveStats(entries);
      growth = await ArchiveGrowthService.load();
    } catch (_) {
      // Paywall still renders with fallbacks.
    }

    if (!_subscriptionsAvailable) {
      setState(() {
        _paywallStats = stats;
        _growth = growth;
        _loading = false;
        _productsUnavailable = true;
        _error = SubscriptionCopy.temporarilyUnavailable;
        _entitlements = PremiumEntitlements.free();
      });
      _trackSubscriptionPaywallSeen(PremiumEntitlements.free());
      return;
    }

    final rc = RevenueCatService.instance;
    Offerings? offerings;
    PremiumEntitlements entitlements = PremiumEntitlements.free();
    String? error;

    try {
      offerings = await rc.fetchOfferings().timeout(
        _loadTimeout,
        onTimeout: () => null,
      );
      entitlements = await AppServices.instance.billing
          .loadEntitlements(forceRefresh: true)
          .timeout(_loadTimeout, onTimeout: () => PremiumEntitlements.free());
    } on TimeoutException {
      error = 'Loading timed out. Please try again in a moment.';
      entitlements = rc.latestEntitlements;
    } catch (e) {
      error = userFacingErrorMessage(
        e,
        fallback: 'Could not load subscription details.',
      );
      entitlements = rc.latestEntitlements;
    }

    if (!mounted) return;
    final productsOk = _hasStorePackages(offerings);
    _trackSubscriptionPaywallSeen(entitlements);
    setState(() {
      _offerings = offerings;
      _entitlements = entitlements;
      _paywallStats = stats;
      _growth = growth;
      _loading = false;
      _productsUnavailable = !productsOk;
      _error = error;
      if (!productsOk && error == null) {
        _error = SubscriptionCopy.temporarilyUnavailable;
      }
    });
  }

  Package? _packageForBillingPeriod(BillingPeriod period) {
    final current = _offerings?.current;
    if (current == null) return null;
    for (final p in current.availablePackages) {
      if (p.packageType == PackageType.monthly &&
          period == BillingPeriod.monthly) {
        return p;
      }
      if (p.packageType == PackageType.annual &&
          period == BillingPeriod.yearly) {
        return p;
      }
    }
    return null;
  }

  void _trackSubscriptionPaywallSeen(PremiumEntitlements entitlements) {
    if (_paywallSeenTracked || entitlements.isPro) return;
    _paywallSeenTracked = true;
    First25UserMetrics.trackPaywallSeen(surface: 'subscription_screen');
  }

  Future<void> _purchase(BillingPeriod period) async {
    final package = _packageForBillingPeriod(period);
    if (package == null) {
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
      final ent = await AppServices.instance.billing.purchaseNative(package);
      if (ent.isPro) {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingErrorMessage(
                e,
                fallback: 'Purchase could not be completed.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _purchasePreferred() {
    final yearly = _packageForBillingPeriod(BillingPeriod.yearly);
    if (yearly != null) {
      _purchase(BillingPeriod.yearly);
      return;
    }
    final monthly = _packageForBillingPeriod(BillingPeriod.monthly);
    if (monthly != null) {
      _purchase(BillingPeriod.monthly);
    }
  }

  Widget? _plansSection() {
    if (_productsUnavailable) return null;
    final monthly = _packageForBillingPeriod(BillingPeriod.monthly);
    final yearly = _packageForBillingPeriod(BillingPeriod.yearly);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (yearly != null)
          _planOutlineButton(
            label: 'Yearly',
            price: yearly.storeProduct.priceString,
            onPressed: _busy ? null : () => _purchase(BillingPeriod.yearly),
          ),
        if (monthly != null) ...[
          const SizedBox(height: 8),
          _planOutlineButton(
            label: 'Monthly',
            price: monthly.storeProduct.priceString,
            onPressed: _busy ? null : () => _purchase(BillingPeriod.monthly),
          ),
        ],
      ],
    );
  }

  Widget _planOutlineButton({
    required String label,
    required String price,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(price, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = _entitlements ?? PremiumEntitlements.free();
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
          else if (e.isPro)
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
                showRetry: _subscriptionsAvailable,
                onRetry: _load,
                onRestore: () => context.push('/restore-purchases'),
              ),
            ] else if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppTheme.muted, height: 1.4),
              ),
            ],
            if (_subscriptionsAvailable && !e.isPro) ...[
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
