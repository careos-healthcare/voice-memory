import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/activation/archive_insight_feedback.dart';
import '../../features/activation/archive_insight_feedback_adaptation.dart';
import '../../features/activation/weekly_archive_review.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import 'archive_insight_feedback_controls.dart';

/// Compact or full weekly archive review — summary, not belief history.
class WeeklyArchiveReviewCard extends StatelessWidget {
  const WeeklyArchiveReviewCard({
    super.key,
    required this.review,
    this.compact = false,
    this.onAddAnother,
    this.onViewEvidence,
    this.onViewFullReview,
  });

  final WeeklyArchiveReview review;
  final bool compact;
  final VoidCallback? onAddAnother;
  final VoidCallback? onViewEvidence;
  final VoidCallback? onViewFullReview;

  Widget _wrapWithFeedback(WidgetBuilder buildCard) {
    return ArchiveInsightFeedbackHost(
      insightId: ArchiveInsightFeedbackStore.targetId(
        ArchiveInsightTarget.weeklyReview,
      ),
      showControls: ArchiveInsightFeedbackGate.showForWeeklyReview(
        hasEnoughEvidence: review.hasEnoughEvidence,
      ),
      childBuilder: buildCard,
    );
  }

  String _adaptWeeklyCopy(String base) =>
      ArchiveInsightFeedbackAdaptation.adaptedCopyFor(
        base,
        ArchiveInsightTarget.weeklyReview,
      );

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final labelStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    );

    if (!review.hasEnoughEvidence) {
      return Container(
        key: const Key('weekly_archive_review_insufficient'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: VoiceMemoryCards.standard(
          background: AppColors.backgroundSecondary,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(review.title, style: titleStyle),
            const SizedBox(height: AppSpacing.sm),
            Text(
              review.insufficientBody ?? WeeklyArchiveReviewCopy.insufficientBody,
              key: const Key('weekly_archive_review_insufficient_body'),
              style: bodyStyle,
            ),
          ],
        ),
      );
    }

    if (compact) {
      return _wrapWithFeedback((context) => Container(
        key: const Key('weekly_archive_review_compact_card'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: VoiceMemoryCards.standard(
          background: AppColors.backgroundSecondary,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              review.title,
              key: const Key('weekly_archive_review_title'),
              style: titleStyle,
            ),
            if (review.subtitle case final subtitle?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _adaptWeeklyCopy(subtitle),
                key: const Key('weekly_archive_review_subtitle'),
                style: bodyStyle,
              ),
            ],
            if (review.strongestThreadLine case final thread?) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                WeeklyArchiveReviewCopy.strongestThreadLabel,
                key: const Key('weekly_archive_review_compact_thread_label'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _adaptWeeklyCopy(thread),
                key: const Key('weekly_archive_review_compact_thread_line'),
                style: bodyStyle,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (onViewFullReview != null)
              OutlinedButton(
                key: const Key('weekly_archive_review_view_full_cta'),
                onPressed: onViewFullReview,
                child: Text(WeeklyArchiveReviewCopy.viewFullCta),
              ),
            if (onViewFullReview != null && onAddAnother != null)
              const SizedBox(height: AppSpacing.xs),
            if (onAddAnother != null && review.primaryCta != null)
              FilledButton(
                key: const Key('weekly_archive_review_add_cta'),
                onPressed: onAddAnother,
                child: Text(review.primaryCta!),
              ),
          ],
        ),
      ));
    }

    return _wrapWithFeedback((context) => Container(
      key: const Key('weekly_archive_review_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (review.notConclusionLine case final notConclusion?) ...[
            Text(
              notConclusion,
              key: const Key('weekly_archive_review_not_conclusion'),
              style: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (review.sourceLine case final source?) ...[
            Text(
              source,
              key: const Key('weekly_archive_review_source_line'),
              style: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (review.strongestThreadLine case final thread?) ...[
            Text(
              WeeklyArchiveReviewCopy.strongestThreadLabel,
              key: const Key('weekly_archive_review_thread_label'),
              style: labelStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              thread,
              key: const Key('weekly_archive_review_thread_line'),
              style: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (review.whatChangedLine case final changed?) ...[
            Text(
              WeeklyArchiveReviewCopy.whatChangedLabel,
              key: const Key('weekly_archive_review_change_label'),
              style: labelStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _adaptWeeklyCopy(changed),
              key: const Key('weekly_archive_review_change_line'),
              style: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (review.evidenceRows.isNotEmpty) ...[
            Text(
              WeeklyArchiveReviewCopy.evidenceLabel,
              key: const Key('weekly_archive_review_evidence_label'),
              style: labelStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            for (var i = 0; i < review.evidenceRows.length; i++) ...[
              Text(
                review.evidenceRows[i],
                key: Key('weekly_archive_review_evidence_$i'),
                style: bodyStyle,
              ),
              if (i < review.evidenceRows.length - 1)
                const SizedBox(height: AppSpacing.xs),
            ],
            const SizedBox(height: AppSpacing.sm),
          ],
          if (review.uncertaintyLine case final uncertainty?) ...[
            Text(
              WeeklyArchiveReviewCopy.stillUncertainLabel,
              key: const Key('weekly_archive_review_uncertain_label'),
              style: labelStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              uncertainty,
              key: const Key('weekly_archive_review_uncertainty_line'),
              style: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (review.nextActionLine case final nextAction?) ...[
            Text(
              WeeklyArchiveReviewCopy.addNextLabel,
              key: const Key('weekly_archive_review_add_next_label'),
              style: labelStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              nextAction,
              key: const Key('weekly_archive_review_next_action'),
              style: bodyStyle,
            ),
          ],
          if (onAddAnother != null && review.primaryCta != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('weekly_archive_review_add_cta'),
              onPressed: onAddAnother,
              child: Text(review.primaryCta!),
            ),
          ],
          if (onViewEvidence != null && review.secondaryCta != null) ...[
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              key: const Key('weekly_archive_review_view_evidence_cta'),
              onPressed: onViewEvidence,
              child: Text(review.secondaryCta!),
            ),
          ],
        ],
      ),
    ));
  }
}
