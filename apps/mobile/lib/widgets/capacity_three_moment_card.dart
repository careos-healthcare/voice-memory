import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_three_moment_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/low_effort_yes_capture_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// Archive Home card for the capacity 3-moment activation path.
class CapacityThreeMomentCard extends StatelessWidget {
  const CapacityThreeMomentCard({
    required this.result, super.key,
    this.onPrimaryDismiss,
    this.sampleMode = false,
  });

  const CapacityThreeMomentCard.test({
    required this.result, super.key,
    this.onPrimaryDismiss,
    this.sampleMode = false,
  });

  final CapacityThreeMomentResult result;
  final VoidCallback? onPrimaryDismiss;
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
            onPressed: () {
              if (result.primaryDismisses) {
                onPrimaryDismiss?.call();
                return;
              }
              if (result.primaryRoute.isNotEmpty) {
                unawaited(context.push(result.primaryRoute));
              }
            },
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
          if (result.showReviewSecondary) ...[
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              key: const Key('capacity_three_moment_card_review_button'),
              onPressed: () => context.push(result.reviewSecondaryRoute),
              child: Text(result.reviewSecondaryLabel),
            ),
          ],
        ],
      ),
    );
  }
}