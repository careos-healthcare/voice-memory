import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_evidence/archive_belief_thread_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Soft Pro continuity bridge after archive value appears — never blocks insight.
class ArchiveIntelligenceProBridgeCard extends StatelessWidget {
  const ArchiveIntelligenceProBridgeCard({
    super.key,
    required this.onSeePro,
    required this.onNotNow,
  });

  final VoidCallback onSeePro;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('archive_intelligence_pro_bridge_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ArchiveBeliefThreadCopy.proKeepsThread,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ArchiveBeliefThreadCopy.proBridgeBody,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ArchiveBeliefThreadCopy.proReviewChanges,
            style: ArchiveMobileTypography.responsiveHelper(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('archive_intelligence_pro_not_now'),
                  onPressed: onNotNow,
                  child: const Text(ArchiveBeliefThreadCopy.proBridgeSecondary),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilledButton(
                  key: const Key('archive_intelligence_pro_see_pro'),
                  onPressed: onSeePro,
                  child: const Text(ArchiveBeliefThreadCopy.proBridgeCta),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
