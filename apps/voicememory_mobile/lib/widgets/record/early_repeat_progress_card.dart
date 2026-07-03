import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/early_repeat_progress_model.dart';
import '../../features/early_archive/early_saved_moments_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Capture-first progress card for the first-three recording loop — no extra CTAs.
class EarlyRepeatProgressCard extends StatelessWidget {
  const EarlyRepeatProgressCard({
    super.key,
    required this.progress,
    this.onViewSavedMoments,
  });

  final EarlyRepeatProgressResult progress;
  final VoidCallback? onViewSavedMoments;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('early_repeat_progress_card_${progress.kind.name}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFFFFBF5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            progress.title,
            key: const Key('early_repeat_progress_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            progress.body,
            key: const Key('early_repeat_progress_body'),
            style: ArchiveMobileTypography.explanationBody(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            progress.progressLabel,
            key: const Key('early_repeat_progress_label'),
            style: ArchiveMobileTypography.cardLabel(context).copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            progress.nextMomentCue.label,
            key: const Key('early_repeat_progress_next_moment_cue_label'),
            style: ArchiveMobileTypography.cardLabel(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            progress.nextMomentCue.body,
            key: const Key('early_repeat_progress_next_moment_cue_body'),
            style: ArchiveMobileTypography.explanationBody(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            progress.nextMomentCue.footer,
            key: const Key('early_repeat_progress_next_moment_cue_footer'),
            style: ArchiveMobileTypography.explanationBody(context).copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (onViewSavedMoments != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('early_repeat_progress_view_saved_moments_button'),
                onPressed: onViewSavedMoments,
                child: const Text(EarlySavedMomentsCopy.viewSavedMomentsCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
