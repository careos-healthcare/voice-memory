import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/activation/archive_home_summary.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Compact post-save nudge — points to Archive Home instead of duplicating payoff cards.
class PostSaveArchiveHomeNudgeCard extends StatelessWidget {
  const PostSaveArchiveHomeNudgeCard({
    required this.summary, required this.onViewArchive, required this.onAddMoment, super.key,
  });

  final ArchiveHomeSummary summary;
  final VoidCallback onViewArchive;
  final VoidCallback onAddMoment;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('post_save_archive_home_nudge_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF0F7F2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            summary.title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            summary.body,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('post_save_view_archive_cta'),
            onPressed: onViewArchive,
            child: const Text(VisibleArchiveProofCopy.firstSaveViewArchiveCta),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            key: const Key('post_save_add_moment_cta'),
            onPressed: onAddMoment,
            child: const Text(VisibleArchiveProofCopy.firstSavePrimaryCta),
          ),
        ],
      ),
    );
  }
}