import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_evidence/archive_belief_thread_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Soft Pro boundary for full archive history — never blocks insight or recording.
class ArchiveIntelligenceProBridgeCard extends StatelessWidget {
  const ArchiveIntelligenceProBridgeCard({
    super.key,
    required this.onSeePro,
    required this.onNotNow,
    this.compact = false,
  });

  final VoidCallback onSeePro;
  final VoidCallback onNotNow;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key(
        compact
            ? 'archive_intelligence_pro_bridge_card_compact'
            : 'full_archive_history_pro_boundary_card',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ArchiveBeliefThreadCopy.fullArchiveHistoryTitle,
            key: const Key('full_archive_history_pro_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ArchiveBeliefThreadCopy.fullArchiveHistoryBody,
            key: const Key('full_archive_history_pro_body'),
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
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
