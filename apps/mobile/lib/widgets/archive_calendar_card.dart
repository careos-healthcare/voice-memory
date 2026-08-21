import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_calendar/archive_calendar_copy.dart';
import 'package:archiveme_mobile/features/archive_calendar/archive_calendar_models.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Compact Archive Calendar card for Archive Home — counts only.
class ArchiveCalendarCard extends StatelessWidget {
  const ArchiveCalendarCard({
    required this.result, super.key,
    this.onPrimaryAction,
  });

  const ArchiveCalendarCard.test({
    required this.result, super.key,
    this.onPrimaryAction,
  });

  final ArchiveCalendarResult result;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    if (ScreenshotMode.enabled ||
        !result.hasCard ||
        !result.showOnArchiveHome) {
      return const SizedBox.shrink(key: Key('archive_calendar_card_hidden'));
    }

    return Container(
      key: const Key('archive_calendar_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ArchiveCalendarCopy.eyebrow,
            key: const Key('archive_calendar_card_eyebrow'),
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.cardHeadline,
            key: const Key('archive_calendar_card_headline'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            result.cardSummary,
            key: const Key('archive_calendar_card_summary'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.weekSummaryLabel,
            key: const Key('archive_calendar_card_week_summary'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.privacyLine,
            key: const Key('archive_calendar_card_privacy'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('archive_calendar_card_primary_button'),
            onPressed:
                onPrimaryAction ?? () => context.push(result.primaryRoute),
            child: Text(result.primaryCtaLabel),
          ),
        ],
      ),
    );
  }
}