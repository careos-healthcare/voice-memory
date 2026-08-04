import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/weekly_archive_review_copy.dart';
import '../../features/early_archive/weekly_archive_review_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact weekly archive review — repeated, changed, helped, next to watch.
class WeeklyArchiveWeekReviewCard extends StatelessWidget {
  const WeeklyArchiveWeekReviewCard({
    super.key,
    required this.review,
    required this.showRecordCta,
    this.onRecord,
  });

  final WeeklyArchiveWeekReviewResult review;
  final bool showRecordCta;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.4);
    final fallbackStyle = bodyStyle.copyWith(
      color: AppColors.textSecondary,
      fontStyle: FontStyle.italic,
    );
    final evidenceStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.35, fontSize: 12);

    return Container(
      key: const Key('weekly_archive_week_review_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FAF8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            review.title,
            key: const Key('weekly_archive_week_review_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            review.promise,
            key: const Key('weekly_archive_week_review_promise'),
            style: bodyStyle.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Section(
            label: WeeklyArchiveWeekReviewCopy.repeatedLabel,
            labelKey: 'weekly_archive_week_review_repeated_label',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  review.repeatedLine,
                  key: const Key('weekly_archive_week_review_repeated_body'),
                  style: review.repeatedIsFallback ? fallbackStyle : bodyStyle,
                ),
                for (final phrase in review.evidencePhrases)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      phrase,
                      key: Key('weekly_archive_week_review_evidence_$phrase'),
                      style: evidenceStyle,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Section(
            label: WeeklyArchiveWeekReviewCopy.changedLabel,
            labelKey: 'weekly_archive_week_review_changed_label',
            child: Text(
              review.changedLine,
              key: const Key('weekly_archive_week_review_changed_body'),
              style: review.changedIsFallback ? fallbackStyle : bodyStyle,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Section(
            label: WeeklyArchiveWeekReviewCopy.helpedLabel,
            labelKey: 'weekly_archive_week_review_helped_label',
            child: Text(
              review.helpedLine,
              key: const Key('weekly_archive_week_review_helped_body'),
              style: review.helpedIsFallback ? fallbackStyle : bodyStyle,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Section(
            label: WeeklyArchiveWeekReviewCopy.nextToWatchLabel,
            labelKey: 'weekly_archive_week_review_next_label',
            child: Text(
              review.nextToWatchLine,
              key: const Key('weekly_archive_week_review_next_body'),
              style: bodyStyle.copyWith(color: AppColors.textSecondary),
            ),
          ),
          if (showRecordCta && onRecord != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('weekly_archive_week_review_record_cta'),
                onPressed: onRecord,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentPrimary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(WeeklyArchiveWeekReviewCopy.recordCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.labelKey,
    required this.child,
  });

  final String label;
  final String labelKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          key: Key(labelKey),
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: 2),
        child,
      ],
    );
  }
}
