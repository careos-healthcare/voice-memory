import 'package:archiveme_mobile/features/onboarding/ui/onboarding_v1_copy.dart';
import 'package:archiveme_mobile/onboarding/onboarding_visuals.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Numbered trust pillars shown during first-run onboarding.
class OnboardingTrustPillarsSection extends StatelessWidget {
  const OnboardingTrustPillarsSection({super.key});

  static const Key sectionKey = Key('onboarding_trust_pillars');

  @override
  Widget build(BuildContext context) {
    return Column(
      key: sectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          OnboardingV1Copy.trustPillarsHeading,
          style: OnboardingTypography.label(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < OnboardingV1Copy.trustPillars.length; i++)
          _PillarCard(
            index: i + 1,
            title: OnboardingV1Copy.trustPillars[i].title,
            body: OnboardingV1Copy.trustPillars[i].body,
          ),
      ],
    );
  }
}

class _PillarCard extends StatelessWidget {
  const _PillarCard({
    required this.index,
    required this.title,
    required this.body,
  });

  final int index;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('onboarding_trust_pillar_$index'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$index',
              style: OnboardingTypography.label(color: AppColors.accentPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: OnboardingTypography.label()),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: OnboardingTypography.body(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
