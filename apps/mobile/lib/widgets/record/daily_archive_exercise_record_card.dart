import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/daily_archive_exercise/daily_archive_exercise_copy.dart';
import 'package:archiveme_mobile/features/daily_archive_exercise/daily_archive_exercise_models.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Compact daily exercise prompt on Record — metadata only.
class DailyArchiveExerciseRecordCard extends StatelessWidget {
  const DailyArchiveExerciseRecordCard({
    required this.exercise, super.key,
    this.onPrimary,
  });

  final DailyArchiveExerciseResult exercise;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    if (!exercise.showOnRecord) {
      return const SizedBox.shrink(
        key: Key('daily_archive_exercise_record_card_hidden'),
      );
    }

    return Container(
      key: const Key('daily_archive_exercise_record_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary.withValues(alpha: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DailyArchiveExerciseCopy.recordLabel,
            key: const Key('daily_archive_exercise_record_label'),
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            exercise.prompt,
            key: const Key('daily_archive_exercise_record_prompt'),
            style: ArchiveMobileTypography.body(context).copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            exercise.hint,
            key: const Key('daily_archive_exercise_record_hint'),
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('daily_archive_exercise_record_primary_button'),
            onPressed: onPrimary,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: Text(exercise.primaryCtaLabel),
          ),
        ],
      ),
    );
  }
}