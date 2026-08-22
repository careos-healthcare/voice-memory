import 'package:archiveme_mobile/features/archive_beliefs/archive_belief_models.dart';
import 'package:archiveme_mobile/product/belief_product_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/archive_belief_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ArchiveBeliefsHomeSection extends StatelessWidget {
  const ArchiveBeliefsHomeSection({
    required this.beliefs, required this.hasEnoughEvidence, super.key,
  });

  final List<ArchiveBeliefCardModel> beliefs;
  final bool hasEnoughEvidence;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          BeliefProductCopy.archiveHeroHeading,
          style: VoiceMemoryTypography.headlineStyle(),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          BeliefProductCopy.northStarTagline,
          style: VoiceMemoryTypography.metadataStyle(),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!hasEnoughEvidence || beliefs.isEmpty)
          _EmptyBeliefsCard(onRecord: () => context.go('/record'))
        else
          ...beliefs.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ArchiveBeliefSummaryCard(belief: b, compact: true),
            ),
          ),
        if (beliefs.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: () => context.go('/discover-yourself'),
            child: const Text(ConsumerUiCopy.viewAllPatterns),
          ),
        ],
      ],
    );
  }
}

class _EmptyBeliefsCard extends StatelessWidget {
  const _EmptyBeliefsCard({required this.onRecord});

  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          BeliefProductCopy.emptyTitle,
          style: VoiceMemoryTypography.cardTitleStyle(),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          BeliefProductCopy.emptyBody,
          style: VoiceMemoryTypography.bodyStyle(
            color: VoiceMemoryTypography.metadataStyle().color,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: onRecord,
          child: const Text(BeliefProductCopy.recordFirstReflectionCta),
        ),
      ],
    );
  }
}