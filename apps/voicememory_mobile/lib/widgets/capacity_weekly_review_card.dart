import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/capacity_loop/capacity_weekly_review_copy.dart';
import '../features/capacity_loop/capacity_weekly_review_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Compact Archive Home card for capacity weekly review — counts only.
class CapacityWeeklyReviewCard extends StatelessWidget {
  const CapacityWeeklyReviewCard({
    super.key,
    required this.result,
    this.onPrimaryAction,
    this.sampleMode = false,
  });

  const CapacityWeeklyReviewCard.test({
    super.key,
    required this.result,
    this.onPrimaryAction,
    this.sampleMode = false,
  });

  final CapacityWeeklyReviewResult result;
  final VoidCallback? onPrimaryAction;
  final bool sampleMode;

  @override
  Widget build(BuildContext context) {
    if (sampleMode ||
        ScreenshotMode.enabled ||
        !result.hasReview ||
        !result.showOnArchiveHome) {
      return const SizedBox.shrink(
        key: Key('capacity_weekly_review_card_hidden'),
      );
    }

    return Container(
      key: const Key('capacity_weekly_review_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CapacityWeeklyReviewCopy.cardEyebrow,
            key: const Key('capacity_weekly_review_card_eyebrow'),
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.title,
            key: const Key('capacity_weekly_review_card_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.cardSummary,
            key: const Key('capacity_weekly_review_card_summary'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('capacity_weekly_review_card_primary_button'),
            onPressed:
                onPrimaryAction ?? () => context.push(result.primaryRoute),
            child: Text(result.primaryCtaLabel),
          ),
        ],
      ),
    );
  }
}
