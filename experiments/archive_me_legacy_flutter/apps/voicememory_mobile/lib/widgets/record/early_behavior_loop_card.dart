import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/record/early_behavior_loop_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../../theme/voicememory_colors.dart';

/// Compact behaviour-loop insight — one clear observation, not a report.
class EarlyBehaviorLoopCard extends StatelessWidget {
  const EarlyBehaviorLoopCard({super.key, required this.insight});

  final EarlyBehaviorLoopInsight insight;

  static const _sectionStyle = TextStyle(
    fontSize: 13,
    height: 1.45,
    color: VoiceMemoryColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('early_behavior_loop_card'),
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
            insight.loopLine,
            key: const Key('early_behavior_loop_line'),
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: VoiceMemoryColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(insight.triggerLine, style: _sectionStyle),
          const SizedBox(height: 4),
          Text(insight.behaviorLine, style: _sectionStyle),
          const SizedBox(height: 4),
          Text(insight.costLine, style: _sectionStyle),
          const SizedBox(height: AppSpacing.sm),
          Text(
            insight.evidenceLine,
            key: const Key('early_behavior_loop_evidence'),
            style: _sectionStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Check this tomorrow:',
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            insight.nextCheckLine,
            key: const Key('early_behavior_loop_next_check'),
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
