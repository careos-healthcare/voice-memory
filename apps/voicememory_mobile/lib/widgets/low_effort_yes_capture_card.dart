import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/capacity_loop/low_effort_yes_capture_copy.dart';
import '../features/capacity_loop/low_effort_yes_capture_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Compact quick-save card for capacity-yes record surfaces.
class LowEffortYesCaptureCard extends StatelessWidget {
  const LowEffortYesCaptureCard({
    super.key,
    required this.result,
    this.sampleMode = false,
    this.compact = false,
  });

  const LowEffortYesCaptureCard.test({
    super.key,
    required this.result,
    this.sampleMode = false,
    this.compact = false,
  });

  final LowEffortYesCaptureResult result;
  final bool sampleMode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (sampleMode ||
        ScreenshotMode.enabled ||
        !result.showCard) {
      return const SizedBox.shrink(
        key: Key('low_effort_yes_capture_card_hidden'),
      );
    }

    return Container(
      key: const Key('low_effort_yes_capture_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.title,
            key: const Key('low_effort_yes_capture_card_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.body,
            key: const Key('low_effort_yes_capture_card_body'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('low_effort_yes_capture_card_quick_save'),
            onPressed: () => context.push(LowEffortYesCaptureCopy.route),
            child: Text(result.primaryCtaLabel),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            key: const Key('low_effort_yes_capture_card_record_instead'),
            onPressed: () => context.push(LowEffortYesCaptureCopy.recordRoute),
            child: Text(result.secondaryCtaLabel),
          ),
        ],
      ),
    );
  }
}
