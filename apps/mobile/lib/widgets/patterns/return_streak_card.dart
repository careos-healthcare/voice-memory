import 'package:archiveme_mobile/features/tomorrow_return/return_streak_model.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ReturnStreakCard extends StatelessWidget {
  const ReturnStreakCard({
    required this.streak, super.key,
    this.showCta = true,
  });

  final ReturnStreak streak;
  final bool showCta;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = AppColors.warmBorder;

  @override
  Widget build(BuildContext context) {
    if (!streak.showOnPatterns && !streak.showOnRecordPostSave) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            streak.headline,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 17,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ConsumerUiCopy.returnStreakDaysInARow(streak.currentStreakDays),
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.accentPrimary,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            streak.body,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(height: 1.45),
          ),
          if (showCta) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: () => context.go('/record'),
                child: const Text(ConsumerUiCopy.returnStreakRecordCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}