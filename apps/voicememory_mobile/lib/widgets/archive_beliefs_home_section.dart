import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/archive_beliefs/archive_belief_models.dart';
import '../product/belief_product_copy.dart';
import '../product/consumer_ui_copy.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_typography.dart';
import 'archive_belief_summary_card.dart';

class ArchiveBeliefsHomeSection extends StatelessWidget {
  const ArchiveBeliefsHomeSection({
    super.key,
    required this.beliefs,
    required this.hasEnoughEvidence,
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
