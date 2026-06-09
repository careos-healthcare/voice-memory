import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../onboarding/onboarding_pages.dart';
import '../onboarding/onboarding_visuals.dart';
import '../product/consumer_ui_copy.dart';
import '../features/retention/retention_metrics_tracker.dart';
import '../router/onboarding_gate.dart';
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
      if (!mounted) return;
      context.go('/onboarding-intent');
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  void _advance() {
    if (_isLast || _completing) return;
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
                      const Spacer(),
                      if (!_isLast)
                        TextButton(
                          onPressed: _completing ? null : _complete,
                          child: const Text('Skip'),
                        ),
                    ],
                  ),
                ),
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
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    children: [
                      for (var i = 0; i < OnboardingPages.pageCount; i++)
                        Expanded(
                          child: Container(
                            margin: EdgeInsets.only(
                              right: i < OnboardingPages.pageCount - 1 ? 6 : 0,
                            ),
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: i <= _index
                                  ? AppColors.accentPrimary
                                      .withValues(alpha: 0.9)
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
                    onPressed: _completing
                        ? null
                        : (_isLast ? _complete : _advance),
                    child: Text(
                      _isLast
                          ? ConsumerUiCopy.onboardingFinalCta
                          : ConsumerUiCopy.onboardingContinueCta,
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
