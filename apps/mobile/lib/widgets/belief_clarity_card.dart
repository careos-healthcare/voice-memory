import 'package:archiveme_mobile/features/archive_beliefs/archive_belief_models.dart';
import 'package:archiveme_mobile/product/belief_clarity.dart';
import 'package:archiveme_mobile/product/belief_product_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

/// Answers: what is the belief, why we think so, why it matters.
class BeliefClarityCard extends StatelessWidget {
  const BeliefClarityCard({
    required this.belief, super.key,
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
        // Not quoted: `statement` is a pattern ArchiveMe derived, not the
        // user's words, so quotation marks would misattribute it.
        Text(
          belief.statement,
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
            '$reflectionsAnalysed ${BeliefProductCopy.reflectionsWord}',
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
      color: AppColors.transparent,
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