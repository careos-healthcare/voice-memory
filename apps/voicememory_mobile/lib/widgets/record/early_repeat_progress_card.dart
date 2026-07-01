import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/early_repeat_progress_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Capture-first progress card for the first-three recording loop — no extra CTAs.
class EarlyRepeatProgressCard extends StatelessWidget {
  const EarlyRepeatProgressCard({
    super.key,
    required this.progress,
  });

  final EarlyRepeatProgressResult progress;

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
        ],
      ),
    );
  }
}
