import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/acquisition/audience_wedge_model.dart';
import '../features/acquisition/audience_wedge_store.dart';
import '../features/loop_mode/loop_mode_coordinator.dart';
import '../onboarding/onboarding_visuals.dart';
import '../product/consumer_ui_copy.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Optional pressure-loop question before loop selection.
class OnboardingIntentScreen extends StatefulWidget {
  const OnboardingIntentScreen({super.key});

  @override
  State<OnboardingIntentScreen> createState() => _OnboardingIntentScreenState();
}

class _OnboardingIntentScreenState extends State<OnboardingIntentScreen> {
  bool _busy = false;

  Future<void> _finish(BuildContext context, {AudienceWedge? wedge}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (wedge != null) {
        await AudienceWedgeStore.instance().save(wedge);
        await LoopModeCoordinator.activate(wedge.mappedLoopId);
      }
      if (!context.mounted) return;
      context.go('/onboarding-loop');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('onboarding_intent_skip'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: _busy ? null : () => _finish(context),
                  child: const Text(ConsumerUiCopy.acquisitionIntentSkip),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                ConsumerUiCopy.acquisitionIntentQuestion,
                style: OnboardingTypography.title(context),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final wedge in AudienceWedgeIds.onboardingChoices)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: OutlinedButton(
                    key: Key('onboarding_intent_${wedge.name}'),
                    onPressed: _busy
                        ? null
                        : () => _finish(context, wedge: wedge),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 14,
                      ),
                      alignment: Alignment.centerLeft,
                    ),
                    child: Text(wedge.label),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
