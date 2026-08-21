import 'dart:async';

import 'package:archiveme_mobile/l10n/localized_consumer_ui.dart';
import 'package:archiveme_mobile/api/api_error_message.dart';
import 'package:archiveme_mobile/billing/archive_paywall_copy.dart';
import 'package:archiveme_mobile/billing/archive_paywall_plans.dart';
import 'package:archiveme_mobile/billing/paywall_attribution_event.dart';
import 'package:archiveme_mobile/billing/paywall_attribution_store.dart';
import 'package:archiveme_mobile/billing/paywall_objection_follow_up.dart';
import 'package:archiveme_mobile/billing/paywall_rejection_reason.dart';
import 'package:archiveme_mobile/billing/paywall_route_args.dart';
import 'package:archiveme_mobile/billing/paywall_session_tracker.dart';
import 'package:archiveme_mobile/billing/paywall_source.dart';
import 'package:archiveme_mobile/billing/purchase_intent_return_cue.dart';
import 'package:archiveme_mobile/billing/restore_purchases_copy.dart';
import 'package:archiveme_mobile/billing/restore_purchases_feedback.dart';
import 'package:archiveme_mobile/billing/restore_purchases_flow.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/billing/subscription_copy.dart';
import 'package:archiveme_mobile/billing/suggestion_attribution_event.dart';
import 'package:archiveme_mobile/billing/suggestion_attribution_store.dart';
import 'package:archiveme_mobile/billing/v1/app_services_paywall_dependencies.dart';
import 'package:archiveme_mobile/billing/v1/paywall_controller.dart';
import 'package:archiveme_mobile/billing/v1/paywall_plan.dart' show PaywallPlan;
import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/app_review/archive_app_review_session.dart';
import 'package:archiveme_mobile/features/early_archive/early_archive_proof_analytics.dart';
import 'package:archiveme_mobile/features/first25/first25_user_metrics.dart';
import 'package:archiveme_mobile/features/paywall/archive_loop_entitlements.dart';
import 'package:archiveme_mobile/features/paywall_cta_lift/paywall_cta_lift_engine.dart';
import 'package:archiveme_mobile/features/paywall_objection_handling/paywall_objection_engine.dart';
import 'package:archiveme_mobile/features/paywall_objection_handling/paywall_objection_model.dart';
import 'package:archiveme_mobile/features/paywall_value_sharpening/paywall_value_sharpening_analytics.dart';
import 'package:archiveme_mobile/features/paywall_value_sharpening/paywall_value_sharpening_copy.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/delayed_paywall_proof_store.dart';
import 'package:archiveme_mobile/features/pro_packaging/pro_value_copy.dart';
import 'package:archiveme_mobile/features/pro_packaging/pro_value_engine.dart';
import 'package:archiveme_mobile/features/pro_packaging/pro_value_model.dart';
import 'package:archiveme_mobile/features/pro_value/pro_value_copy.dart';
import 'package:archiveme_mobile/features/referral/invite_funnel_metrics.dart';
import 'package:archiveme_mobile/features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_analytics.dart';
import 'package:archiveme_mobile/features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_model.dart';
import 'package:archiveme_mobile/features/revenue_metrics/revenue_funnel_analytics.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/widgets/account/archive_me_pro_value_section.dart';
import 'package:archiveme_mobile/widgets/archive_paywall/paywall_unavailable_fallback.dart';
import 'package:archiveme_mobile/widgets/billing/paywall_objection_follow_up_card.dart';
import 'package:archiveme_mobile/widgets/billing/paywall_rejection_prompt.dart';
import 'package:archiveme_mobile/widgets/billing/paywall_subscription_details_section.dart';
import 'package:archiveme_mobile/widgets/billing/plan_selection_confidence_block.dart';
import 'package:archiveme_mobile/widgets/paywall/purchase_confidence_card.dart';
import 'package:archiveme_mobile/widgets/pro/paywall_cta_lift_block.dart';
import 'package:archiveme_mobile/widgets/pro/paywall_objection_section.dart';
import 'package:archiveme_mobile/widgets/paywall/archive_intelligence_pro_paywall.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    this.delayedPaywallProofGateOverride,
    this.sessionTracker,
    this.objectionFollowUp,
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

  /// Injectable delayed paywall gate for tests; defaults to live proof milestones.
  final bool Function()? delayedPaywallProofGateOverride;

  /// Injectable session tracker for tests; defaults to [livePaywallSessionTracker].
  final PaywallSessionTracker? sessionTracker;

  /// Injectable follow-up gate for tests; defaults to a tracker-backed instance.
  final PaywallObjectionFollowUp? objectionFollowUp;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  static const Duration _loadTimeout = Duration(seconds: 12);
  static const String _entitlementLabel = ProPackagingCopy.title;

  static final List<_PaywallBenefit> _benefits = ConsumerUiCopy.paywallBullets
      .map((b) => _PaywallBenefit(Icons.check_circle_outline, b))
      .toList();

  late final PaywallController _paywallController = PaywallController(
    dependencies: AppServicesPaywallDependencies(
      billingReady: widget.billingReadyOverride,
    ),
  );

  late final PaywallObjectionFollowUp _objectionFollowUp =
      widget.objectionFollowUp ??
      PaywallObjectionFollowUp(
        sessionTracker: widget.sessionTracker ?? livePaywallSessionTracker,
      );

  PaywallState get _ps => _paywallController.state;

  RestorePurchasesFlow? _restoreFlow;
  bool _paywallSeenTracked = false;
  PaywallRejectionReason? _objectionFollowUpReason;
  bool _purchaseAttemptedThisSession = false;
  bool _delayedPaywallGateResolved = false;

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

  /// Anchor positioning line, directly under the headline on every variant —
  /// "longer verified timeline", never "more chat" or a promised outcome.
  Widget _paywallPositioningLine() {
    return Builder(
      builder: (context) => Text(
        PaywallValueSharpeningCopy.anchorPositioningLine,
        key: const Key('paywall_positioning_line'),
        style: ArchiveMobileTypography.responsiveSectionTitle(context),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Concise Free-vs-Pro comparison — replaces a plain repeated benefit list
  /// so the paywall states the actual split once instead of restating Pro
  /// benefits in multiple separate blocks.
  Widget _freeVsProComparisonSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: ArchiveMeProValueSection(
        key: const Key('paywall_free_vs_pro_comparison'),
        packaging: _packaging,
        showTitle: false,
        compact: true,
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
        _paywallPositioningLine(),
        const SizedBox(height: 8),
        _paywallPrimaryValueBlock(),
        if (includeBullets) ...[
          const SizedBox(height: 14),
          _freeVsProComparisonSection(),
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

  bool get _purchasePlansAvailable => _ps.purchasePlansAvailable;

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
      case PaywallAttributionEventType.purchaseStarted:
        InviteFunnelMetrics.purchaseStarted();
      case PaywallAttributionEventType.purchaseCompleted:
        InviteFunnelMetrics.purchaseCompleted();
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
    final err = _ps.errorMessage;
    if (err == SubscriptionCopy.paywallNoOfferings ||
        err == SubscriptionCopy.temporarilyUnavailable) {
      return '${ConsumerUiCopy.paywallSetupUnavailableBody}\n\n'
          '${ConsumerUiCopy.paywallUnavailablePlansLoading}';
    }
    if (err != null) return err;
    return '${ConsumerUiCopy.paywallSetupUnavailableBody}\n\n'
        '${ProPackagingCopy.offeringsUnavailableBody}';
  }

  String? get _monthlyPriceString => _ps.priceStringFor(PaywallPlan.monthly);

  String? get _yearlyPriceString => _ps.priceStringFor(PaywallPlan.yearly);

  Widget _subscriptionDetailsSection({required bool plansAvailable}) {
    return PaywallSubscriptionDetailsSection(
      monthlyPrice: _monthlyPriceString,
      yearlyPrice: _yearlyPriceString,
      plansAvailable: plansAvailable,
    );
  }

  Future<void> _load({bool isRetry = false}) async {
    if (!mounted) return;
    setState(() {});
    await _paywallController.loadOfferings(isRetry: isRetry);
    if (!mounted) return;
    final entitlements = _ps.entitlements ?? PremiumEntitlements.free();
    _trackPaywallSeen(entitlements);
    if (_ps.purchasePlansAvailable && !entitlements.isPro) {
      _trackPlansShown();
    }
    if (mounted) setState(() {});
  }

  bool _passesDelayedPaywallProofGate() {
    final override = widget.delayedPaywallProofGateOverride;
    if (override != null) return override();
    if (ScreenshotMode.enabled) return true;
    if (ArchiveAppReviewSession.isActive) return true;
    return DelayedPaywallProofStore.passesGate;
  }

  Future<void> _resolveDelayedPaywallGate() async {
    if (widget.delayedPaywallProofGateOverride == null &&
        !ScreenshotMode.enabled &&
        !DelayedPaywallProofStore.isGateBypassedForTesting) {
      await DelayedPaywallProofStore.ensureLoaded();
    }
    if (!mounted) return;
    if (!_passesDelayedPaywallProofGate()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
        } else {
          router.go('/record');
        }
      });
      return;
    }
    setState(() => _delayedPaywallGateResolved = true);
    _startPaywallSession();
  }

  void _startPaywallSession() {
    _recordAttribution(
      PaywallAttributionEventType.paywallSeen,
      suggestionStage: SuggestionAttributionEventType.suggestionToPaywallSeen,
    );
    unawaited(_loadObjectionFollowUp());
    unawaited(_load());
  }

  @override
  void initState() {
    super.initState();
    unawaited(_resolveDelayedPaywallGate());
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
    if (!_objectionFollowUp.shouldShow(
      isPro: _ps.entitlements?.isPro == true,
      reason: reason,
    )) {
      return;
    }
    _objectionFollowUp.markShown();
    setState(() => _objectionFollowUpReason = reason);
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
    unawaited(First25UserMetrics.trackPaywallSeen(surface: 'paywall_screen'));
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
    final monthly = _ps.packageFor(PaywallPlan.monthly);
    final yearly = _ps.packageFor(PaywallPlan.yearly);
    if (yearly != null) ActivationTracker.trackAnnualPlanShown();
    if (monthly != null) ActivationTracker.trackMonthlyPlanShown();
  }

  void _trackPlanSelected(PaywallPlan plan) {
    if (plan == PaywallPlan.yearly) {
      ActivationTracker.trackAnnualPlanSelected();
    } else {
      ActivationTracker.trackMonthlyPlanSelected();
    }
  }

  /// Stable plan id for analytics — never user text.
  String _planIdFor(PaywallPlan plan) => plan == PaywallPlan.yearly
      ? PaywallPlanSelectionConfidence.yearlyPlanId
      : PaywallPlanSelectionConfidence.monthlyPlanId;

  Future<void> _continue() async {
    _purchaseAttemptedThisSession = true;
    _recordAttribution(
      PaywallAttributionEventType.purchaseStarted,
      suggestionStage:
          SuggestionAttributionEventType.suggestionToPurchaseStarted,
    );
    final package = _ps.packageFor(_ps.selectedPlan);
    if (package == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(SubscriptionCopy.paywallNoOfferings)),
      );
      return;
    }

    setState(() {});

    RevenueFunnelAnalytics.paywallPurchaseCtaTapped(
      source: _attributionSource.id,
      isPro: _ps.entitlements?.isPro == true,
    );
    ActivationTracker.trackPaywallContinueTapped();
    // Purchase intent: remember the start (stable ids only) and suppress
    // the return cue for the rest of this session — cancelling the App
    // Store sheet never triggers an immediate nudge.
    PurchaseIntentReturnCue.purchaseStartedThisSession = true;
    unawaited(
      _purchaseIntentStore.recordPurchaseStarted(
        source: _attributionSource.id,
        plan: _planIdFor(_ps.selectedPlan),
      ),
    );
    final period = _ps.selectedPlan == PaywallPlan.monthly
        ? 'monthly'
        : 'yearly';
    await First25UserMetrics.trackPaywallStarted(
      surface: 'paywall_screen',
      period: period,
    );

    try {
      final ent = await _paywallController.purchaseSelectedPackage();
      if (ent == null) return;
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
    } catch (e, stackTrace) {
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
      if (mounted) setState(() {});
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
    if (flow.isBusy || _ps.isBusy) return;

    await _paywallController.beginRestore();
    if (mounted) setState(() {});
    RevenueFunnelAnalytics.paywallRestoreTapped(
      source: _attributionSource.id,
      isPro: _ps.entitlements?.isPro == true,
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
      if (!mounted) return;
      RestorePurchasesFeedback.showSnackBar(context, result);
    } finally {
      await _paywallController.endRestore();
      if (mounted) setState(() {});
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
      isPro: _ps.entitlements?.isPro == true,
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

  /// Header restore action so "Restore purchases" is reachable without
  /// scrolling past the rest of the page. Icon-only (tooltip carries the
  /// visible label) so it never duplicates the bottom text button's label
  /// for `find.text` uniqueness in existing tests.
  Widget? _headerRestoreAction() {
    if (_ps.loadingOfferings || _ps.entitlements?.isPro == true) return null;
    return IconButton(
      key: const Key('paywall_header_restore_action'),
      icon: const Icon(Icons.restore),
      tooltip: ConsumerUiCopy.restorePurchases,
      onPressed: _ps.isBusy ? null : _restore,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_delayedPaywallGateResolved) {
      return const SizedBox.shrink();
    }
    final restoreAction = _headerRestoreAction();
    return PushedScreenShell(
      title: _entitlementLabel,
      onBack: () => unawaited(_dismissWithCapture()),
      showBottomDone: false,
      actions: restoreAction == null ? null : [restoreAction],
      body: _paywallShellBody(),
    );
  }

  Widget _paywallShellBody() {
    if (_ps.loadingOfferings) {
      return ListView(
        padding: ArchiveResponsiveLayout.pagePadding(context),
        children: [
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
          ),
        ],
      );
    }
    if (_ps.entitlements?.isPro == true) {
      return ListView(
        padding: ArchiveResponsiveLayout.pagePadding(context),
        children: [_proActiveBody()],
      );
    }
    if (ScreenshotMode.enabled) {
      return ListView(
        padding: ArchiveResponsiveLayout.pagePadding(context),
        children: [_screenshotPaywallBody()],
      );
    }
    if (!_purchasePlansAvailable) {
      return ListView(
        padding: ArchiveResponsiveLayout.pagePadding(context),
        children: [_unavailableBody()],
      );
    }
    return _paywallBody();
  }

  Widget _proActiveBody() {
    return Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Icon(
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
            child: Text(context.l10n.paywallBackToPatterns),
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
          busy: _ps.isBusy,
          retrying: _ps.offeringsReloading,
          showRetry: _billingReady,
          onRetry: () => unawaited(_load(isRetry: true)),
          onRestore: _restore,
          onDismiss: () => unawaited(_dismissWithCapture()),
          primaryDismissLabel: packaging.continueCta,
          hideBenefits: true,
        ),
        if (_objectionFollowUpReason != null) ...[
          const SizedBox(height: 14),
          _aboveFoldClaritySection(),
          const SizedBox(height: 14),
          _objectionFollowUpSection(),
        ],
        if (_paywallObjectionSectionResult.shouldShow) ...[
          const SizedBox(height: 14),
          _paywallObjectionSection(),
        ],
        if (_showsPurchaseConfidenceCard) ...[
          const SizedBox(height: 14),
          _purchaseConfidenceSection(),
        ],
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
                const Icon(
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
    for (final plan in PaywallPlan.values) {
      final intro = _ps.packageFor(plan)?.storeProduct.introductoryPrice;
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
                    const Icon(
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
            context.l10n.paywallDifferentiation,
            key: const Key('paywall_differentiation'),
            style: ArchiveMobileTypography.responsiveBody(context),
            textAlign: TextAlign.center,
          ),
          if (includeTrustLine) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.paywallTrust,
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
              context.l10n.paywallHeadline,
              style: ArchiveMobileTypography.responsivePageTitle(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.paywallSubhead,
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
              price: r'$49.99 / year',
              helper: ArchivePaywallPlanCopy.annualHelper,
            ),
            const SizedBox(height: 10),
            _mockPlanCard(
              context: context,
              title: ArchivePaywallPlanCopy.monthlyLabel,
              price: r'$9.99 / month',
              helper: ArchivePaywallPlanCopy.monthlyHelper,
            ),
            const SizedBox(height: 16),
            _subscriptionDetailsSection(plansAvailable: false),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: null,
              child: Text(context.l10n.paywallContinue),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: null,
              child: Text(context.l10n.restorePurchases),
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
    final monthly = _ps.packageFor(PaywallPlan.monthly);
    final yearly = _ps.packageFor(PaywallPlan.yearly);
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
    final paywallCtaLiftResult = PaywallCtaLiftEngine.build(
      source: widget.triggerArgs?.source,
      analyticsSource: _attributionSource.id,
      isPro: _ps.entitlements?.isPro == true,
    );

    if (showPackagingSection) {
      return ArchiveIntelligenceProPaywall(
        headline: ProValueCopy.headline,
        subheadline: ProValueCopy.subheadline,
        positioningLine: PaywallValueSharpeningCopy.anchorPositioningLine,
        selectedPlan: _ps.selectedPlan,
        monthlyPrice: _monthlyPriceString,
        yearlyPrice: _yearlyPriceString,
        hasMonthly: monthly != null,
        hasYearly: yearly != null,
        onPlanSelected: (plan) {
          setState(() => _paywallController.selectPlan(plan));
          _trackPlanSelected(plan);
          ActivationFunnelAnalytics.track(
            ActivationFunnelAnalytics.paywallPlanSelected,
            source: _attributionSource.id,
            plan: _planIdFor(plan),
          );
        },
        onPurchase: _continue,
        onDismiss: () {
          RevenueFunnelAnalytics.paywallDismissed(
            source: _attributionSource.id,
            isPro: _ps.entitlements?.isPro == true,
          );
          ActivationTracker.trackPaywallDismissed();
          unawaited(
            First25UserMetrics.trackPaywallDismissed(surface: 'paywall_screen'),
          );
          unawaited(_dismissWithCapture());
        },
        onRestore: _restore,
        purchaseInFlight: _ps.purchaseInFlight,
        isBusy: _ps.isBusy,
        ctaLabel: packaging.continueCta,
        surface: 'subscription',
        confirmLine: PaywallPriceConfidenceCopy.confirmLine,
        errorMessage: _ps.errorMessage,
        extraScrollContent: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _freeVsProComparisonSection(),
            const SizedBox(height: 14),
            _paywallDifferentiationAndTrustSection(
              includeTrustLine: !_showsPurchaseConfidenceCard,
            ),
            const SizedBox(height: 10),
            _paywallBackupLine(),
          ],
        ),
      );
    }

    return ArchiveIntelligenceProPaywall(
      headline: headline,
      subheadline: subhead,
      positioningLine: PaywallValueSharpeningCopy.anchorPositioningLine,
      selectedPlan: _ps.selectedPlan,
      monthlyPrice: _monthlyPriceString,
      yearlyPrice: _yearlyPriceString,
      hasMonthly: monthly != null,
      hasYearly: yearly != null,
      onPlanSelected: (plan) {
        setState(() => _paywallController.selectPlan(plan));
        _trackPlanSelected(plan);
        ActivationFunnelAnalytics.track(
          ActivationFunnelAnalytics.paywallPlanSelected,
          source: _attributionSource.id,
          plan: _planIdFor(plan),
        );
      },
      onPurchase: _continue,
      onDismiss: () {
        RevenueFunnelAnalytics.paywallDismissed(
          source: _attributionSource.id,
          isPro: _ps.entitlements?.isPro == true,
        );
        ActivationTracker.trackPaywallDismissed();
        unawaited(
          First25UserMetrics.trackPaywallDismissed(surface: 'paywall_screen'),
        );
        unawaited(_dismissWithCapture());
      },
      onRestore: _restore,
      purchaseInFlight: _ps.purchaseInFlight,
      isBusy: _ps.isBusy,
      ctaLabel: sourceCopy?.cta ?? ConsumerUiCopy.paywallPrimaryCta,
      surface: 'subscription',
      confirmLine: PaywallPriceConfidenceCopy.confirmLine,
      errorMessage: _ps.errorMessage,
      extraScrollContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_usesGeneralConversionClarity)
            _generalConversionClaritySection(includeBullets: false)
          else
            _freeVsProComparisonSection(),
          if (_objectionFollowUpReason != null) ...[
            const SizedBox(height: 14),
            _objectionFollowUpSection(),
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
          if (PaywallProofPreview.showFor(widget.triggerArgs?.source)) ...[
            const SizedBox(height: 14),
            _proofPreviewSection(),
          ],
          if (_showsPurchaseConfidenceCard) ...[
            const SizedBox(height: 14),
            _purchaseConfidenceSection(),
          ],
          const SizedBox(height: 14),
          _confidenceSection(),
          const SizedBox(height: 10),
          PlanSelectionConfidenceBlock(
            selectedPlanId: _planIdFor(_ps.selectedPlan),
            source: widget.triggerArgs?.source?.id,
          ),
          const SizedBox(height: 10),
          _priceConfidenceLines(),
          if (paywallCtaLiftResult.shouldShow) ...[
            const SizedBox(height: 10),
            Text(
              paywallCtaLiftResult.purchaseCtaLine,
              key: const Key('paywall_cta_lift_purchase_line'),
              textAlign: TextAlign.center,
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
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
}

class _PaywallBenefit {
  const _PaywallBenefit(this.icon, this.label);
  final IconData icon;
  final String label;
}