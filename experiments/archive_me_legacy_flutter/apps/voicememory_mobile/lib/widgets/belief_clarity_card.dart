import 'package:flutter/material.dart';

import '../features/archive_beliefs/archive_belief_models.dart';
import '../product/belief_clarity.dart';
import '../product/belief_product_copy.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';
import '../theme/voicememory_typography.dart';

/// Answers: what is the belief, why we think so, why it matters.
class BeliefClarityCard extends StatelessWidget {
  const BeliefClarityCard({
    super.key,
    required this.belief,
    this.reflectionsAnalysed,
    this.showArchiveExplanation = false,
    this.onTap,
  });

  final ArchiveBeliefCardModel belief;
  final int? reflectionsAnalysed;
  final bool showArchiveExplanation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(BeliefProductCopy.labelBelief),
        const SizedBox(height: 6),
        Text(
          BeliefClarity.quotedBelief(belief.statement),
          style: VoiceMemoryTypography.headlineStyle().copyWith(fontSize: 22),
        ),
        const SizedBox(height: AppSpacing.md),
        _label(BeliefProductCopy.labelConfidence),
        const SizedBox(height: 4),
        Text(
          '${belief.confidencePercent}%',
          style: VoiceMemoryTypography.cardTitleStyle(),
        ),
        if (reflectionsAnalysed != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _label(BeliefProductCopy.labelBasedOn),
          const SizedBox(height: 4),
          Text(
            BeliefProductCopy.savedMomentsCount(reflectionsAnalysed!),
            style: VoiceMemoryTypography.bodyStyle(),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _label(BeliefProductCopy.labelWhy),
        const SizedBox(height: 4),
        Text(
          BeliefClarity.whyLine(belief),
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _label(BeliefProductCopy.labelWhyItMatters),
        const SizedBox(height: 4),
        Text(
          BeliefClarity.whyItMatters(belief),
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textSecondary,
          ),
        ),
        if (showArchiveExplanation && reflectionsAnalysed != null) ...[
          const SizedBox(height: AppSpacing.md),
          _label(BeliefProductCopy.labelArchiveExplanation),
          const SizedBox(height: 4),
          Text(
            BeliefClarity.archiveExplanation(
              belief,
              reflectionsAnalysed: reflectionsAnalysed!,
            ),
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );

    final box = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(),
      child: child,
    );

    if (onTap == null) return box;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VoiceMemoryCards.radius),
        child: box,
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: VoiceMemoryTypography.metadataStyle(
        color: AppColors.accentPrimary,
      ).copyWith(fontWeight: FontWeight.w600),
    );
  }
}
