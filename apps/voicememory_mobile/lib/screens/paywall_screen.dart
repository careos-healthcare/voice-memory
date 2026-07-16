import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../api/api_error_message.dart';
import '../config/screenshot_mode.dart';
import '../billing/archive_paywall_copy.dart';
import '../billing/archive_paywall_plans.dart';
import '../billing/paywall_attribution_event.dart';
import '../features/referral/invite_funnel_metrics.dart';
import '../billing/paywall_attribution_store.dart';
import '../billing/paywall_objection_follow_up.dart';
import '../billing/paywall_rejection_reason.dart';
import '../billing/purchase_intent_return_cue.dart';
import '../billing/paywall_route_args.dart';
import '../billing/paywall_source.dart';
import '../billing/suggestion_attribution_event.dart';
import '../billing/suggestion_attribution_store.dart';
import '../design/archive_responsive_layout.dart';
import '../design/archive_mobile_typography.dart';
import '../features/activation/activation_tracker.dart';
import '../billing/restore_purchases_copy.dart';
import '../billing/restore_purchases_feedback.dart';
import '../billing/restore_purchases_flow.dart';
import '../billing/revenuecat_diagnostics_log.dart';
import '../billing/revenuecat_service.dart';
import '../billing/revenuecat_offerings_debug_log.dart';
import '../billing/subscription_copy.dart';
import '../product/consumer_ui_copy.dart';
import '../features/early_archive/early_archive_proof_analytics.dart';
import '../features/first25/first25_user_metrics.dart';
import '../features/revenue_metrics/revenue_funnel_analytics.dart';
import '../features/paywall_objection_handling/paywall_objection_engine.dart';
import '../features/paywall_objection_handling/paywall_objection_model.dart';
import '../features/paywall_value_sharpening/paywall_value_sharpening_analytics.dart';
import '../features/paywall_value_sharpening/paywall_value_sharpening_copy.dart';
import '../features/paywall_cta_lift/paywall_cta_lift_engine.dart';
import '../features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_analytics.dart';
import '../features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_model.dart';
import '../widgets/pro/paywall_cta_lift_block.dart';
import '../features/beta_feedback_capture/beta_feedback_capture_engine.dart';
import '../features/beta_feedback_capture/beta_feedback_capture_model.dart';
import '../features/beta_feedback_capture/beta_feedback_capture_store.dart';
import '../models/entitlement.dart';
import '../services/activation_funnel_analytics.dart';
import '../services/app_services.dart';
import '../theme/voicememory_colors.dart';
import '../widgets/billing/paywall_objection_follow_up_card.dart';
import '../widgets/billing/paywall_rejection_prompt.dart';
import '../widgets/billing/plan_selection_confidence_block.dart';
import '../widgets/paywall/purchase_confidence_card.dart';
import '../widgets/pro/paywall_objection_section.dart';
import '../widgets/beta/beta_feedback_capture_card.dart';
import '../widgets/pushed_screen_shell.dart';
import '../features/pro_packaging/pro_value_copy.dart';
import '../features/pro_packaging/pro_value_engine.dart';
import '../features/pro_packaging/pro_value_model.dart';
import '../widgets/archive_paywall/paywall_unavailable_fallback.dart';
import '../widgets/billing/paywall_subscription_details_section.dart';
import '../features/paywall/archive_loop_entitlements.dart';

/// Production RevenueCat paywall — ArchiveMe Pro monthly / yearly.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    this.triggerArgs,
    this.attributionStore,
    this.suggestionAttributionStore,
    this.objectionStore,
    this.purchaseIntentStore,
    this.restoreFlow,
    this.billingConfiguredForRestore,
    this.billingReadyOverride,
  });

  /// Trigger-specific preview copy when opened from a memory limit gate.
  final PaywallRouteArgs? triggerArgs;

  /// Injectable for tests; defaults to the live prefs-backed store.
  final PaywallAttributionStore? attributionStore;

  /// Injectable for tests; defaults to the live prefs-backed store.
  final SuggestionAttributionStore? suggestionAttributionStore;

  /// Injectable for tests; defaults to the live prefs-backed store.
  final PaywallObjectionStore? objectionStore;

  /// Injectable for tests; defaults to the live prefs-backed store.
  final PurchaseIntentStore? purchaseIntentStore;

  /// Injectable restore flow for tests; defaults to live [RestorePurchasesFlow].
  final RestorePurchasesFlow? restoreFlow;

  /// Override RevenueCat configured check for restore-only tests.
  final bool Function()? billingConfiguredForRestore;

  /// Override billing configured for purchase UI tests (offerings still load live).
  final bool Function()? billingReadyOverride;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

enum _PaywallPlan { monthly, yearly }

enum _PaywallBusyKind { none, purchase, restore }

class _PaywallScreenState extends State<PaywallScreen> {
  static const Duration _loadTimeout = Duration(seconds: 12);
  static const String _entitlementLabel = ProPackagingCopy.title;

  static final _benefits = ConsumerUiCopy.paywallBullets
      .map((b) => _PaywallBenefit(Icons.check_circle_outline, b))
      .toList();

  Offerings? _offerings;
  PremiumEntitlements? _entitlements;
  bool _loading = true;
  bool _offeringsReloading = false;
  bool _busy = false;
  _PaywallBusyKind _busyKind = _PaywallBusyKind.none;
  RestorePurchasesFlow? _restoreFlow;
  bool _paywallSeenTracked = false;
  String? _error;
  _PaywallPlan _selected = _PaywallPlan.yearly;

  /// Last captured rejection reason — loaded once at init, so the same flow
  /// that captures a reason can never render its own follow-up.
  PaywallRejectionReason? _objectionFollowUpReason;
  bool _showBetaFeedbackCaptureNoCta = false;
  bool _showBetaFeedbackCapturePurchaseFail = false;
  bool _purchaseAttemptedThisSession = false;

  bool get _usesGeneralConversionClarity {
    final source = widget.triggerArgs?.source;
    return source == null || source == PaywallSource.generalPro;
  }

  bool get _showsPurchaseConfidenceCard => true;

  Widget _purchaseConfidenceSection() {
    return PurchaseConfidenceCard(
      source: _attributionSource.id,
      surface: 'paywall_screen',
    );
  }

  PaywallObjectionSectionResult get _paywallObjectionSectionResult =>
      PaywallObjectionEngine.build(
        source: widget.triggerArgs?.source,
        surface: 'paywall_screen',
      );

  Widget _paywallObjectionSection() {
    return PaywallObjectionSection(result: _paywallObjectionSectionResult);
  }

  Widget _paywallPrimaryValueBlock() {
    return Builder(
      builder: (context) => Text(
        ConsumerUiCopy.paywallPrimaryValueBlock,
        key: const Key('paywall_primary_value_block'),
        style: ArchiveMobileTypography.responsiveBody(context),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _paywallBackupLine() {
    return Builder(
      builder: (context) => Text(
        ConsumerUiCopy.paywallBackupLine,
        key: const Key('paywall_backup_line'),
        style: ArchiveMobileTypography.responsiveHelper(context),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _generalConversionClaritySection({required bool includeBullets}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _paywallPrimaryValueBlock(),
        if (includeBullets) ...[
          const SizedBox(height: 14),
          ..._benefits.map(_benefitRow),
        ],
        const SizedBox(height: 14),
        _paywallDifferentiationAndTrustSection(
          includeTrustLine: !_showsPurchaseConfidenceCard,
        ),
        const SizedBox(height: 10),
        _paywallBackupLine(),
      ],
    );
  }

  bool get _billingReady =>
      widget.billingReadyOverride?.call() ??
      RevenueCatService.instance.isConfigured;

  bool get _restoreBillingReady =>
      widget.billingConfiguredForRestore?.call() ?? _billingReady;

  bool get _purchasePlansAvailable => _billingReady && _hasPackages;

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

  /// True when this paywall was opened from a daily suggestion surface.
  bool get _fromSuggestion =>
      _attributionSource == PaywallSource.dailySuggestion ||
      _attributionSource == PaywallSource.startHereToday;

  SuggestionAttributionStore? get _suggestionAttribution =>
      widget.suggestionAttributionStore ??
      (AppServices.isInitialized
          ? SuggestionAttributionStore.instance()
          : null);

  /// Fire-and-forget local attribution write; no-op when services are absent.
  /// Suggestion-sourced opens also log the suggestion-to-Pro funnel stage.
  void _recordAttribution(
    PaywallAttributionEventType type, {
    SuggestionAttributionEventType? suggestionStage,
  }) {
    // Purchase stages also feed the product funnel — source id only, never
    // user content. paywall_seen already reaches analytics via First25.
    if (type == PaywallAttributionEventType.purchaseStarted ||
        type == PaywallAttributionEventType.purchaseCompleted) {
      ActivationFunnelAnalytics.track(type.id, source: _attributionSource.id);
    }
    // Invited funnel mirror — additive, attribution-gated, carrying only
    // the invite source (never the paywall source or any URL).
    switch (type) {
      case PaywallAttributionEventType.paywallSeen:
        InviteFunnelMetrics.paywallSeen();
        break;
      case PaywallAttributionEventType.purchaseStarted:
        InviteFunnelMetrics.purchaseStarted();
        break;
      case PaywallAttributionEventType.purchaseCompleted:
        InviteFunnelMetrics.purchaseCompleted();
        break;
      default:
        break;
    }
    final store = _attribution;
    if (store != null) {
      unawaited(
        store.record(
          type,
          source: _attributionSource,
          sourceRoute: widget.triggerArgs?.sourceRoute,
        ),
      );
    }
    if (suggestionStage == null || !_fromSuggestion) return;
    final suggestionStore = _suggestionAttribution;
    if (suggestionStore == null) return;
    unawaited(suggestionStore.record(suggestionStage));
  }

  ProPackagingDisplay get _packaging => ProPackagingEngine.build(
        offeringsAvailable: _purchasePlansAvailable,
        showPlanPrices: _purchasePlansAvailable,
      );

  String get _unavailableBodyText {
    if (!_billingReady) {
      return '${ConsumerUiCopy.paywallSetupUnavailableBody}\n\n'
          '${ConsumerUiCopy.paywallUnavailablePlansLoading}';
    }
    final err = _error;
    if (err == SubscriptionCopy.paywallNoOfferings ||
        err == SubscriptionCopy.temporarilyUnavailable) {
      return '${ConsumerUiCopy.paywallSetupUnavailableBody}\n\n'
          '${ConsumerUiCopy.paywallUnavailablePlansLoading}';
    }
    if (err != null) return err;
    return '${ConsumerUiCopy.paywallSetupUnavailableBody}\n\n'
        '${ProPackagingCopy.offeringsUnavailableBody}';
  }

  bool get _hasPackages {
    final packages = _offerings?.current?.availablePackages;
    return packages != null && packages.isNotEmpty;
  }

  String? get _monthlyPriceString =>
      _packageFor(_PaywallPlan.monthly)?.storeProduct.priceString;

  String? get _yearlyPriceString =>
      _packageFor(_PaywallPlan.yearly)?.storeProduct.priceString;

  Widget _subscriptionDetailsSection({required bool plansAvailable}) {
    return PaywallSubscriptionDetailsSection(
      monthlyPrice: _monthlyPriceString,
      yearlyPrice: _yearlyPriceString,
      plansAvailable: plansAvailable,
    );
  }

  Future<PremiumEntitlements> _mergeReviewProEntitlements(
    PremiumEntitlements entitlements,
  ) async {
    if (!AppServices.isInitialized || entitlements.isPro) return entitlements;
    try {
      final loopState =
          await ArchiveLoopEntitlementStore(AppServices.instance.prefs)
              .load()
              .timeout(const Duration(seconds: 2), onTimeout: () {
        return ArchiveLoopEntitlementState.empty;
      });
      if (!loopState.isPro) return entitlements;
      return PremiumEntitlements(
        tier: BillingTier.pro,
        entitlementIds: const [],
        billingConnected: false,
        source: 'app_review',
      );
    } catch (_) {
      return entitlements;
    }
  }

  @override
  void initState() {
    super.initState();
    _recordAttribution(
      PaywallAttributionEventType.paywallSeen,
      suggestionStage: SuggestionAttributionEventType.suggestionToPaywallSeen,
    );
    _loadObjectionFollowUp();
    unawaited(
      BetaFeedbackCaptureStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    _load();
  }

  BetaFeedbackCaptureResult _betaFeedbackCapturePaywallResult({
    required bool paywallNoCtaRequested,
    required bool paywallPurchaseAttempted,
  }) =>
      BetaFeedbackCaptureEngine.build(
        context: BetaFeedbackCaptureEngine.buildContext(
          surface: BetaFeedbackCaptureSurface.paywall,
          source: _attributionSource.id,
          entryCount: 0,
          hasPaywallSeen: _paywallSeenTracked,
          hasPurchaseCtaTapped: _purchaseAttemptedThisSession,
          isPro: _entitlements?.isPro == true,
          paywallNoCtaRequested: paywallNoCtaRequested,
          paywallPurchaseAttempted: paywallPurchaseAttempted,
        ),
      );

  void _handleBetaFeedbackCapturePaywallChanged({required bool dismissAfter}) {
    setState(() {
      _showBetaFeedbackCaptureNoCta = false;
      _showBetaFeedbackCapturePurchaseFail = false;
    });
    if (dismissAfter) {
      unawaited(_dismissWithCapture());
    }
  }

  PaywallObjectionStore get _objectionStore =>
      widget.objectionStore ?? PaywallObjectionStore();

  PurchaseIntentStore get _purchaseIntentStore =>
      widget.purchaseIntentStore ?? PurchaseIntentStore();

  /// Reads the reason stored by a previous paywall visit. Pro users and
  /// repeat renders within one session show nothing; the Pro-active body
  /// additionally never includes the block.
  Future<void> _loadObjectionFollowUp() async {
    final reason = await _objectionStore.lastReason();
    if (!mounted) return;
    if (!PaywallObjectionFollowUp.shouldShow(
      isPro: _entitlements?.isPro == true,
      reason: reason,
    )) {
      return;
    }
    PaywallObjectionFollowUp.shownThisSession = true;
    setState(() => _objectionFollowUpReason = reason);
  }

  Package? _packageFor(_PaywallPlan plan, [Offerings? offerings]) {
    final current = (offerings ?? _offerings)?.current;
    if (current == null) return null;
    for (final p in current.availablePackages) {
      if (plan == _PaywallPlan.monthly &&
          p.packageType == PackageType.monthly) {
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

  Future<void> _load({bool isRetry = false}) async {
    if (!mounted) return;

    RevenueCatOfferingsDebugLog.paywallLoadStarted(
      billingConfigured: _billingReady,
      appServicesInitialized: AppServices.isInitialized,
      screenshotMode: ScreenshotMode.enabled,
    );

    setState(() {
      if (isRetry) {
        _offeringsReloading = true;
      } else {
        _loading = true;
      }
      if (!isRetry) {
        _error = null;
      }
    });

    Offerings? offerings;
    PremiumEntitlements entitlements = PremiumEntitlements.free();
    String? error;
    String loadReason = 'completed';
    var billingConfigured = _billingReady;
    var monthly = null as Package?;
    var yearly = null as Package?;
    var selected = _selected;

    try {
      if (!billingConfigured && !ScreenshotMode.enabled) {
        if (AppServices.isInitialized) {
          try {
            await RevenueCatService.instance
                .initialize()
                .timeout(_loadTimeout);
          } on TimeoutException {
            loadReason = 'configure_timeout';
            RevenueCatDiagnosticsLog.paywallFallback(
              reason: loadReason,
              isRetry: isRetry,
            );
          }
          billingConfigured = RevenueCatService.instance.isConfigured;
        }
        if (!billingConfigured) {
          loadReason = 'billing_not_configured';
          RevenueCatOfferingsDebugLog.paywallLoadEarlyExit(
            reason: loadReason,
          );
          _trackPaywallSeen(PremiumEntitlements.free());
          entitlements = PremiumEntitlements.free();
          error = ConsumerUiCopy.paywallBillingNotConfigured;
          return;
        }
      }

      if (ScreenshotMode.enabled) {
        loadReason = 'screenshot_mode';
        RevenueCatOfferingsDebugLog.paywallLoadEarlyExit(reason: loadReason);
        entitlements = PremiumEntitlements.free();
        return;
      }

      final rc = RevenueCatService.instance;

      try {
        offerings = await rc.fetchOfferings().timeout(
          _loadTimeout,
          onTimeout: () {
            RevenueCatOfferingsDebugLog.fetchOfferingsFinished(
              offerings: null,
              error: 'paywall_fetchOfferings_timeout_${_loadTimeout.inSeconds}s',
            );
            RevenueCatDiagnosticsLog.fetchOfferingsFinished(
              success: false,
              offerings: null,
              error: 'paywall_fetchOfferings_timeout_${_loadTimeout.inSeconds}s',
            );
            return null;
          },
        );
        entitlements = await AppServices.instance.billing
            .loadEntitlements(forceRefresh: true)
            .timeout(_loadTimeout, onTimeout: () => PremiumEntitlements.free());
        entitlements = await _mergeReviewProEntitlements(entitlements);
      } on TimeoutException {
        loadReason = 'load_timeout';
        error = SubscriptionCopy.paywallNoOfferings;
        entitlements = rc.latestEntitlements;
        RevenueCatOfferingsDebugLog.paywallLoadEarlyExit(reason: loadReason);
        RevenueCatDiagnosticsLog.paywallFallback(
          reason: loadReason,
          error: error,
          isRetry: isRetry,
        );
      } catch (e) {
        loadReason = 'load_error';
        error = SubscriptionCopy.paywallNoOfferings;
        entitlements = rc.latestEntitlements;
        RevenueCatOfferingsDebugLog.paywallLoadEarlyExit(reason: loadReason);
        RevenueCatDiagnosticsLog.paywallFallback(
          reason: loadReason,
          error: error,
          isRetry: isRetry,
        );
      }

      if (!mounted) {
        loadReason = 'widget_unmounted_before_render';
        return;
      }

      _trackPaywallSeen(entitlements);

      monthly = _packageFor(_PaywallPlan.monthly, offerings);
      yearly = _packageFor(_PaywallPlan.yearly, offerings);
      if (yearly == null && monthly != null) {
        selected = _PaywallPlan.monthly;
      } else if (yearly != null) {
        selected = _PaywallPlan.yearly;
      }

      if (!_hasPackagesIn(offerings) && error == null) {
        loadReason = 'no_packages_in_current_offering';
        error = SubscriptionCopy.paywallNoOfferings;
        RevenueCatDiagnosticsLog.paywallFallback(
          reason: loadReason,
          error: error,
          isRetry: isRetry,
        );
      } else if (_hasPackagesIn(offerings)) {
        loadReason = 'plans_available';
      }

      if (_hasPackagesIn(offerings) && entitlements.isPro == false) {
        _trackPlansShown();
      }
    } catch (e) {
      loadReason = 'load_unhandled_error';
      error = SubscriptionCopy.paywallNoOfferings;
      RevenueCatDiagnosticsLog.paywallFallback(
        reason: loadReason,
        error: error,
        isRetry: isRetry,
      );
    } finally {
      if (mounted) {
        setState(() {
          _offerings = offerings;
          _entitlements = entitlements;
          _loading = false;
          _offeringsReloading = false;
          _selected = selected;
          _error = error;
        });
      }

      final purchasePlansAvailable =
          billingConfigured && _hasPackagesIn(offerings);
      RevenueCatOfferingsDebugLog.paywallLoadResult(
        billingConfigured: billingConfigured,
        offeringsLoaded: offerings != null,
        offeringCount: offerings?.all.length ?? 0,
        currentOfferingId: offerings?.current?.identifier,
        packageCount: offerings?.current?.availablePackages.length ?? 0,
        monthlyPackageFound: monthly != null,
        annualPackageFound: yearly != null,
        purchasePlansAvailable: purchasePlansAvailable,
        showingUnavailable:
            !purchasePlansAvailable && entitlements.isPro != true,
        reason: loadReason,
        error: error,
      );
      if (!purchasePlansAvailable && entitlements.isPro != true) {
        RevenueCatDiagnosticsLog.paywallFallback(
          reason: loadReason,
          error: error,
          isRetry: isRetry,
        );
      }
    }
  }

  void _trackPaywallSeen(PremiumEntitlements entitlements) {
    if (_paywallSeenTracked || entitlements.isPro) return;
    _paywallSeenTracked = true;
    RevenueFunnelAnalytics.paywallSeen(
      source: _attributionSource.id,
      isPro: entitlements.isPro,
    );
    PaywallValueSharpeningAnalytics.seen(
      source: _attributionSource.id,
      surface: 'paywall_screen',
      proofConnected: PaywallValueSharpeningCopy.isProofConnectedSource(
        _attributionSource,
      ),
    );
    ActivationTracker.trackPaywallShown();
    final preview = widget.triggerArgs?.valuePreview;
    if (preview != null) {
      ActivationTracker.trackProValuePreviewShown(preview.typeId);
    }
    First25UserMetrics.trackPaywallSeen(surface: 'paywall_screen');
    EarlyArchiveProofAnalytics.proScreenOpenedAfterTimeline(
      source: 'paywall_screen',
    );
    if (_attributionSource == PaywallSource.valueMoment) {
      RevenueLiftExperimentV2Analytics.paywallSeen(
        context: RevenueLiftExperimentV2PaywallSeenContext(
          source: _attributionSource.id,
          surface: 'paywall_screen',
          entryCount: 0,
        ),
      );
    }
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

  /// Stable plan id for analytics — never user text.
  String _planIdFor(_PaywallPlan plan) => plan == _PaywallPlan.yearly
      ? PaywallPlanSelectionConfidence.yearlyPlanId
      : PaywallPlanSelectionConfidence.monthlyPlanId;

  Future<void> _continue() async {
    _purchaseAttemptedThisSession = true;
    _recordAttribution(
      PaywallAttributionEventType.purchaseStarted,
      suggestionStage:
          SuggestionAttributionEventType.suggestionToPurchaseStarted,
    );
    final package = _packageFor(_selected);
    if (package == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(SubscriptionCopy.paywallNoOfferings)),
      );
      return;
    }

    setState(() {
      _busy = true;
      _busyKind = _PaywallBusyKind.purchase;
    });
    RevenueFunnelAnalytics.paywallPurchaseCtaTapped(
      source: _attributionSource.id,
      isPro: _entitlements?.isPro == true,
    );
    ActivationTracker.trackPaywallContinueTapped();
    // Purchase intent: remember the start (stable ids only) and suppress
    // the return cue for the rest of this session — cancelling the App
    // Store sheet never triggers an immediate nudge.
    PurchaseIntentReturnCue.purchaseStartedThisSession = true;
    unawaited(
      _purchaseIntentStore.recordPurchaseStarted(
        source: _attributionSource.id,
        plan: _planIdFor(_selected),
      ),
    );
    final period = _selected == _PaywallPlan.monthly ? 'monthly' : 'yearly';
    First25UserMetrics.trackPaywallStarted(
      surface: 'paywall_screen',
      period: period,
    );

    try {
      final ent = await AppServices.instance.billing.purchaseNative(package);
      if (ent.isPro) {
        unawaited(_purchaseIntentStore.recordPurchaseCompleted());
        _recordAttribution(
          PaywallAttributionEventType.purchaseCompleted,
          suggestionStage:
              SuggestionAttributionEventType.suggestionToPurchaseCompleted,
        );
        await First25UserMetrics.trackPaywallPurchased(
          surface: 'paywall_screen',
          period: period,
        );
      }
      if (!mounted) return;
      if (ent.isPro) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(ArchivePaywallCopy.purchaseSuccess)),
        );
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      final failResult = _betaFeedbackCapturePaywallResult(
        paywallNoCtaRequested: false,
        paywallPurchaseAttempted: true,
      );
      if (failResult.shouldShow) {
        setState(() => _showBetaFeedbackCapturePurchaseFail = true);
      }
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
      if (mounted) {
        setState(() {
          _busy = false;
          _busyKind = _PaywallBusyKind.none;
        });
      }
    }
  }

  RestorePurchasesFlow get _effectiveRestoreFlow =>
      widget.restoreFlow ??
      (_restoreFlow ??= RestorePurchasesFlow(
        billing: AppServices.instance.billing,
        isBillingConfigured: () => _restoreBillingReady,
      ));

  Future<void> _restore() async {
    _recordAttribution(PaywallAttributionEventType.restoreStarted);

    if (!AppServices.isInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(RestorePurchasesCopy.restoreError)),
        );
      }
      return;
    }

    final flow = _effectiveRestoreFlow;
    if (flow.isBusy || _busy) return;

    setState(() {
      _busy = true;
      _busyKind = _PaywallBusyKind.restore;
    });
    RevenueFunnelAnalytics.paywallRestoreTapped(
      source: _attributionSource.id,
      isPro: _entitlements?.isPro == true,
    );
    ActivationTracker.trackRestoreTapped();
    try {
      final result = await flow.restore();
      if (!mounted || result.outcome == RestorePurchasesOutcome.skippedBusy) {
        return;
      }
      if (result.outcome == RestorePurchasesOutcome.restored) {
        _recordAttribution(PaywallAttributionEventType.restoreCompleted);
        await _load();
      }
      RestorePurchasesFeedback.showSnackBar(context, result);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyKind = _PaywallBusyKind.none;
        });
      }
    }
  }

  /// Exit paths (back arrow, Done, "Not now") run the one-tap rejection
  /// capture first — never shown to Pro users (covers just-purchased) and at
  /// most once per session. Navigation always follows; nothing blocks.
  Future<void> _dismissWithCapture() async {
    await _maybeCaptureRejection();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/record');
    }
  }

  Future<void> _maybeCaptureRejection() async {
    if (!PaywallRejectionCapture.shouldPrompt(
      isPro: _entitlements?.isPro == true,
    )) {
      return;
    }
    PaywallRejectionCapture.promptShownThisSession = true;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.paywallRejectionPromptSeen,
      source: _attributionSource.id,
    );
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => PaywallRejectionPrompt(
        source: _attributionSource.id,
        // Persist the stable id so the next paywall visit can answer the
        // objection. Never shown in this flow — the screen is popping.
        onReason: (reason) => unawaited(
          _objectionStore.recordRejection(
            reason,
            source: _attributionSource.id,
          ),
        ),
      ),
    );
    // Swipe/barrier dismissal is a skip too — the prompt logged nothing.
    if (result == null) {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.paywallRejectionPromptSkipped,
        source: _attributionSource.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: _entitlementLabel,
      onBack: () => unawaited(_dismissWithCapture()),
      body: ListView(
        padding: ArchiveResponsiveLayout.pagePadding(context),
        children: [
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                  Text(
                    ArchivePaywallCopy.checkingProAccess,
                    style: ArchiveMobileTypography.responsiveBody(context),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else if (_entitlements?.isPro == true)
            _proActiveBody()
          else if (ScreenshotMode.enabled)
            _screenshotPaywallBody()
          else if (!_purchasePlansAvailable)
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
          Icon(
            Icons.verified_outlined,
            size: 48,
            color: VoiceMemoryColors.success,
          ),
          const SizedBox(height: 12),
          Text(
            ArchivePaywallCopy.proActiveTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            ArchivePaywallCopy.proActiveConfirmation,
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
    final packaging = _packaging;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaywallUnavailableFallback(
          headline: sourceCopy?.headline ?? ConsumerUiCopy.paywallHeadline,
          body: _unavailableBodyText,
          busy: _busy,
          retrying: _offeringsReloading,
          showRetry: _billingReady,
          onRetry: () => unawaited(_load(isRetry: true)),
          onRestore: _restore,
          onDismiss: () => unawaited(_dismissWithCapture()),
          primaryDismissLabel: packaging.continueCta,
          hideBenefits: true,
        ),
        const SizedBox(height: 16),
        _subscriptionDetailsSection(plansAvailable: false),
      ],
    );
  }

  /// Long-term archive framing near the plan cards — addresses subscription
  /// resistance by being honest about what kind of product this is.
  Widget _longTermArchiveLine() {
    return Text(
      PaywallAnnualValueCopy.longTermLine,
      key: const Key('paywall_long_term_line'),
      textAlign: TextAlign.center,
      style: ArchiveMobileTypography.responsiveHelper(context),
    );
  }

  /// "Proof you can look for" — observable checks so the user can judge for
  /// themselves whether Pro is helping. Suggestion sources only.
  Widget _proofPreviewSection() {
    return Container(
      key: const Key('paywall_proof_preview'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            PaywallProofPreview.heading,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          for (final row in PaywallProofPreview.rows) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 16,
                  color: VoiceMemoryColors.primaryIndigo,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row,
                    style: ArchiveMobileTypography.responsiveHelper(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// True only when one of the loaded App Store products carries an actual
  /// zero-price introductory offer. No offerings (or paid intro pricing)
  /// means no trial copy — the line is never a generic promise.
  bool get _hasFreeTrialOffer {
    for (final plan in _PaywallPlan.values) {
      final intro = _packageFor(plan)?.storeProduct.introductoryPrice;
      if (intro != null && intro.price == 0) return true;
    }
    return false;
  }

  /// Above-fold clarity: the paid promise in plain words, directly under
  /// the headline and before any plan card or CTA. Same block for every
  /// source so the continuity framing lives in one place.
  Widget _aboveFoldClaritySection() {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.paywallAboveFoldClaritySeen,
      source: widget.triggerArgs?.source?.id,
      oncePerSession: true,
    );
    return Builder(
      builder: (context) => Container(
        key: const Key('paywall_above_fold_clarity'),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: VoiceMemoryColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: VoiceMemoryColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              PaywallAboveFoldClarity.title,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: 8),
            for (final line in PaywallAboveFoldClarity.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: VoiceMemoryColors.primaryIndigo,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        line,
                        style: ArchiveMobileTypography.responsiveBody(context),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              PaywallAboveFoldClarity.freeReassuranceLine,
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
          ],
        ),
      ),
    );
  }

  /// One objection-specific reassurance block — only on a paywall visit
  /// after a rejection reason was captured, below the above-fold clarity
  /// block and above the plan cards. The CTA is untouched.
  Widget _objectionFollowUpSection() {
    return PaywallObjectionFollowUpCard(
      reason: _objectionFollowUpReason!,
      source: widget.triggerArgs?.source?.id,
    );
  }

  /// Price confidence immediately below the plan cards: manage-anytime,
  /// plus the trial handling line only when a real free trial was detected
  /// on a loaded product. Reduces hesitation at the App Store sheet.
  Widget _priceConfidenceLines() {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.priceConfidenceSeen,
      source: widget.triggerArgs?.source?.id,
      oncePerSession: true,
    );
    return Column(
      key: const Key('paywall_price_confidence'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final line in PaywallPriceConfidenceCopy.planLines(
          hasFreeTrial: _hasFreeTrialOffer,
        ))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              line,
              textAlign: TextAlign.center,
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
          ),
      ],
    );
  }

  /// Final price-confidence line directly before the purchase CTA — the App
  /// Store confirms before anything is charged.
  Widget _appStoreConfirmLine() {
    return Text(
      PaywallPriceConfidenceCopy.confirmLine,
      key: const Key('paywall_app_store_confirm_line'),
      textAlign: TextAlign.center,
      style: ArchiveMobileTypography.responsiveHelper(context),
    );
  }

  Widget _paywallDifferentiationAndTrustSection({
    bool includeTrustLine = true,
  }) {
    return Builder(
      builder: (context) => Column(
        key: const Key('paywall_differentiation_trust'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ConsumerUiCopy.paywallDifferentiation,
            key: const Key('paywall_differentiation'),
            style: ArchiveMobileTypography.responsiveBody(context),
            textAlign: TextAlign.center,
          ),
          if (includeTrustLine) ...[
            const SizedBox(height: 8),
            Text(
              ConsumerUiCopy.paywallTrust,
              key: const Key('paywall_trust'),
              style: ArchiveMobileTypography.responsiveHelper(context),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// Final purchase reassurance immediately above the purchase CTA —
  /// reassuring, not defensive. Suggestion sources add the explicit
  /// no-pressure line the post-save receipt already used.
  Widget _confidenceSection() {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.purchaseReassuranceSeen,
      source: widget.triggerArgs?.source?.id,
      oncePerSession: true,
    );
    final lines = PaywallConfidenceCopy.linesFor(
      widget.triggerArgs?.source,
      hasFreeTrial: _hasFreeTrialOffer,
    );
    return Column(
      key: const Key('paywall_confidence_section'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              line,
              textAlign: TextAlign.center,
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
          ),
      ],
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
            _paywallPrimaryValueBlock(),
            const SizedBox(height: 14),
            ..._benefits.map(_benefitRow),
            const SizedBox(height: 14),
            _paywallDifferentiationAndTrustSection(
              includeTrustLine: !_showsPurchaseConfidenceCard,
            ),
            const SizedBox(height: 10),
            _paywallBackupLine(),
            const SizedBox(height: 14),
            _paywallObjectionSection(),
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
            TextButton(onPressed: null, child: const Text('Restore purchases')),
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
    final packaging = _packaging;
    final headline =
        sourceCopy?.headline ??
        (triggerArgs?.hasTriggerCopy == true
            ? triggerArgs!.previewTitle!
            : packaging.title);
    final subhead =
        sourceCopy?.subheadline ??
        (triggerArgs?.hasTriggerCopy == true
            ? triggerArgs!.previewBody!
            : packaging.subtitle);
    final showPackagingSection = sourceCopy == null && valuePreview == null;
    final benefitRows = sourceCopy != null
        ? sourceCopy.bullets
              .map((b) => _PaywallBenefit(Icons.check_circle_outline, b))
              .toList()
        : valuePreview != null
        ? valuePreview.previewBullets
              .map((b) => _PaywallBenefit(Icons.check_circle_outline, b))
              .toList()
        : const <_PaywallBenefit>[];
    final paywallCtaLiftResult = PaywallCtaLiftEngine.build(
      source: widget.triggerArgs?.source,
      analyticsSource: _attributionSource.id,
      isPro: _entitlements?.isPro == true,
    );

    return ArchiveResponsiveLayout.constrainContent(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showPackagingSection) ...[
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
          ] else ...[
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
            const SizedBox(height: 14),
            if (_usesGeneralConversionClarity)
              _generalConversionClaritySection(includeBullets: true)
            else
              _aboveFoldClaritySection(),
          ],
          // Objection follow-up: below the clarity block, above plan cards.
          if (_objectionFollowUpReason != null) ...[
            const SizedBox(height: 14),
            _objectionFollowUpSection(),
          ],
          SizedBox(height: ArchiveResponsiveLayout.gap(context) + 6),
          if (!showPackagingSection &&
              !_usesGeneralConversionClarity &&
              benefitRows.isNotEmpty)
            ...benefitRows.map(_benefitRow),
          if (!showPackagingSection &&
              !_usesGeneralConversionClarity &&
              benefitRows.isNotEmpty) ...[
            const SizedBox(height: 14),
            _paywallDifferentiationAndTrustSection(
              includeTrustLine: !_showsPurchaseConfidenceCard,
            ),
          ],
          if (PaywallAnnualValueCopy.showFor(widget.triggerArgs?.source)) ...[
            const SizedBox(height: 14),
            _longTermArchiveLine(),
          ],
          if (_paywallObjectionSectionResult.shouldShow) ...[
            const SizedBox(height: 14),
            _paywallObjectionSection(),
          ],
          if (paywallCtaLiftResult.shouldShow) ...[
            const SizedBox(height: 14),
            PaywallCtaLiftBlock(result: paywallCtaLiftResult),
          ],
          const SizedBox(height: 24),
          ...orderedPaywallPlans(
            hasAnnual: yearly != null,
            hasMonthly: monthly != null,
          ).map((kind) {
            final plan = kind == PaywallPlanKind.annual
                ? _PaywallPlan.yearly
                : _PaywallPlan.monthly;
            final package = kind == PaywallPlanKind.annual ? yearly! : monthly!;
            final suggestionFraming = PaywallAnnualValueCopy.showFor(
              widget.triggerArgs?.source,
            );
            final useCompactPlanLabels = showPackagingSection;
            return Padding(
              padding: EdgeInsets.only(
                bottom: kind == PaywallPlanKind.annual && monthly != null
                    ? 12
                    : 0,
              ),
              child: _planCard(
                context: context,
                plan: plan,
                title: kind == PaywallPlanKind.annual
                    ? (useCompactPlanLabels
                          ? ArchiveLoopPaywallCopy.subscriptionYearlyTitle
                          : ArchivePaywallPlanCopy.annualLabel)
                    : (useCompactPlanLabels
                          ? ArchiveLoopPaywallCopy.subscriptionMonthlyTitle
                          : ArchivePaywallPlanCopy.monthlyLabel),
                helper: kind == PaywallPlanKind.annual
                    ? (useCompactPlanLabels
                          ? ArchiveLoopPaywallCopy.subscriptionYearlyDuration
                          : suggestionFraming
                                ? PaywallAnnualValueCopy.yearlyHelper
                                : ArchivePaywallPlanCopy.annualHelper)
                    : (useCompactPlanLabels
                          ? ArchiveLoopPaywallCopy.subscriptionMonthlyDuration
                          : suggestionFraming
                                ? PaywallAnnualValueCopy.monthlyHelper
                                : ArchivePaywallPlanCopy.monthlyHelper),
                price: package.storeProduct.priceString,
              ),
            );
          }),
          if (!showPackagingSection) ...[
            // Plan-selection confidence: follows the selected plan, before the
            // purchase CTA.
            const SizedBox(height: 14),
            PlanSelectionConfidenceBlock(
              selectedPlanId: _planIdFor(_selected),
              source: widget.triggerArgs?.source?.id,
            ),
            // Price confidence directly below the plan cards.
            const SizedBox(height: 10),
            _priceConfidenceLines(),
          ],
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
          if (!showPackagingSection && PaywallProofPreview.showFor(widget.triggerArgs?.source)) ...[
            const SizedBox(height: 18),
            _proofPreviewSection(),
          ],
          if (!showPackagingSection && _showsPurchaseConfidenceCard) ...[
            const SizedBox(height: 18),
            _purchaseConfidenceSection(),
          ],
          if (!showPackagingSection) ...[
            const SizedBox(height: 18),
            _confidenceSection(),
          ],
          if (!showPackagingSection && paywallCtaLiftResult.shouldShow) ...[
            const SizedBox(height: 10),
            Text(
              paywallCtaLiftResult.purchaseCtaLine,
              key: const Key('paywall_cta_lift_purchase_line'),
              textAlign: TextAlign.center,
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
          ],
          if (!showPackagingSection) ...[
            // Final price-confidence line directly before the purchase CTA.
            const SizedBox(height: 10),
            _appStoreConfirmLine(),
          ],
          if (showPackagingSection) ...[
            const SizedBox(height: 16),
            _subscriptionDetailsSection(plansAvailable: _purchasePlansAvailable),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _busy ? null : _continue,
            style: FilledButton.styleFrom(
              backgroundColor: VoiceMemoryColors.primaryIndigo,
              foregroundColor: VoiceMemoryColors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _busy && _busyKind == _PaywallBusyKind.purchase
                ? Text(
                    ArchivePaywallCopy.purchaseStarting,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
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
          if (_showBetaFeedbackCapturePurchaseFail) ...[
            const SizedBox(height: 12),
            BetaFeedbackCaptureCard(
              result: _betaFeedbackCapturePaywallResult(
                paywallNoCtaRequested: false,
                paywallPurchaseAttempted: true,
              ),
              onChanged: () => _handleBetaFeedbackCapturePaywallChanged(
                dismissAfter: false,
              ),
            ),
          ] else if (_showBetaFeedbackCaptureNoCta) ...[
            const SizedBox(height: 12),
            BetaFeedbackCaptureCard(
              result: _betaFeedbackCapturePaywallResult(
                paywallNoCtaRequested: true,
                paywallPurchaseAttempted: _purchaseAttemptedThisSession,
              ),
              onChanged: () => _handleBetaFeedbackCapturePaywallChanged(
                dismissAfter: true,
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    RevenueFunnelAnalytics.paywallDismissed(
                      source: _attributionSource.id,
                      isPro: _entitlements?.isPro == true,
                    );
                    ActivationTracker.trackPaywallDismissed();
                    First25UserMetrics.trackPaywallDismissed(
                      surface: 'paywall_screen',
                    );
                    final noCtaResult = _betaFeedbackCapturePaywallResult(
                      paywallNoCtaRequested: true,
                      paywallPurchaseAttempted: _purchaseAttemptedThisSession,
                    );
                    if (noCtaResult.shouldShow) {
                      setState(() => _showBetaFeedbackCaptureNoCta = true);
                      return;
                    }
                    unawaited(_dismissWithCapture());
                  },
            child: const Text(ConsumerUiCopy.paywallSecondaryCta),
          ),
          TextButton(
            onPressed: _busy ? null : _restore,
            child: Text(
              _busy && _busyKind == _PaywallBusyKind.restore
                  ? ArchivePaywallCopy.restoreChecking
                  : ConsumerUiCopy.restorePurchases,
            ),
          ),
          if (!showPackagingSection) ...[
            const SizedBox(height: 16),
            _subscriptionDetailsSection(plansAvailable: _purchasePlansAvailable),
          ],
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
            Icon(
              benefit.icon,
              size: 22,
              color: VoiceMemoryColors.primaryIndigo,
            ),
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
                // Funnel event with the stable plan id only — fired on the
                // explicit tap, never during purchase.
                ActivationFunnelAnalytics.track(
                  ActivationFunnelAnalytics.paywallPlanSelected,
                  source: _attributionSource.id,
                  plan: _planIdFor(plan),
                );
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
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
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
