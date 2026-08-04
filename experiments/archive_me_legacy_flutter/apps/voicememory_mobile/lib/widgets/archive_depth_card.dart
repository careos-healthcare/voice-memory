import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_typography.dart';
import '../features/archive_depth/archive_depth_copy.dart';
import '../features/archive_depth/archive_depth_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Compact archive depth readout for Archive Home / Patterns.
class ArchiveDepthCard extends StatelessWidget {
  const ArchiveDepthCard({super.key, required this.result});

  final ArchiveDepthResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('archive_depth_card_${result.level.name}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ArchiveDepthCopy.cardTitle,
            key: const Key('archive_depth_card_title'),
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.levelLabel,
            key: Key('archive_depth_level_${result.level.name}'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.explanation,
            key: Key('archive_depth_explanation_${result.level.name}'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            result.progressLabel,
            key: const Key('archive_depth_progress_label'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.nextStep,
            key: const Key('archive_depth_next_step'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          if (result.showProLine) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              ArchiveDepthCopy.proLineLongTerm,
              key: const Key('archive_depth_pro_line'),
              style: ArchiveMobileTypography.explanationBody(context),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('archive_depth_pro_preview_button'),
                onPressed: () => context.push('/pro-preview'),
                child: const Text(ArchiveDepthCopy.proPreviewButton),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One-line archive depth hint on Record after 2+ entries.
class ArchiveDepthCompactHint extends StatelessWidget {
  const ArchiveDepthCompactHint({super.key, required this.result});

  final ArchiveDepthResult result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('archive_depth_compact_hint'),
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        '${ArchiveDepthCopy.cardTitle}: ${result.levelLabel}',
        style: ArchiveMobileTypography.explanationBody(
          context,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
