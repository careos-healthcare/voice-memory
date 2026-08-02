import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../onboarding/onboarding_pages.dart';
import '../onboarding/onboarding_visuals.dart';
import '../features/retention/retention_metrics_tracker.dart';
import '../router/onboarding_gate.dart';
import '../router/route_catalog.dart';
import '../services/app_services.dart';
import '../theme/app_spacing.dart';
import '../theme/archive_semantic_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    this.persistCompletion,
    this.onCaptureSelected,
  });

  final Future<void> Function()? persistCompletion;
  final ValueChanged<String>? onCaptureSelected;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _completing = false;

  Future<void> _complete(String destination, {Object? extra}) async {
    if (_completing) return;
    setState(() => _completing = true);
    try {
      if (widget.persistCompletion case final persist?) {
        await persist();
      } else {
        await AppServices.instance.prefs.setOnboardingCompleted(true);
      }
      onboardingGate.markComplete();
      if (widget.persistCompletion == null) {
        unawaited(
          RetentionMetricsTracker.track(
            RetentionMetricsTracker.onboardingCompleted,
          ),
        );
      }
      if (!mounted) return;
      if (widget.onCaptureSelected case final onCaptureSelected?) {
        onCaptureSelected(destination);
      } else {
        context.go(destination, extra: extra);
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ArchiveSemanticColors.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.background,
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
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: KeyedSubtree(
                      key: const Key('onboarding_promise_screen'),
                      child: _OnboardingPage(page: OnboardingPages.pages.first),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          key: const Key('onboarding_primary_cta'),
                          onPressed: _completing
                              ? null
                              : () => _complete(RouteCatalog.recordHome),
                          child: const Text(OnboardingPages.primaryAction),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        OutlinedButton(
                          key: const Key('onboarding_type_instead_cta'),
                          onPressed: _completing
                              ? null
                              : () => _complete(
                                  RouteCatalog.quickTextCapture,
                                  extra: const {
                                    'returnToRecordAfterSave': true,
                                  },
                                ),
                          child: const Text(OnboardingPages.secondaryAction),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
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
