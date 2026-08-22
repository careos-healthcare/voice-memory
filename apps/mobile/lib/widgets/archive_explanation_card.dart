import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

/// Permanent “What is the archive?” explanation near the top of home.
class ArchiveExplanationCard extends StatelessWidget {
  const ArchiveExplanationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.standard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What is the archive?',
            style: VoiceMemoryTypography.sectionTitleStyle(),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The archive studies your reflections over time.\n\n'
            'It tracks recurring themes, changing beliefs and important life moments.\n\n'
            'Over months and years it builds evidence about who you are becoming.',
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}