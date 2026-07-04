import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/pattern_detail/pattern_detail_copy.dart';
import '../../features/pattern_detail/pattern_detail_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Bottom sheet explaining one confirmed pattern and its evidence.
class PatternDetailSheet extends StatelessWidget {
  const PatternDetailSheet({
    super.key,
    required this.detail,
  });

  final PatternDetailResult detail;

  static Future<void> show(
    BuildContext context, {
    required PatternDetailResult detail,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: PatternDetailSheet(detail: detail),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final labelStyle = ArchiveMobileTypography.cardLabel(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final secondaryStyle = bodyStyle.copyWith(color: AppColors.textSecondary);
    final fallbackStyle = secondaryStyle.copyWith(fontStyle: FontStyle.italic);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            key: const Key('pattern_detail_sheet'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                PatternDetailCopy.sheetTitle,
                key: const Key('pattern_detail_sheet_title'),
                style: titleStyle,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                PatternDetailCopy.patternLabelHeading,
                key: const Key('pattern_detail_pattern_label_heading'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail.patternLabel,
                key: const Key('pattern_detail_pattern_label'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                PatternDetailCopy.evidenceHeading,
                key: const Key('pattern_detail_evidence_heading'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                PatternDetailCopy.evidenceIntro,
                key: const Key('pattern_detail_evidence_intro'),
                style: secondaryStyle,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final phrase in detail.evidencePhrases) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: bodyStyle),
                    Expanded(
                      child: Text(
                        '"$phrase"',
                        key: Key('pattern_detail_evidence_phrase_$phrase'),
                        style: bodyStyle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                PatternDetailCopy.whatChangedHeading,
                key: const Key('pattern_detail_what_changed_heading'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail.whatChangedBody,
                key: const Key('pattern_detail_what_changed_body'),
                style: detail.whatChangedSupported ? bodyStyle : fallbackStyle,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                PatternDetailCopy.whatHelpedHeading,
                key: const Key('pattern_detail_what_helped_heading'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail.whatHelpedBody,
                key: const Key('pattern_detail_what_helped_body'),
                style: detail.whatHelpedSupported ? bodyStyle : fallbackStyle,
              ),
              if (detail.hasSavedMoments) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  PatternDetailCopy.savedMomentsHeading,
                  key: const Key('pattern_detail_saved_moments_heading'),
                  style: labelStyle,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < detail.savedMoments.length; i++)
                  _MomentRow(
                    moment: detail.savedMoments[i],
                    index: i,
                  ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                PatternDetailCopy.whatToWatchHeading,
                key: const Key('pattern_detail_what_to_watch_heading'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail.whatToWatchNextBody,
                key: const Key('pattern_detail_what_to_watch_body'),
                style: bodyStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MomentRow extends StatelessWidget {
  const _MomentRow({
    required this.moment,
    required this.index,
  });

  final PatternDetailMoment moment;
  final int index;

  @override
  Widget build(BuildContext context) {
    final labelStyle = ArchiveMobileTypography.cardLabel(context).copyWith(
      color: AppColors.textPrimary,
    );
    final previewStyle =
        ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );
    final chipStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.accentPrimary,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        key: Key('pattern_detail_moment_row_$index'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  moment.dateTimeLabel,
                  key: Key('pattern_detail_moment_date_$index'),
                  style: labelStyle,
                ),
              ),
              Container(
                key: Key('pattern_detail_moment_chip_$index'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  moment.statusChipLabel,
                  style: chipStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            moment.previewText,
            key: Key('pattern_detail_moment_preview_$index'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: previewStyle,
          ),
        ],
      ),
    );
  }
}
