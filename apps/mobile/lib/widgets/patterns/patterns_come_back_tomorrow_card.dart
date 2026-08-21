import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Calm reminder on Patterns home — why returning tomorrow matters.
class PatternsComeBackTomorrowCard extends StatelessWidget {
  const PatternsComeBackTomorrowCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.flat(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConsumerUiCopy.patternsComeBackTitle,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 17,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ConsumerUiCopy.patternsComeBackBody,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(height: 1.45),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () => context.go('/record'),
              child: const Text(ConsumerUiCopy.patternsComeBackRecordCta),
            ),
          ),
        ],
      ),
    );
  }
}