import 'package:archiveme_mobile/features/archive_beliefs/archive_belief_models.dart';
import 'package:archiveme_mobile/product/belief_product_copy.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

class AccountArchiveStatsCard extends StatelessWidget {
  const AccountArchiveStatsCard({required this.stats, super.key});

  final ArchiveBeliefStats stats;

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
            BeliefProductCopy.accountStatsTitle,
            style: VoiceMemoryTypography.sectionTitleStyle(),
          ),
          const SizedBox(height: AppSpacing.sm),
          _row(
            BeliefProductCopy.accountBeliefsIdentified,
            '${stats.beliefsIdentified}',
          ),
          _row(
            BeliefProductCopy.accountStrongestBelief,
            stats.strongestBelief ?? '—',
          ),
          _row(
            BeliefProductCopy.accountEvidenceAnalysed,
            '${stats.reflectionsAnalysed}',
          ),
          _row(
            BeliefProductCopy.accountArchiveAge,
            stats.archiveAgeDays <= 0
                ? 'Just started'
                : '${stats.archiveAgeDays} days',
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: VoiceMemoryTypography.metadataStyle()),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: VoiceMemoryTypography.bodyStyle()),
          ),
        ],
      ),
    );
  }
}