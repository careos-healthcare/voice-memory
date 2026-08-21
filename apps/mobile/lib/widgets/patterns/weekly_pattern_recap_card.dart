import 'package:archiveme_mobile/features/tomorrow_return/weekly_pattern_recap_engine.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

class WeeklyPatternRecapCard extends StatelessWidget {
  const WeeklyPatternRecapCard({
    required this.recap, super.key,
    this.onRecordNext,
  });

  final WeeklyPatternRecap recap;

  /// Opens Record so the user can add the next moment in the loop.
  final VoidCallback? onRecordNext;

  @override
  Widget build(BuildContext context) {
    final chips = recap.chips.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.flat(background: const Color(0xFFFFFBF5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recap.title,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 17,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            recap.body,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(height: 1.45),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chip in chips)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      chip,
                      style: VoiceMemoryTypography.bodyStyle().copyWith(
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (onRecordNext != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: onRecordNext,
                child: const Text(ConsumerUiCopy.recordNextMomentCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}