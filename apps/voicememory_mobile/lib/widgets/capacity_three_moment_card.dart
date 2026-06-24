import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/capacity_loop/capacity_three_moment_models.dart';
import '../features/capacity_loop/low_effort_yes_capture_copy.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Archive Home card for the capacity 3-moment activation path.
class CapacityThreeMomentCard extends StatelessWidget {
  const CapacityThreeMomentCard({
    super.key,
    required this.result,
    this.sampleMode = false,
  });

  const CapacityThreeMomentCard.test({
    super.key,
    required this.result,
    this.sampleMode = false,
  });

  final CapacityThreeMomentResult result;
  final bool sampleMode;

  @override
  Widget build(BuildContext context) {
    if (sampleMode ||
        ScreenshotMode.enabled ||
        !result.hasCard ||
        !result.showOnArchiveHome) {
      return const SizedBox.shrink(
        key: Key('capacity_three_moment_card_hidden'),
      );
    }

    return Container(
      key: const Key('capacity_three_moment_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.title,
            key: const Key('capacity_three_moment_card_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.subtitle,
            key: const Key('capacity_three_moment_card_subtitle'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          if (result.emptyBody.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              result.emptyBody,
              key: const Key('capacity_three_moment_card_empty'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (result.progressLabel.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              result.progressLabel,
              key: const Key('capacity_three_moment_card_progress'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('capacity_three_moment_card_primary_button'),
            onPressed: () => context.push(result.primaryRoute),
            child: Text(result.primaryCtaLabel),
          ),
          if (result.showQuickSaveSecondary) ...[
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              key: const Key('capacity_three_moment_card_quick_save_button'),
              onPressed: () => context.push(result.quickSaveRoute),
              child: const Text(LowEffortYesCaptureCopy.quickSaveCta),
            ),
          ],
        ],
      ),
    );
  }
}
