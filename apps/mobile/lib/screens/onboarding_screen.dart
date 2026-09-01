import 'dart:async';

import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_consent_boundary.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_hooks.dart';
import 'package:archiveme_mobile/features/onboarding/remote_processing_consent_decision.dart';
import 'package:archiveme_mobile/features/onboarding/ui/evidence_method_onboarding_screen.dart';
import 'package:archiveme_mobile/features/onboarding/ui/on_device_hero_screen.dart';
import 'package:archiveme_mobile/features/onboarding/ui/remote_processing_consent_step.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/retention/retention_metrics_tracker.dart';
import 'package:archiveme_mobile/onboarding/onboarding_pages.dart';
import 'package:archiveme_mobile/onboarding/onboarding_visuals.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/router/onboarding_gate.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;
  bool _completing = false;

  /// True once the customer has swiped/tapped past the last regular page
  /// into the dedicated remote-processing consent step. That step is
  /// deliberately not just another `OnboardingPageData` entry in the same
  /// `PageView.builder` (see `onboarding_pages.dart`): its two buttons carry
  /// a real decision (see `_recordConsentDecision`) rather than only ever
  /// advancing forward, so it needs its own screen state and its own CTA
  /// row instead of reusing the generic "Continue"/"Start my archive"
  /// button below.
  bool _showingEvidenceMethodStep = false;
  bool _showingConsentStep = false;

  /// True once the consent decision is persisted and the confirmation hero is
  /// on screen. This is the last step before `/record`, so it is the screen
  /// that owns the "into the app" CTA — see [_complete].
  bool _showingOnDeviceHero = false;

  /// The consent answer, so the last screen can confirm it instead of
  /// restating the architecture essay.
  bool _allowedRemote = false;

  static const int _conceptualStepCount = 4;

  bool get _isLast => _index >= OnboardingPages.pageCount - 1;

  /// Which of the [_conceptualStepCount] progress dots is current. The extra
  /// steps live in this widget's state rather than in `OnboardingPages`, so the
  /// dot row cannot read the page index alone.
  int get _stepIndex {
    if (_showingOnDeviceHero) return 3;
    if (_showingConsentStep) return 2;
    if (_showingEvidenceMethodStep) return 1;
    return _index;
  }

  @override
  void initState() {
    super.initState();
    unawaited(BetaAnalyticsHooks.onboardingViewed());
    unawaited(RetentionMetricsTracker.track(RetentionMetricsTracker.onboardingStarted));
  }

  Future<void> _complete() async {
    if (_completing) return;
    setState(() => _completing = true);
    try {
      await RetentionMetricsTracker.track(
        RetentionMetricsTracker.onboardingCompleted,
      );
      await AppServices.instance.prefs.setOnboardingCompleted(true);
      onboardingGate.markComplete();
      if (!mounted) return;
      context.go('/record');
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  /// Persists the customer's explicit remote-processing consent decision
  /// before completing onboarding, so the very first save this account or
  /// guest namespace ever makes already has a real answer for
  /// `CapturePipelineService`'s live consent gate to read — never the
  /// pre-consent default.
  Future<void> _recordConsentDecision(bool allow) async {
    if (_completing) return;
    setState(() => _completing = true);
    try {
      await OnboardingRemoteProcessingDecision.record(
        allow: allow,
        consentStore: RemoteProcessingConsentStore(AppServices.instance.prefs),
      );
      await BetaAnalyticsConsentBoundary.recordOnboardingConsent(granted: allow);
    } finally {
      if (mounted) setState(() => _completing = false);
    }
    if (!mounted) return;
    // The decision is recorded; the hero confirms that choice and
    // carries the only CTA that reaches `/record`.
    setState(() {
      _allowedRemote = allow;
      _showingConsentStep = false;
      _showingOnDeviceHero = true;
    });
  }

  void _advance() {
    if (_completing) return;
    if (_isLast) {
      setState(() => _showingEvidenceMethodStep = true);
      return;
    }
    unawaited(_controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    ));
  }

  void _advanceFromEvidenceMethod() {
    if (_completing) return;
    setState(() {
      _showingEvidenceMethodStep = false;
      _showingConsentStep = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: OnboardingAmbientGlow()),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.xs,
                    AppSpacing.xs,
                    0,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'ArchiveMe',
                        style: OnboardingTypography.label(
                          color: AppColors.accentPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showingOnDeviceHero)
                  Expanded(
                    child: OnDeviceHeroScreen(
                      allowedRemote: _allowedRemote,
                      submitting: _completing,
                      onContinue: () => unawaited(_complete()),
                    ),
                  )
                else if (_showingConsentStep)
                  Expanded(
                    child: RemoteProcessingConsentStep(
                      submitting: _completing,
                      onDecision: _recordConsentDecision,
                    ),
                  )
                else if (_showingEvidenceMethodStep)
                  Expanded(
                    child: EvidenceMethodOnboardingScreen(
                      onContinue: _advanceFromEvidenceMethod,
                    ),
                  )
                else ...[
                  Expanded(
                    child: PageView.builder(
                      key: const Key('onboarding_page_view'),
                      controller: _controller,
                      itemCount: OnboardingPages.pageCount,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) {
                        final page = OnboardingPages.pages[i];
                        return KeyedSubtree(
                          key: Key('onboarding_page_$i'),
                          child: _OnboardingPage(page: page),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < _conceptualStepCount; i++)
                          Expanded(
                            child: Container(
                              margin: EdgeInsets.only(
                                right: i < _conceptualStepCount - 1 ? 6 : 0,
                              ),
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: _stepIndex >= i
                                    ? AppColors.accentPrimary.withValues(
                                        alpha: 0.9,
                                      )
                                    : AppColors.borderSubtle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: FilledButton(
                      key: const Key('onboarding_primary_cta'),
                      onPressed: _completing ? null : _advance,
                      child: const Text(ConsumerUiCopy.onboardingContinueCta),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.page});

  final OnboardingPageData page;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: OnboardingLayout.maxContentWidth,
              minHeight: constraints.maxHeight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(page.title, style: OnboardingTypography.title(context)),
                SizedBox(height: OnboardingTypography.sectionGap(context)),
                Text(page.body, style: OnboardingTypography.body(context)),
                const SizedBox(height: AppSpacing.md),
                OnboardingPageVisual(page: page),
              ],
            ),
          ),
        );
      },
    );
  }
}