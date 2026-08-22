import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:archiveme_mobile/features/acquisition/audience_wedge_model.dart';
import 'package:archiveme_mobile/features/acquisition/audience_wedge_store.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_coordinator.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';

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
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('onboarding_intent_skip'),
                  onPressed: _busy ? null : () => _finish(context),
                  child: const Text(ConsumerUiCopy.acquisitionIntentSkip),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                ConsumerUiCopy.acquisitionIntentQuestion,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontSize: 26, height: 1.3),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ListView(
                  children: [
                    for (final wedge in AudienceWedgeIds.onboardingChoices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: OutlinedButton(
                          key: Key('onboarding_intent_${wedge.name}'),
                          onPressed: _busy
                              ? null
                              : () => _finish(context, wedge: wedge),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            alignment: Alignment.centerLeft,
                          ),
                          child: Text(wedge.label),
                        ),
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
