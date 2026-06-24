import 'package:flutter/material.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/archive_daily_change/archive_daily_change_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Compact daily archive change card — fixed copy only, no journal text.
class ArchiveDailyChangeCard extends StatelessWidget {
  const ArchiveDailyChangeCard({
    super.key,
    required this.result,
    this.onDismiss,
    this.compact = false,
  });

  const ArchiveDailyChangeCard.test({
    super.key,
    required this.result,
    this.onDismiss,
    this.compact = false,
  });

  final ArchiveDailyChangeResult result;
  final VoidCallback? onDismiss;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (ScreenshotMode.enabled ||
        !result.hasFeature ||
        !result.showOnArchiveHome) {
      return const SizedBox.shrink(key: Key('archive_daily_change_card_hidden'));
    }

    return Container(
      key: const Key('archive_daily_change_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  result.title,
                  key: const Key('archive_daily_change_card_title'),
                  style: ArchiveMobileTypography.listTitle(context),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  key: const Key('archive_daily_change_card_dismiss'),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.changeLine,
            key: const Key('archive_daily_change_card_change_line'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          if (result.repeatedLine.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              result.repeatedLine,
              key: const Key('archive_daily_change_card_repeated_line'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (result.alternativeNextMove.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              result.alternativeSectionTitle,
              key: const Key('archive_daily_change_card_alternative_title'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              result.alternativeNextMove,
              key: const Key('archive_daily_change_card_alternative_move'),
              style: ArchiveMobileTypography.listSubtitle(context),
            ),
          ],
          if (!compact && result.watchNextLine.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              result.watchNextLine,
              key: const Key('archive_daily_change_card_watch_next'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reusable section for capacity loop and weekly review screens.
class ArchiveDailyChangeSection extends StatelessWidget {
  const ArchiveDailyChangeSection({
    super.key,
    required this.result,
    this.useWeeklyTitle = false,
  });

  final ArchiveDailyChangeResult result;
  final bool useWeeklyTitle;

  @override
  Widget build(BuildContext context) {
    if (ScreenshotMode.enabled || !result.hasFeature) {
      return const SizedBox.shrink(
        key: Key('archive_daily_change_section_hidden'),
      );
    }

    final show = useWeeklyTitle
        ? result.showOnWeeklyReview
        : result.showOnCapacityLoop;
    if (!show) {
      return const SizedBox.shrink(
        key: Key('archive_daily_change_section_hidden'),
      );
    }

    final sectionTitle =
        useWeeklyTitle ? result.weeklySectionTitle : result.loopSectionTitle;

    return Column(
      key: const Key('archive_daily_change_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          sectionTitle,
          key: const Key('archive_daily_change_section_title'),
          style: ArchiveMobileTypography.explanationBody(
            context,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          result.changeLine,
          key: const Key('archive_daily_change_section_change_line'),
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
        if (result.alternativeNextMove.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            result.alternativeNextMove,
            key: const Key('archive_daily_change_section_alternative_move'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
