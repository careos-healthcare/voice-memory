import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/loop_mode/loop_mode_coordinator.dart';
import '../features/loop_mode/loop_mode_model.dart';
import '../features/proof_admission/remote_processing_consent_store.dart';
import '../features/onboarding/remote_processing_consent_step.dart';
import '../onboarding/onboarding_pages.dart';
import '../onboarding/onboarding_visuals.dart';
import '../product/consumer_ui_copy.dart';
import '../features/retention/retention_metrics_tracker.dart';
import '../router/onboarding_gate.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

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
  bool _showingConsentStep = false;

  bool get _isLast => _index >= OnboardingPages.pageCount - 1;

  @override
  void initState() {
    super.initState();
    RetentionMetricsTracker.track(RetentionMetricsTracker.onboardingStarted);
  }

  Future<void> _complete() async {
    if (_completing) return;
    setState(() => _completing = true);
    try {
      await RetentionMetricsTracker.track(
        RetentionMetricsTracker.onboardingCompleted,
      );
      await LoopModeCoordinator.activate(LoopModeIds.proveEnough);
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
      final store = RemoteProcessingConsentStore(AppServices.instance.prefs);
      if (allow) {
        await store.grant();
      } else {
        await store.withdraw();
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
    await _complete();
  }

  void _advance() {
    if (_completing) return;
    if (_isLast) {
      setState(() => _showingConsentStep = true);
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
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
                if (_showingConsentStep)
                  Expanded(
                    child: RemoteProcessingConsentStep(
                      submitting: _completing,
                      onDecision: (allow) => _recordConsentDecision(allow),
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
                        for (var i = 0; i < OnboardingPages.pageCount; i++)
                          Expanded(
                            child: Container(
                              margin: EdgeInsets.only(
                                right: i < OnboardingPages.pageCount - 1
                                    ? 6
                                    : 0,
                              ),
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: i <= _index
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
                      child: Text(
                        _isLast
                            ? ConsumerUiCopy.onboardingFinalCta
                            : ConsumerUiCopy.onboardingContinueCta,
                      ),
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
