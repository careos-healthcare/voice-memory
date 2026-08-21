import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_return_loop_models.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

/// Surfaces what to notice today, why to return, and what to watch for next time.
class TomorrowReturnLoopCard extends StatelessWidget {
  const TomorrowReturnLoopCard({
    required this.loop, super.key,
    this.compact = false,
  });

  final TomorrowReturnLoop loop;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConsumerUiCopy.tomorrowLoopTitle,
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.accentPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
          _row(
            icon: Icons.visibility_outlined,
            label: ConsumerUiCopy.tomorrowNoticedToday,
            body: loop.noticedToday,
          ),
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
          _row(
            icon: Icons.calendar_today_outlined,
            label: ConsumerUiCopy.tomorrowComeBack,
            body: loop.comeBackTomorrow,
          ),
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
          _row(
            icon: Icons.radar_outlined,
            label: ConsumerUiCopy.tomorrowWatchFor,
            body: loop.watchForNextTime,
          ),
        ],
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    required String body,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.accentPrimary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: VoiceMemoryTypography.metadataStyle(
                  color: AppColors.accentPrimary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: VoiceMemoryTypography.bodyStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}