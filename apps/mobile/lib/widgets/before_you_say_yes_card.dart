import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/capacity_loop/before_yes_engine.dart';
import 'package:archiveme_mobile/features/capacity_loop/low_effort_yes_capture_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Capacity-specific pause card — no journal text, optional compact layout.
class BeforeYouSayYesCard extends StatelessWidget {
  const BeforeYouSayYesCard({
    required this.result, required this.onPauseBeforeYes, required this.onAlreadySaidYes, super.key,
    this.onQuickSave,
    this.compact = false,
    this.sampleMode = false,
  });

  const BeforeYouSayYesCard.test({
    required this.result, required this.onPauseBeforeYes, required this.onAlreadySaidYes, super.key,
    this.onQuickSave,
    this.compact = false,
    this.sampleMode = false,
  });

  final BeforeYesPauseResult result;
  final VoidCallback onPauseBeforeYes;
  final VoidCallback onAlreadySaidYes;
  final VoidCallback? onQuickSave;
  final bool compact;
  final bool sampleMode;

  @override
  Widget build(BuildContext context) {
    final visible = compact ? result.showOnArchiveHome : result.showOnRecord;
    if (sampleMode || ScreenshotMode.enabled || !visible) {
      return const SizedBox.shrink(key: Key('before_you_say_yes_card_hidden'));
    }

    return Container(
      key: const Key('before_you_say_yes_card'),
      width: double.infinity,
      margin: compact ? const EdgeInsets.only(bottom: AppSpacing.md) : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.title,
            key: const Key('before_you_say_yes_card_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.body,
            key: const Key('before_you_say_yes_card_body'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          if (!compact) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              result.recordPrompt,
              key: const Key('before_you_say_yes_card_prompt'),
              style: ArchiveMobileTypography.listSubtitle(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('before_you_say_yes_pause_button'),
            onPressed: onPauseBeforeYes,
            child: Text(result.pauseCtaLabel),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            key: const Key('before_you_say_yes_already_button'),
            onPressed: onAlreadySaidYes,
            child: Text(result.alreadyYesCtaLabel),
          ),
          if (onQuickSave != null) ...[
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              key: const Key('before_you_say_yes_quick_save_button'),
              onPressed: onQuickSave,
              child: const Text(LowEffortYesCaptureCopy.quickSaveCta),
            ),
          ],
        ],
      ),
    );
  }
}