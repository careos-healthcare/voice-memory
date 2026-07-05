import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/onboarding/first_session_onboarding_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Dismissible first-session loop explainer — Record tab, zero entries only.
class FirstSessionOnboardingCard extends StatelessWidget {
  const FirstSessionOnboardingCard({
    super.key,
    required this.onStartMoment,
    required this.onExploreFirst,
  });

  final VoidCallback onStartMoment;
  final VoidCallback onExploreFirst;

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final stepTitleStyle = ArchiveMobileTypography.cardLabel(context);
    final stepBodyStyle = bodyStyle.copyWith(color: AppColors.textSecondary);
    final secondaryStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );

    return Container(
      key: const Key('first_session_onboarding_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF6F4FF)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            FirstSessionOnboardingCopy.title,
            key: const Key('first_session_onboarding_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            FirstSessionOnboardingCopy.body,
            key: const Key('first_session_onboarding_body'),
            style: bodyStyle.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < FirstSessionOnboardingCopy.steps.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            _StepBlock(
              index: i,
              title: FirstSessionOnboardingCopy.steps[i].title,
              body: FirstSessionOnboardingCopy.steps[i].body,
              titleStyle: stepTitleStyle,
              bodyStyle: stepBodyStyle,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            FirstSessionOnboardingCopy.notChatFootnote,
            key: const Key('first_session_onboarding_not_chat_footnote'),
            style: secondaryStyle,
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('first_session_onboarding_start_cta'),
              onPressed: onStartMoment,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentPrimary,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(FirstSessionOnboardingCopy.startCta),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('first_session_onboarding_explore_cta'),
              onPressed: onExploreFirst,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                FirstSessionOnboardingCopy.exploreCta,
                style: secondaryStyle.copyWith(
                  decoration: TextDecoration.underline,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBlock extends StatelessWidget {
  const _StepBlock({
    required this.index,
    required this.title,
    required this.body,
    required this.titleStyle,
    required this.bodyStyle,
  });

  final int index;
  final String title;
  final String body;
  final TextStyle titleStyle;
  final TextStyle bodyStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${index + 1}. $title',
          key: Key('first_session_onboarding_step_title_$index'),
          style: titleStyle,
        ),
        const SizedBox(height: 2),
        Text(
          body,
          key: Key('first_session_onboarding_step_body_$index'),
          style: bodyStyle,
        ),
      ],
    );
  }
}
