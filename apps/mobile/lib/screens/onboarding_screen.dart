import 'dart:async';

import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_consent_boundary.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_hooks.dart';
import 'package:archiveme_mobile/features/onboarding/remote_processing_consent_decision.dart';
import 'package:archiveme_mobile/features/onboarding/ui/remote_processing_consent_copy.dart';
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
  bool _completing = false;

  /// Screen 2 — the send choice. The two buttons persist consent and
  /// complete onboarding; there is no confirmation encore.
  bool _showingConsentStep = false;

  static const int _conceptualStepCount = 2;

  int get _stepIndex => _showingConsentStep ? 1 : 0;

  @override
  void initState() {
    super.initState();
    unawaited(BetaAnalyticsHooks.onboardingViewed());
    unawaited(
      RetentionMetricsTracker.track(RetentionMetricsTracker.onboardingStarted),
    );
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

  /// Persists the send answer, then opens Record. The capture surface
  /// reads this gate — it must not ask the same question again.
  Future<void> _recordConsentDecision(bool allow) async {
    if (_completing) return;
    setState(() => _completing = true);
    try {
      await OnboardingRemoteProcessingDecision.record(
        allow: allow,
        consentStore: RemoteProcessingConsentStore(AppServices.instance.prefs),
      );
      await BetaAnalyticsConsentBoundary.recordOnboardingConsent(
        granted: allow,
      );
    } finally {
      if (mounted) setState(() => _completing = false);
    }
    if (!mounted) return;
    await _complete();
  }

  void _advance() {
    if (_completing) return;
    setState(() => _showingConsentStep = true);
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
                Expanded(
                  child: _showingConsentStep
                      ? RemoteProcessingConsentStep(
                          submitting: _completing,
                          showActions: false,
                          onDecision: _recordConsentDecision,
                        )
                      : _OnboardingPage(page: OnboardingPages.pages.first),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Row(
                    key: const Key('onboarding_progress_dots'),
                    children: [
                      for (var i = 0; i < _conceptualStepCount; i++)
                        Expanded(
                          child: Container(
                            key: Key('onboarding_progress_dot_$i'),
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
                  child: _showingConsentStep
                      ? _ChoiceActions(
                          submitting: _completing,
                          onDecision: _recordConsentDecision,
                        )
                      : FilledButton(
                          key: const Key('onboarding_primary_cta'),
                          onPressed: _completing ? null : _advance,
                          child: const Text(
                            ConsumerUiCopy.onboardingContinueCta,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceActions extends StatelessWidget {
  const _ChoiceActions({
    required this.submitting,
    required this.onDecision,
  });

  final bool submitting;
  final ValueChanged<bool> onDecision;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          RemoteProcessingConsentCopy.changeLaterFootnote,
          key: Key('remote_processing_consent_change_later'),
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          key: const Key('remote_processing_consent_allow'),
          style: RemoteProcessingConsentStep.buttonStyle,
          onPressed: submitting ? null : () => onDecision(true),
          child: const Text(RemoteProcessingConsentCopy.allowCta),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          key: const Key('remote_processing_consent_decline'),
          style: RemoteProcessingConsentStep.buttonStyle,
          onPressed: submitting ? null : () => onDecision(false),
          child: const Text(RemoteProcessingConsentCopy.declineCta),
        ),
      ],
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
