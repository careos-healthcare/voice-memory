import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/review_ritual/view_ritual_copy.dart';
import '../features/review_ritual/view_ritual_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Compact Review Ritual card for Archive Home.
class ReviewRitualCard extends StatelessWidget {
  const ReviewRitualCard({
    super.key,
    required this.result,
    this.onPrimaryAction,
    this.onSecondaryAction,
  });

  const ReviewRitualCard.test({
    super.key,
    required this.result,
    this.onPrimaryAction,
    this.onSecondaryAction,
  });

  final ReviewRitualResult result;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    if (ScreenshotMode.enabled ||
        !result.hasCard ||
        !result.showOnArchiveHome) {
      return const SizedBox.shrink(key: Key('review_ritual_card_hidden'));
    }

    return Container(
      key: const Key('review_ritual_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ReviewRitualCopy.eyebrow,
            key: const Key('review_ritual_card_eyebrow'),
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.cardHeadline,
            key: const Key('review_ritual_card_headline'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            result.cardSummary,
            key: const Key('review_ritual_card_summary'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          if (result.hasRitual) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              result.summaryLabel,
              key: const Key('review_ritual_card_summary_label'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.helperText,
            key: const Key('review_ritual_card_helper'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              FilledButton(
                key: const Key('review_ritual_card_primary_button'),
                onPressed:
                    onPrimaryAction ?? () => context.push(result.primaryRoute),
                child: Text(result.primaryCtaLabel),
              ),
              if (result.hasRitual &&
                  result.primaryRoute != ReviewRitualCopy.route)
                OutlinedButton(
                  key: const Key('review_ritual_card_secondary_button'),
                  onPressed:
                      onSecondaryAction ??
                      () => context.push(result.secondaryRoute),
                  child: Text(result.secondaryCtaLabel),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
