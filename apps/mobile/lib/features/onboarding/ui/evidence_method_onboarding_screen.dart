import 'package:archiveme_mobile/features/onboarding/ui/evidence_method_onboarding_copy.dart';
import 'package:archiveme_mobile/onboarding/onboarding_visuals.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Cited-evidence explainer wired into first-run onboarding.
class EvidenceMethodOnboardingScreen extends StatelessWidget {
  const EvidenceMethodOnboardingScreen({
    required this.onContinue,
    super.key,
  });

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        key: const Key('evidence_method_onboarding_screen'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      EvidenceMethodOnboardingCopy.title,
                      style: OnboardingTypography.title(context),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      EvidenceMethodOnboardingCopy.body,
                      style: OnboardingTypography.body(
                        context,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final bullet in const [
                      EvidenceMethodOnboardingCopy.bullet1,
                      EvidenceMethodOnboardingCopy.bullet2,
                      EvidenceMethodOnboardingCopy.bullet3,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  '),
                            Expanded(
                              child: Text(
                                bullet,
                                style: OnboardingTypography.body(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            FilledButton(
              key: const Key('evidence_method_onboarding_continue'),
              onPressed: onContinue,
              child: const Text(EvidenceMethodOnboardingCopy.continueCta),
            ),
          ],
        ),
      ),
    );
  }
}
