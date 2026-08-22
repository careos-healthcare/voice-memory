import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_belief_thread_copy.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_belief_thread_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Weekly what-changed review for Patterns — calm, non-modal.
class WeeklyWhatChangedReviewCard extends StatelessWidget {
  const WeeklyWhatChangedReviewCard({
    required this.review, super.key,
    this.showProContinuity = false,
    this.onSeePro,
  });

  final WeeklyWhatChangedReview review;
  final bool showProContinuity;
  final VoidCallback? onSeePro;

  @override
  Widget build(BuildContext context) {
    if (!review.hasReview) return const SizedBox.shrink();

    return Container(
      key: const Key('weekly_what_changed_review_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF3F5FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ArchiveBeliefThreadCopy.weeklyTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Section(
            label: ArchiveBeliefThreadCopy.weeklyWhatKeptReturning,
            body: review.whatKeptReturning,
          ),
          const SizedBox(height: AppSpacing.sm),
          _Section(
            label: ArchiveBeliefThreadCopy.weeklyWhatChanged,
            body: review.whatChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          _Section(
            label: ArchiveBeliefThreadCopy.weeklyWhatToTestNext,
            body: review.whatToTestNext,
          ),
          if (review.whatFaded != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _Section(
              label: ArchiveBeliefThreadCopy.whatFadedLabel,
              body: review.whatFaded!,
            ),
          ],
          if (review.isProDepth) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              ArchiveBeliefThreadCopy.proDeeperHistory,
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
          ],
          if (showProContinuity && onSeePro != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              ArchiveBeliefThreadCopy.weeklyProContinuity,
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(onPressed: onSeePro, child: const Text('See Pro')),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ArchiveMobileTypography.cardLabel(context)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          body,
          style: ArchiveMobileTypography.body(
            context,
          ).copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}