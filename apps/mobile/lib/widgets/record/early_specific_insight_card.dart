import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/record/early_specific_insight_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';

/// Sharp early compare insight — grounded in the user's own saved words.
class EarlySpecificInsightCard extends StatelessWidget {
  const EarlySpecificInsightCard({required this.insight, super.key});

  final EarlySpecificInsight insight;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('early_specific_insight_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFFFBF5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            insight.title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            insight.oneLinePattern,
            key: const Key('early_specific_insight_pattern'),
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: VoiceMemoryColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            insight.evidenceLine,
            key: const Key('early_specific_insight_evidence'),
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: VoiceMemoryColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            insight.nextQuestion,
            key: const Key('early_specific_insight_next_question'),
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: VoiceMemoryColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            insight.confidenceLabel,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}