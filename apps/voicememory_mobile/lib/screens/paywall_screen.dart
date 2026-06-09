import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../api/api_error_message.dart';
import '../config/screenshot_mode.dart';
import '../billing/archive_paywall_plans.dart';
import '../billing/paywall_attribution_event.dart';
import '../billing/paywall_attribution_store.dart';
import '../billing/paywall_route_args.dart';
import '../billing/paywall_source.dart';
import '../design/archive_responsive_layout.dart';
import '../design/archive_mobile_typography.dart';
import '../features/activation/activation_tracker.dart';
import '../billing/revenuecat_service.dart';
import '../billing/subscription_copy.dart';
import '../product/consumer_ui_copy.dart';
import '../features/first25/first25_user_metrics.dart';
import '../models/entitlement.dart';
import '../services/app_services.dart';
import '../theme/voicememory_colors.dart';
import '../theme/voicememory_typography.dart';
import '../widgets/pushed_screen_shell.dart';
import '../widgets/archive_paywall/paywall_unavailable_fallback.dart';

/// Production RevenueCat paywall — ArchiveMe Pro monthly / yearly.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, this.triggerArgs, this.attributionStore});

  /// Trigger-specific preview copy when opened from a memory limit gate.
  final PaywallRouteArgs? triggerArgs;

  /// Injectable for tests; defaults to the live prefs-backed store.
  final PaywallAttributionStore? attributionStore;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

enum _PaywallPlan { monthly, yearly }

class _PaywallScreenState extends State<PaywallScreen> {
  static const Duration _loadTimeout = Duration(seconds: 12);
  static const String _entitlementLabel = 'ArchiveMe Pro';

  static final _benefits = ConsumerUiCopy.paywallBullets
      .map(
        (b) => _PaywallBenefit(Icons.check_circle_outline, b),
      )
      .toList();

  Offerings? _offerings;
  PremiumEntitlements? _entitlements;
  bool _loading = true;
  bool _busy = false;
  bool _paywallSeenTracked = false;
  String? _error;
  _PaywallPlan _selected = _PaywallPlan.yearly;

  bool get _billingReady => RevenueCatService.instance.isConfigured;

  /// Source-aware copy variant, when the opener passed a [PaywallSource].
  PaywallSourceCopy? get _sourceCopy {
    final source = widget.triggerArgs?.source;
    return source == null ? null : PaywallSourceCopy.forSource(source);
  }

  PaywallSource get _attributionSource =>
      widget.triggerArgs?.source ?? PaywallSource.generalPro;

  PaywallAttributionStore? get _attribution =>
      widget.attributionStore ??
      (AppServices.isInitialized ? PaywallAttributionStore.instance() : null);

  /// Fire-and-forget local attribution write; no-op when services are absent.
  void _recordAttribution(PaywallAttributionEventType type) {
    final store = _attribution;
    if (store == null) return;
    unawaited(
      store.record(
        type,
        source: _attributionSource,
        sourceRoute: widget.triggerArgs?.sourceRoute,
      ),
    );
  }

  String get _unavailableBodyText {
    if (!_billingReady) return ConsumerUiCopy.paywallBillingNotConfigured;
    final err = _error;
    if (err != null &&
        err != SubscriptionCopy.paywallNoOfferings &&
        err != SubscriptionCopy.temporarilyUnavailable) {
      return err;
    }
    return ConsumerUiCopy.paywallSetupUnavailableBody;
  }

  bool get _hasPackages {
    final packages = _offerings?.current?.availablePackages;
    return packages != null && packages.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _recordAttribution(PaywallAttributionEventType.paywallSeen);
    _load();
  }

  Package? _packageFor(_PaywallPlan plan, [Offerings? offerings]) {
    final current = (offerings ?? _offerings)?.current;
    if (current == null) return null;
    for (final p in current.availablePackages) {
      if (plan == _PaywallPlan.monthly && p.packageType == PackageType.monthly) {
        return p;
      }
      if (plan == _PaywallPlan.yearly && p.packageType == PackageType.annual) {
        return p;
      }
    }
    return null;
  }

  bool _hasPackagesIn(Offerings? offerings) {
    final packages = offerings?.current?.availablePackages;
    return packages != null && packages.isNotEmpty;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    if (!_billingReady && !ScreenshotMode.enabled) {
      _trackPaywallSeen(PremiumEntitlements.free());
      setState(() {
        _loading = false;
        _entitlements = PremiumEntitlements.free();
        _offerings = null;
        _error = ConsumerUiCopy.paywallBillingNotConfigured;
      });
      return;
    }
    if (ScreenshotMode.enabled) {
      setState(() {
        _loading = false;
        _entitlements = PremiumEntitlements.free();
        _offerings = null;
        _error = null;
      });
      return;
    }

    final rc = RevenueCatService.instance;
    Offerings? offerings;
    PremiumEntitlements entitlements = PremiumEntitlements.free();
    String? error;

    try {
      offerings = await rc
          .fetchOfferings()
          .timeout(_loadTimeout, onTimeout: () => null);
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
    _trackPaywallSeen(entitlements);

    final monthly = _packageFor(_PaywallPlan.monthly, offerings);
    final yearly = _packageFor(_PaywallPlan.yearly, offerings);
    var selected = _selected;
    if (yearly == null && monthly != null) {
      selected = _PaywallPlan.monthly;
    } else if (yearly != null) {
      selected = _PaywallPlan.yearly;
    }

    setState(() {
      _offerings = offerings;
      _entitlements = entitlements;
      _loading = false;
      _selected = selected;
      _error = error;
      if (!_hasPackagesIn(offerings) && error == null) {
        _error = SubscriptionCopy.paywallNoOfferings;
      }
    });
    if (_hasPackagesIn(offerings) && entitlements.isPro == false) {
      _trackPlansShown();
    }
  }

  void _trackPaywallSeen(PremiumEntitlements entitlements) {
    if (_paywallSeenTracked || entitlements.isPro) return;
    _paywallSeenTracked = true;
    ActivationTracker.trackPaywallShown();
    final preview = widget.triggerArgs?.valuePreview;
    if (preview != null) {
      ActivationTracker.trackProValuePreviewShown(preview.typeId);
    }
    First25UserMetrics.trackPaywallSeen(surface: 'paywall_screen');
  }

  void _trackPlansShown() {
    final monthly = _packageFor(_PaywallPlan.monthly);
    final yearly = _packageFor(_PaywallPlan.yearly);
    if (yearly != null) ActivationTracker.trackAnnualPlanShown();
    if (monthly != null) ActivationTracker.trackMonthlyPlanShown();
  }

  void _trackPlanSelected(_PaywallPlan plan) {
    if (plan == _PaywallPlan.yearly) {
      ActivationTracker.trackAnnualPlanSelected();
    } else {
      ActivationTracker.trackMonthlyPlanSelected();
    }
  }

  Future<void> _continue() async {
    _recordAttribution(PaywallAttributionEventType.purchaseStarted);
    final package = _packageFor(_selected);
    if (package == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(SubscriptionCopy.paywallNoOfferings)),
      );
      return;
    }

    setState(() => _busy = true);
    _trackPlanSelected(_selected);
    ActivationTracker.trackPaywallContinueTapped();
    final period = _selected == _PaywallPlan.monthly ? 'monthly' : 'yearly';
    First25UserMetrics.trackPaywallStarted(
      surface: 'paywall_screen',
      period: period,
    );

    try {
      final ent = await AppServices.instance.billing.purchaseNative(package);
      if (ent.isPro) {
        _recordAttribution(PaywallAttributionEventType.purchaseCompleted);
        await First25UserMetrics.trackPaywallPurchased(
          surface: 'paywall_screen',
          period: period,
        );
      }
      if (!mounted) return;
      if (ent.isPro) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_entitlementLabel is now active.')),
        );
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    _recordAttribution(PaywallAttributionEventType.restoreStarted);
    if (!_billingReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(SubscriptionCopy.temporarilyUnavailable)),
      );
      return;
    }

    setState(() => _busy = true);
    ActivationTracker.trackRestoreTapped();
    try {
      final ent = await AppServices.instance.billing.restoreNative();
      if (!mounted) return;
      if (ent.isPro) {
        _recordAttribution(PaywallAttributionEventType.restoreCompleted);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_entitlementLabel restored.')),
        );
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active subscription found for this account.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingErrorMessage(e, fallback: 'Restore failed. Try again.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: _entitlementLabel,
      body: ListView(
        padding: ArchiveResponsiveLayout.pagePadding(context),
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_entitlements?.isPro == true)
            _proActiveBody()
          else if (ScreenshotMode.enabled)
            _screenshotPaywallBody()
          else if (!_billingReady || !_hasPackages)
            _unavailableBody()
          else
            _paywallBody(),
        ],
      ),
    );
  }

  Widget _proActiveBody() {
    return Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Icon(Icons.verified_outlined, size: 48, color: VoiceMemoryColors.success),
          const SizedBox(height: 12),
          Text(
            '$_entitlementLabel is active',
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            ConsumerUiCopy.paywallProActiveBody,
            style: ArchiveMobileTypography.responsiveBody(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text(ConsumerUiCopy.paywallBackToPatterns),
          ),
        ],
      ),
    );
  }

  Widget _unavailableBody() {
    final sourceCopy = _sourceCopy;
    return PaywallUnavailableFallback(
      headline: sourceCopy?.headline,
      subhead: sourceCopy?.subheadline,
      body: _unavailableBodyText,
      busy: _busy,
      showRetry: _billingReady,
      onRetry: _load,
      onRestore: _restore,
    );
  }

  Widget _screenshotPaywallBody() {
    return Builder(
      builder: (context) => ArchiveResponsiveLayout.constrainContent(
        context: context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ConsumerUiCopy.paywallHeadline,
              style: ArchiveMobileTypography.responsivePageTitle(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              ConsumerUiCopy.paywallSubhead,
              style: ArchiveMobileTypography.responsiveBody(context),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ArchiveResponsiveLayout.gap(context) + 6),
            ..._benefits.map(_benefitRow),
            const SizedBox(height: 20),
            _mockPlanCard(
              context: context,
              title: ArchivePaywallPlanCopy.annualLabel,
              price: '\$49.99 / year',
              helper: ArchivePaywallPlanCopy.annualHelper,
            ),
            const SizedBox(height: 10),
            _mockPlanCard(
              context: context,
              title: ArchivePaywallPlanCopy.monthlyLabel,
              price: '\$9.99 / month',
              helper: ArchivePaywallPlanCopy.monthlyHelper,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: null,
              child: const Text(ConsumerUiCopy.paywallContinue),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: null,
              child: const Text('Restore purchases'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mockPlanCard({
    required BuildContext context,
    required String title,
    required String price,
    String? helper,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ArchiveMobileTypography.listTitle(context)),
                const SizedBox(height: 4),
                Text(
                  price,
                  style: ArchiveMobileTypography.explanationBody(context),
                ),
                if (helper != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    helper,
                    style: ArchiveMobileTypography.responsiveHelper(context),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paywallBody() {
    final monthly = _packageFor(_PaywallPlan.monthly);
    final yearly = _packageFor(_PaywallPlan.yearly);
    final triggerArgs = widget.triggerArgs;
    final valuePreview = triggerArgs?.valuePreview;
    final sourceCopy = _sourceCopy;
    final headline = sourceCopy?.headline ??
        (triggerArgs?.hasTriggerCopy == true
            ? triggerArgs!.previewTitle!
            : ConsumerUiCopy.paywallHeadline);
    final subhead = sourceCopy?.subheadline ??
        (triggerArgs?.hasTriggerCopy == true
            ? triggerArgs!.previewBody!
            : ConsumerUiCopy.paywallSubhead);
    final benefitRows = sourceCopy != null
        ? sourceCopy.bullets
            .map((b) => _PaywallBenefit(Icons.check_circle_outline, b))
            .toList()
        : valuePreview != null
            ? valuePreview.previewBullets
                .map((b) => _PaywallBenefit(Icons.check_circle_outline, b))
                .toList()
            : _benefits;

    return ArchiveResponsiveLayout.constrainContent(
      context: context,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          headline,
          style: ArchiveMobileTypography.responsivePageTitle(context),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          subhead,
          style: ArchiveMobileTypography.responsiveBody(context),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: ArchiveResponsiveLayout.gap(context) + 6),
        ...benefitRows.map(_benefitRow),
        const SizedBox(height: 24),
        ...orderedPaywallPlans(
          hasAnnual: yearly != null,
          hasMonthly: monthly != null,
        ).map((kind) {
          final plan = kind == PaywallPlanKind.annual
              ? _PaywallPlan.yearly
              : _PaywallPlan.monthly;
          final package = kind == PaywallPlanKind.annual ? yearly! : monthly!;
          return Padding(
            padding: EdgeInsets.only(
              bottom: kind == PaywallPlanKind.annual && monthly != null ? 12 : 0,
            ),
            child: _planCard(
              context: context,
              plan: plan,
              title: kind == PaywallPlanKind.annual
                  ? ArchivePaywallPlanCopy.annualLabel
                  : ArchivePaywallPlanCopy.monthlyLabel,
              helper: kind == PaywallPlanKind.annual
                  ? ArchivePaywallPlanCopy.annualHelper
                  : ArchivePaywallPlanCopy.monthlyHelper,
              price: package.storeProduct.priceString,
            ),
          );
        }),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(
            _error!,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
              color: VoiceMemoryColors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _continue,
          style: FilledButton.styleFrom(
            backgroundColor: VoiceMemoryColors.primaryIndigo,
            foregroundColor: VoiceMemoryColors.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: VoiceMemoryColors.onPrimary,
                  ),
                )
              : Text(
                  sourceCopy?.cta ?? ConsumerUiCopy.paywallPrimaryCta,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _busy
              ? null
              : () {
                  ActivationTracker.trackPaywallDismissed();
                  First25UserMetrics.trackPaywallDismissed(
                    surface: 'paywall_screen',
                  );
                  context.pop();
                },
          child: const Text(ConsumerUiCopy.paywallSecondaryCta),
        ),
        TextButton(
          onPressed: _busy ? null : _restore,
          child: Text(ConsumerUiCopy.restorePurchases),
        ),
      ],
      ),
    );
  }

  Widget _benefitRow(_PaywallBenefit benefit) {
    return Builder(
      builder: (context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(benefit.icon, size: 22, color: VoiceMemoryColors.primaryIndigo),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              benefit.label,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _planCard({
    required BuildContext context,
    required _PaywallPlan plan,
    required String title,
    required String price,
    required String helper,
  }) {
    final selected = _selected == plan;
    final isYearly = plan == _PaywallPlan.yearly;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy
            ? null
            : () {
                setState(() => _selected = plan);
                _trackPlanSelected(plan);
              },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? VoiceMemoryColors.surface
                : VoiceMemoryColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? VoiceMemoryColors.primaryIndigo
                  : VoiceMemoryColors.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: isYearly && selected
                ? [
                    BoxShadow(
                      color: VoiceMemoryColors.primaryIndigo.withValues(
                        alpha: 0.12,
                      ),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected
                    ? VoiceMemoryColors.primaryIndigo
                    : VoiceMemoryColors.textTertiary,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ArchiveMobileTypography.listTitle(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price,
                      style: ArchiveMobileTypography.explanationBody(
                        context,
                        color: selected
                            ? VoiceMemoryColors.primaryIndigo
                            : VoiceMemoryColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      helper,
                      style: ArchiveMobileTypography.responsiveHelper(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaywallBenefit {
  const _PaywallBenefit(this.icon, this.label);
  final IconData icon;
  final String label;
}
