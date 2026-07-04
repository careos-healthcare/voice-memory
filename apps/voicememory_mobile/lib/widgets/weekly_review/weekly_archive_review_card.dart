import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/weekly_review/weekly_archive_review_copy.dart';
import '../../features/weekly_review/weekly_archive_review_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact weekly review entry point on Record / Patterns.
class WeeklyArchiveReviewCard extends StatelessWidget {
  const WeeklyArchiveReviewCard({
    super.key,
    required this.review,
    required this.onViewReview,
  });

  final WeeklyArchiveReviewResult review;
  final VoidCallback onViewReview;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.4,
    );
    final secondaryStyle = bodyStyle.copyWith(color: AppColors.textSecondary);

    return Container(
      key: const Key('weekly_archive_review_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF8FAF8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            review.title,
            key: const Key('weekly_archive_review_card_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          if (review.state == WeeklyArchiveReviewState.full &&
              review.subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              review.subtitle!,
              key: const Key('weekly_archive_review_card_subtitle'),
              style: secondaryStyle,
            ),
          ],
          if (review.state == WeeklyArchiveReviewState.forming &&
              review.formingBody != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              review.formingBody!,
              key: const Key('weekly_archive_review_card_forming_body'),
              style: secondaryStyle,
            ),
          ],
          if (review.compactTeaser case final teaser?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              teaser,
              key: const Key('weekly_archive_review_card_teaser'),
              style: bodyStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('weekly_archive_review_view_button'),
              onPressed: onViewReview,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentPrimary,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(WeeklyArchiveReviewCopy.viewWeeklyReviewCta),
            ),
          ),
        ],
      ),
    );
  }
}
