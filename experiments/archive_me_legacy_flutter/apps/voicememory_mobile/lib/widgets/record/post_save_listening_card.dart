import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/post_save/post_save_recorded_summary_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Shown while the capture pipeline turns audio into saved text.
class PostSaveListeningCard extends StatelessWidget {
  const PostSaveListeningCard({super.key, this.stageLabel});

  final String? stageLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: PostSaveRecordedSummaryCopy.listeningTitle,
      child: Container(
        key: const Key('post_save_listening_card'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: VoiceMemoryCards.standard(
          background: AppColors.backgroundSecondary,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              PostSaveRecordedSummaryCopy.listeningTitle,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              PostSaveRecordedSummaryCopy.listeningBody,
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textPrimary, height: 1.45),
            ),
            if (stageLabel != null && stageLabel!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                stageLabel!,
                style: ArchiveMobileTypography.responsiveHelper(
                  context,
                ).copyWith(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
