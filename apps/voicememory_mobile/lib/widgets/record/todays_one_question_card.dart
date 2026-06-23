import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/todays_question/todays_question_copy.dart';
import '../../features/todays_question/todays_question_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact today's one question card on Record — metadata only.
class TodaysOneQuestionCard extends StatelessWidget {
  const TodaysOneQuestionCard({
    super.key,
    required this.question,
    this.onPrimary,
    this.onViewFull,
  });

  final TodaysQuestionResult question;
  final VoidCallback? onPrimary;
  final VoidCallback? onViewFull;

  @override
  Widget build(BuildContext context) {
    if (!question.showOnRecord) {
      return const SizedBox.shrink(
        key: Key('todays_one_question_card_hidden'),
      );
    }

    return Container(
      key: const Key('todays_one_question_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary.withValues(alpha: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question.eyebrow,
            key: const Key('todays_one_question_card_eyebrow'),
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            question.questionText,
            key: const Key('todays_one_question_card_question'),
            style: ArchiveMobileTypography.body(context).copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            question.helperText,
            key: const Key('todays_one_question_card_helper'),
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('todays_one_question_card_primary_button'),
            onPressed: onPrimary,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: Text(question.primaryCtaLabel),
          ),
          if (onViewFull != null) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              key: const Key('todays_one_question_card_view_button'),
              onPressed: onViewFull,
              child: Text(
                question.secondaryCtaLabel ?? TodaysQuestionCopy.viewQuestionCta,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
