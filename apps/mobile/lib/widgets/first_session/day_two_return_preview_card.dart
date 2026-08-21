import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/first_session/day_two_return_preview.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Passive preview of tomorrow's check, shown near the day-1 complete /
/// day-2 reminder area after the first save. No buttons, no permission
/// asks, no obligations — it disappears on its own once the day-2 return
/// happened or the archive holds 3+ entries.
class DayTwoReturnPreviewCard extends StatelessWidget {
  const DayTwoReturnPreviewCard({
    required this.preview, super.key,
    this.entryCount,
  });

  final DayTwoReturnPreview preview;

  /// Safe count for analytics — never card text.
  final int? entryCount;

  @override
  Widget build(BuildContext context) {
    if (!preview.show) return const SizedBox.shrink();
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.day2ReturnPreviewSeen,
      entryCount: entryCount,
      stage: 'post_save',
      oncePerSession: true,
    );

    return Container(
      key: const Key('day_two_return_preview_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF3F6FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DayTwoReturnPreview.title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            preview.body,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            DayTwoReturnPreview.smallLine,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}